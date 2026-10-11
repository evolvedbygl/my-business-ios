//  SessionChangesUITests.swift GLSmallBusinessUITests
//
//  UI automation for the interactive changes a unit test can't reach: phone auto-dashing (#5), the
//  unsaved-changes guard (#7), the per-line discount control (#6), and the receipt form's Job
//  picker + photo upload (#2/#3). Runs in the harness (no macOS permission prompt), in demo mode.

import UIKit
import XCTest

final class SessionChangesUITests: GLUITestCase {

    // #5 — auto-dash, AND robustness: typeText sends all 10 digits faster than any human, which
    // used to drop a digit with the old SwiftUI.onChange reformat. PhoneTextField formats
    // atomically, so this (the original failing case) must now produce the full number — no
    // character dropped.
    func testPhoneFieldAutoDashesWithoutDroppingDigits() {
        let phone = openNewCustomerPhoneField()
        phone.typeText("5551234567")
        // typeText returns before the app has taken every keystroke, so wait for the number before
        // reading it (see `waitForValue`: a dropped digit still fails right here).
        phone.waitForValue("555-123-4567")
        XCTAssertEqual(phone.value as? String, "555-123-4567",
                       "Typing 10 digits should auto-format to 555-123-4567 with no digit lost.")
    }

    // #5 at a person's pace: one digit at a time, each on screen before the next. The dashes must
    // land exactly where the typist sees them, and the first digit (which makes the form dirty and
    // swaps in the discard-guard Back button) must not take the keyboard away — if it did, the next
    // typeText would fail with no keyboard focus.
    func testPhoneFieldFormatsEachDigitAtHumanPace() {
        let phone = openNewCustomerPhoneField()
        let shown = ["5", "55", "555", "555-1", "555-12", "555-123",
                     "555-123-4", "555-123-45", "555-123-456", "555-123-4567"]
        for (digit, expected) in zip("5551234567", shown) {
            phone.typeText(String(digit))
            phone.waitForValue(expected)
            XCTAssertEqual(phone.value as? String, expected,
                           "After typing \(digit) the field should read \(expected).")
        }
    }

    // #5, the whole number in ONE edit — what a paste (or an AutoFill suggestion) hands the field.
    // The formatter must strip the pasted punctuation and dash it exactly like typed digits.
    func testPhoneFieldFormatsAPastedNumber() {
        UIPasteboard.general.string = "(555) 123-4567"
        let phone = openNewCustomerPhoneField()
        // A second tap on the focused, empty field opens the edit menu, but not every time: a tap
        // that lands too soon after the focusing one is read as part of it (2026-09-29, 1 in ~3
        // runs). A long press opens the menu reliably, so fall back to it.
        let paste = app.menuItems["Paste"]
        phone.tap()
        if !paste.waitForExistence(timeout: 2) {
            phone.press(forDuration: 1.0)
        }
        XCTAssertTrue(paste.waitForExistence(timeout: 5),
                      "Tapping the focused Phone field should offer Paste. \(app.visibleSummary())")
        paste.tap()
        phone.waitForValue("555-123-4567")
        XCTAssertEqual(phone.value as? String, "555-123-4567",
                       "A pasted (555) 123-4567 should format to 555-123-4567.")
    }

    /// Customers ▸ + ▸ the New Customer form's Phone field, holding the keyboard.
    private func openNewCustomerPhoneField() -> XCUIElement {
        app.openContacts("Customers")
        // LAW 40: the one-option "More" menu is gone — "+" (a11y "Add Customer") is a direct button.
        app.buttons["Add Customer"].tap()

        let phone = app.textFields["Phone"]
        XCTAssertTrue(phone.waitForExistence(timeout: 5), "The New Customer form should have a Phone field.")
        XCTAssertTrue(phone.tapForKeyboardFocus(), "Tapping Phone should give it the keyboard.")
        return phone
    }

