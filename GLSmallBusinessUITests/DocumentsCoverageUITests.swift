//  DocumentsCoverageUITests.swift GLSmallBusinessUITests
//
//  Opens the remaining heavy document/info screens — Personal info, the company "More Info" and
//  W-9, the per-customer Invoices list + new-invoice form, and a receipt's detail. These are the
//  largest views still untouched by the other suites.

import XCTest

final class DocumentsCoverageUITests: GLUITestCase {

    func testPersonalInfoOpens() {
        // Personal merged into Gold Life ID (2026-08-22): the gold pill is the door to the person,
        // and the screen carries the old Personal sections.
        openMenu()
        app.buttons["Gold Life ID"].tap()
        XCTAssertTrue(app.glNavBar("Gold Life ID").waitForExistence(timeout: 5),
                      "Menu → the gold pill should open the Gold Life ID screen.")
        XCTAssertTrue(app.staticTexts["First name"].waitForExistence(timeout: 5),
                      "The Gold Life ID screen should carry the personal info sections.")
        // Below the fold on this screen, and a List does not materialize offscreen rows — so this
        // must SCROLL to it, not merely ask whether it exists.
        XCTAssertTrue(app.scrollToRow("Signature").exists,
                      "The signature row should live on the Gold Life ID screen.")
    }

    func testCompanyDetailsInlineOnHub() {
        // "More Info" retired: the basics live INLINE on the hub - License, Online, Address, and
        // masked W-9 details, no extra click.
        openCompanyHub()
        XCTAssertTrue(app.scrollToRow("License #").exists,
                      "The hub should show the License row inline.")
        // "Tax details (W-9)" sits BELOW the License row, so it needs its own scroll — asserting
        // `.exists` right after finding License checked a row not yet rendered.
        XCTAssertTrue(app.scrollToRow("Tax details (W-9)").exists,
                      "The hub should show the W-9 details section inline.")
    }

    func testGenerateW9Opens() {
        openCompanyHub()
        app.tapMenuRow("Documents")
        XCTAssertTrue(app.glNavBar("Documents").waitForExistence(timeout: 5),
                      "The hub's Documents row should open the documents screen.")
        app.tapMenuRow("Generate a W-9")
        XCTAssertTrue(app.glNavBar("Generate a W-9").waitForExistence(timeout: 5),
                      "Generate a W-9 should open the W-9 sheet.")
    }

    func testInvoicesListAndNewInvoiceFormOpen() {
        app.openContacts("Customers")
        app.staticTexts["Carter, Danielle"].tap()
        app.staticTexts["Invoices"].tap()
        XCTAssertTrue(app.glNavBar("Invoices").waitForExistence(timeout: 5),
                      "The customer's Invoices list should open.")
        // (2026-09-01): the one-option "…" menu is gone — "+" is a permanent direct navbar button
        // (a11y label "New Invoice"); "Select" is its own button.
        app.buttons["New Invoice"].tap()
        XCTAssertTrue(app.textFields["Job title"].waitForExistence(timeout: 5),
                      "New Invoice should open the invoice form.")
    }

    func testReceiptDetailOpens() {
        // Job Records moved into Business -> All Documents; the receipts list was renamed "All
        // Expenses" in the 2026-09-01 IA audit.
        openCompanyHub()
        app.tapMenuRow("Documents")
        app.tapMenuRow("All Expenses")
        XCTAssertTrue(app.glNavBar("All Expenses").waitForExistence(timeout: 5))
        app.staticTexts["Henderson Hardware"].tap()
        // The detail titles itself with the vendor (Receipt.displayVendor), so assert the ARRIVAL
        // screen directly instead of the old "list bar went away" negative.
        XCTAssertTrue(app.glNavBar("Henderson Hardware").waitForExistence(timeout: 5),
                      "Tapping a receipt should open its detail, titled by the vendor.")
    }

    private func openMenu() {
        app.openContacts("Customers")
        app.buttons["Menu"].tap()
    }

    private func openCompanyHub() {
        openMenu()
        app.tapMenuRow("My Business Details")
        XCTAssertTrue(app.staticTexts["Contact"].waitForExistence(timeout: 5),
                      "The company hub should open.")
    }
}
