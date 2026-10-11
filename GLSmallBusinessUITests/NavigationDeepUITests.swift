//  NavigationDeepUITests.swift GLSmallBusinessUITests
//
//  Opens the heavier detail/list screens (employee + subcontractor hubs, the Job-Records lists, an
//  invoice's detail). These are the largest views in the app, so reaching them both guards their
//  navigation and meaningfully exercises their code.

import XCTest

final class NavigationDeepUITests: GLUITestCase {

    func testEmployeeHubAndMoreInfoOpen() {
        app.openContacts("Employees")
        app.staticTexts["Caldwell, Owen"].tap()
        XCTAssertTrue(app.glNavBar("Caldwell, Owen").waitForExistence(timeout: 5),
                      "Tapping an employee row should open that employee's hub.")
        app.buttons["More Info"].tap()
        XCTAssertTrue(app.staticTexts["Email"].waitForExistence(timeout: 5),
                      "More Info should push the employee's details.")
    }

    func testSubcontractorHubAndMoreInfoOpen() {
        app.openContacts("Subcontractors")
        app.staticTexts["Mendoza, Luis"].tap()
        XCTAssertTrue(app.glNavBar("Mendoza, Luis").waitForExistence(timeout: 5),
                      "Tapping a subcontractor row should open that subcontractor's hub.")
        app.buttons["More Info"].tap()
        XCTAssertTrue(app.staticTexts["Email"].waitForExistence(timeout: 5),
                      "More Info should push the subcontractor's details.")
    }

    func testJobRecordsListsOpen() {
        app.openRecordsHub()
        openListThenBack("All Estimates")
        openListThenBack("All Invoices")
        openListThenBack("All Change Orders")
        // Renamed from "All Receipts" in the 2026-09-01 IA audit — row AND bar title.
        openListThenBack("All Expenses")
    }

    func testInvoiceDetailOpens() {
        app.openRecordsHub()
        app.openRecordsList("All Invoices")
        app.staticTexts["INV-0001"].tap()
        // The detail's bar is titled with the invoice number, so arrival is asserted positively — a
        // negative wait on the list's bar passed for three idle seconds on ANY screen.
        XCTAssertTrue(app.glNavBar("INV-0001").waitForExistence(timeout: 5),
                      "Tapping an invoice should open its detail, bar titled INV-0001. \(app.visibleSummary())")
    }

    /// The Contracts root's + booking menu
    /// must open the contract form.
    func testContractsRootBookingFlowOpensForm() {
        app.tabBars.buttons["Contracts"].tap()
        XCTAssertTrue(app.glNavBar("Contracts").waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        app.buttons["New contract"].tap()
        XCTAssertTrue(app.glNavBar("New Contract").waitForExistence(timeout: 5),
                      "Contracts tab + -> New contract should push the contract form.")
    }

    /// The flip-takes-the-keyboard contract (QA-found: the hidden pane's search field kept first
    /// responder and keystrokes filtered the INVISIBLE list).
    func testSegmentFlipDismissesSearchKeyboard() throws {
        app.openContacts("Customers")
        let field = app.searchFields["Search customers"]
        guard field.waitForExistence(timeout: 5) else {
            throw XCTSkip("In-list search field not exposed to automation on this run.")
        }
        field.tap()
        field.typeText("zz")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "Opening search should raise the keyboard.")
        app.openContacts("Employees")
        XCTAssertTrue(app.glNavBar("Employees").waitForExistence(timeout: 5))
        XCTAssertFalse(app.keyboards.firstMatch.exists,
                       "A segment flip must dismiss the hidden pane's keyboard.")
    }

    /// Taps a Job-Records row (scrolling the sheet to it if it's below the fold), confirms the list
    /// opened, then returns to the Menu. Open one records list from the ALL DOCUMENTS hub and come
    /// back to it.
    private func openListThenBack(_ title: String) {
        app.openRecordsList(title)
        app.glNavBar(title).buttons.firstMatch.tap()
        XCTAssertTrue(app.glNavBar("Documents").waitForExistence(timeout: 5),
                      "Back from \(title) should land on the records hub.")
    }
}
