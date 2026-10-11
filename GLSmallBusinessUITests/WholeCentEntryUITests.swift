//  WholeCentEntryUITests.swift GLSmallBusinessUITests
//
//  Money is entered in whole cents: an amount field refuses a third decimal as it is typed, on the
//  real form, keystroke by keystroke. The rule and the list of amount fields are pinned by unit
//  tests (`WholeCentAmountTests`); this is the one thing they can't reach — the field itself
//  putting the text back under the person's finger.

import XCTest

final class WholeCentEntryUITests: GLUITestCase {

    /// All Expenses ▸ + ▸ Add Manually ▸ Total: "12.345" typed at machine speed (XCUITest's pace,
    /// where SwiftUI can hand several keystrokes over as one change) keeps "12.34" — every digit
    /// but the third decimal — and a further digit is refused too.
    func testAReceiptTotalRefusesAThirdDecimal() {
        app.openContacts("Customers")
        app.buttons["Menu"].tap()
        app.tapMenuRow("My Business Details")
        app.tapMenuRow("Documents")
        app.tapMenuRow("All Expenses")
        let receiptsBar = app.glNavBar("All Expenses")
        XCTAssertTrue(receiptsBar.waitForExistence(timeout: 5))
        receiptsBar.buttons["Add Receipt"].tap()
        app.buttons["Add Manually"].tap()
        XCTAssertTrue(app.glNavBar("New Receipt").waitForExistence(timeout: 5),
                      "Add Manually should open the receipt form.")

        let total = app.textFields["receiptTotalField"]
        XCTAssertTrue(app.scrollUntilHittable(total, maxSwipes: 4),
                      "The receipt form should show its Total field. \(app.visibleSummary())")
        XCTAssertTrue(total.tapForKeyboardFocus(), "Tapping Total should give it the keyboard.")

        total.typeText("12.345")
        total.waitForValue("12.34")
        XCTAssertEqual(total.value as? String, "12.34", "A third decimal can't be typed into an amount.")

        total.typeText("9")
        total.waitForValue("12.34")
        XCTAssertEqual(total.value as? String, "12.34", "Nor can a fourth keystroke sneak one in.")
    }
}