    // #7 — editing a form then going Back prompts to discard, and confirming leaves the form. The
    // PROMPT is the data-loss protection; without the guard a stray swipe-back would have silently
    // discarded.
    func testUnsavedChangesGuardPromptsAndDiscardLeaves() {
        app.openContacts("Customers")
        // LAW 40: the one-option "More" menu is gone — "+" (a11y "Add Customer") is a direct button.
        app.buttons["Add Customer"].tap()

        let firstName = app.textFields["First name"]
        XCTAssertTrue(firstName.waitForExistence(timeout: 5))
        firstName.tap()
        firstName.typeText("Dirty")

        let back = app.buttons["discardBackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5),
                      "Editing should swap in the discard-guard Back button.")
        back.tap()

        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 5),
                      "Going back with unsaved edits should prompt to discard.")
        app.buttons["Discard Changes"].tap()
        XCTAssertTrue(app.glNavBar("Customers").waitForExistence(timeout: 5),
                      "Confirming discard should leave the form.")
    }

    // #7 — a form with NO edits navigates back normally (no guard button, no prompt).
    func testCleanFormHasNoDiscardGuard() {
        app.openContacts("Customers")
        // LAW 40: the one-option "More" menu is gone — "+" (a11y "Add Customer") is a direct button.
        app.buttons["Add Customer"].tap()
        XCTAssertTrue(app.glNavBar("New Customer").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["discardBackButton"].exists,
                       "An untouched form should not show the discard-guard Back button.")
    }

    // #6 — the per-line discount control is present in the estimate line editor.
    func testEstimateLineItemHasDiscountControl() {
        app.openContacts("Customers")
        app.staticTexts["Carter, Danielle"].tap()
        app.staticTexts["Estimates"].tap()
        // LAW 40: "+" (a11y "New Estimate") is a direct navbar button now, no "More" menu.
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.textFields["Job title"].waitForExistence(timeout: 5),
                      "New Estimate should open the estimate form.")

        // Presence is the contract here (nothing is tapped), so the assertion stays on it.
        let picker = app.buttons["lineDiscountPicker"].firstMatch
        app.scrollUntilHittable(picker, maxSwipes: 5)
        XCTAssertTrue(picker.exists, "#6: each line item should have a discount control.")
    }

    // Tax ID (SSN/EIN) — same atomic-formatting fix as phone: typing 9 digits at once must keep
    // them all (a dropped SSN/EIN digit would silently produce a wrong tax ID on the 1099).
    func testTaxIdFieldFormatsWithoutDroppingDigits() {
        app.openContacts("Subcontractors")
        // LAW 40: the subcontractors "..." became the 1099-report menu; add is the direct "+"
        // button (a11y "Add Subcontractor").
        app.buttons["Add Subcontractor"].tap()
        XCTAssertTrue(app.glNavBar("New Subcontractor").waitForExistence(timeout: 5))

        // The Tax ID is masked behind Face ID; scroll it into view and reveal it first (demo mode
        // bypasses the biometric prompt). Scrolled to hittable, not merely present, so the tap
        // can't land on a pre-rendered-but-off-screen row and miss.
        let reveal = app.buttons["taxIdRevealButton"]
        XCTAssertTrue(app.scrollUntilHittable(reveal),
                      "The Tax ID reveal control should be on screen. \(app.visibleSummary())")
        // Coordinate tap: a small.plain button in a LabeledContent value slot doesn't always fire
        // from a plain element.tap under XCUITest, so hit its center point directly.
        reveal.tap()

        let tin = app.textFields["tinField"]
        XCTAssertTrue(tin.waitForExistence(timeout: 5), "Revealing should show the Tax ID field.")
        XCTAssertTrue(tin.tapForKeyboardFocus(), "Tapping the Tax ID field should give it the keyboard.")
        tin.typeText("987654321")   // distinct from the SSN placeholder so the assert is meaningful
        tin.waitForValue("987-65-4321")   // same read-after-typeText race as the phone test
        XCTAssertEqual(tin.value as? String, "987-65-4321",
                       "Typing 9 digits should format as an SSN with no digit dropped.")
    }

    // #2 + #3 — the receipt form (created from scratch) has a Job picker and a photo-upload option.
    func testReceiptFormHasJobPickerAndPhotoUpload() {
        app.openContacts("Customers")
        app.buttons["Menu"].tap()
        // Job Records moved into Business -> All Documents; the receipts row and screen were
        // renamed "All Expenses".
        app.tapMenuRow("My Business Details")
        app.tapMenuRow("Documents")
        app.tapMenuRow("All Expenses")
        let receiptsBar = app.glNavBar("All Expenses")
        XCTAssertTrue(receiptsBar.waitForExistence(timeout: 5))

        // The add control is ALWAYS the "+" menu (a11y "Add Receipt") — it no longer mutates
        let addReceipt = app.buttons["Add Receipt"]
        XCTAssertTrue(addReceipt.waitForExistence(timeout: 5))
        addReceipt.tap()
        let addManually = app.buttons["Add Manually"]
        XCTAssertTrue(addManually.waitForExistence(timeout: 5))
        addManually.tap()

        XCTAssertTrue(app.glNavBar("New Receipt").waitForExistence(timeout: 5),
                      "Add Manually should open the receipt form.")
        XCTAssertTrue(app.buttons["Upload a photo of the receipt"].waitForExistence(timeout: 5),
                      "#3: the receipt form should offer a photo upload.")
        // Presence is the contract here (nothing is tapped), so the assertion stays on it.
        let jobPicker = app.buttons["receiptJobPicker"].firstMatch
        app.scrollUntilHittable(jobPicker, maxSwipes: 4)
        XCTAssertTrue(jobPicker.exists, "#2: the receipt form should have a Job picker.")
    }
}
