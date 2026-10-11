//  ScreenSweepUITests.swift GLSmallBusinessUITests
//
//  Opens the app's main screens and confirms each one appears. This is the dead-interaction guard:
//  it catches an add button, menu row, list row, or link that silently goes nowhere (the class of
//  bug that left the Insurance rows dead). Opening this many screens also exercises most of the
//  view code.

import XCTest

final class ScreenSweepUITests: GLUITestCase {

    // MARK: - Add forms open (LAW 40 retired the one-option "More" menus: each list now carries a
    // permanent "+" navbar button labeled "Add <Kind>")

    func testAddCustomerFormOpens() {
        app.openContacts("Customers")
        app.buttons["Add Customer"].tap()
        XCTAssertTrue(app.glNavBar("New Customer").waitForExistence(timeout: 5),
                      "Add Customer should open the New Customer form.")
    }

    func testAddEmployeeFormOpens() {
        app.openContacts("Employees")
        app.buttons["Add Employee"].tap()
        XCTAssertTrue(app.glNavBar("New Employee").waitForExistence(timeout: 5),
                      "Add Employee should open the New Employee form.")
    }

    func testAddSubcontractorFormOpens() {
        app.openContacts("Subcontractors")
        app.buttons["Add Subcontractor"].tap()
        XCTAssertTrue(app.glNavBar("New Subcontractor").waitForExistence(timeout: 5),
                      "Add Subcontractor should open the New Subcontractor form.")
    }

    // MARK: - Hubs open from a row, and "More Info" pushes

    func testCustomerHubAndMoreInfoOpen() {
        app.openContacts("Customers")
        app.staticTexts["Carter, Danielle"].tap()
        XCTAssertTrue(app.glNavBar("Carter, Danielle").waitForExistence(timeout: 5),
                      "Tapping a customer row should open that customer's hub.")
        app.buttons["More Info"].tap()
        XCTAssertTrue(app.staticTexts["Email"].waitForExistence(timeout: 5),
                      "More Info should push the customer's details.")
    }

    // MARK: - Menu → company hub → Insurance (the dead-rows regression guard)

    func testMenuOpensCompanyHub() {
        openMenu()
        app.staticTexts["My Business Details"].tap()
        XCTAssertTrue(app.staticTexts["Contact"].waitForExistence(timeout: 5),
                      "Tapping My Business Details should open the company hub.")
    }

    func testInsuranceScreenOpensFromCompanyHub() {
        // Documents live one push deeper since the 2026-08-22 restructure: hub → All Documents →
        // Insurance & Licensing (both below the fold now). The 2026-09-01 IA audit renamed the
        // destination SCREEN to "My Insurance & License"; the row keeps its "Insurance & Licensing"
        // title.
        openMenu()
        app.staticTexts["My Business Details"].tap()
        app.tapMenuRow("Documents")
        app.tapMenuRow("Insurance & Licensing")
        XCTAssertTrue(app.glNavBar("My Insurance & License").waitForExistence(timeout: 5),
                      "The My Insurance & License screen should open from Documents.")
    }

    private func openMenu() {
        app.openContacts("Customers")
        app.buttons["Menu"].tap()
    }
}
