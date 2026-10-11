//  ChangeOrderBalanceUITests.swift
//  GLSmallBusinessUITests
//
//  Verifies the change-order/balance fix against deterministic demo data, seeded only under the
//  `-uiTestChangeOrder` launch arg: a $1,000 invoice with $300 paid and one APPROVED, not-yet-added
//  change order of +$200. The change order must NOT affect the balance until it's added to the invoice;
//  adding it must bill it exactly once.

import XCTest

final class ChangeOrderBalanceUITests: GLUITestCase {
    /// The fixture dataset, on top of the base demo launch.
    override class var extraLaunchArguments: [String] { ["-uiTestChangeOrder"] }

    func testApprovedChangeOrderEntersBalanceOnlyWhenAdded() {
        // Open the fixture invoice. The records lists moved one push deeper in the 2026-08-22
        // restructure: Menu ▸ My Business Details ▸ All Documents ▸ All Invoices.
        app.openRecordsHub()
        app.openRecordsList("All Invoices")
        let invoiceRow = app.staticTexts["INV-0099"]
        XCTAssertTrue(invoiceRow.waitForExistence(timeout: 10), "fixture invoice INV-0099 not found")
        invoiceRow.tap()

        // Before adding: balance = $1,000 − $300 = $700. The $200 change order is NOT counted yet.
        XCTAssertTrue(app.staticTexts["$700.00"].waitForExistence(timeout: 10),
                      "balance should be $700.00 before the change order is added")
        XCTAssertFalse(app.staticTexts["$900.00"].exists,
                       "balance must not include the change order before it's added")

        // The approved change order is surfaced in the invoice with an inline Add-to-invoice
        // button. It sits below the totals, so it is scrolled into reach before the tap.
        let addButton = app.buttons["Add to invoice"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "'Add to invoice' button missing")
        XCTAssertTrue(app.scrollUntilHittable(addButton),
                      "'Add to invoice' should scroll on screen. \(app.visibleSummary())")
        addButton.tap()

        // After adding: total $1,200, balance $1,200 − $300 = $900 (billed exactly once).
        XCTAssertTrue(app.staticTexts["$900.00"].waitForExistence(timeout: 10),
                      "balance should update to $900.00 once the change order is added")
    }
}
