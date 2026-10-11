//  CoverageExpansionUITests.swift GLSmallBusinessUITests
//
//  Reaches the remaining heavy screens that the other suites don't: an estimate's detail, the new-
//  estimate form, and the Statistics screen. Opening them guards their navigation and exercises a
//  lot of otherwise-untouched view code.

import XCTest

final class CoverageExpansionUITests: GLUITestCase {

    func testEstimateDetailOpens() {
        openCarterEstimates()
        app.staticTexts["EST-0002"].tap()
        XCTAssertTrue(app.glNavBar("EST-0002").waitForExistence(timeout: 5),
                      "Tapping an estimate should open its detail.")
    }

    func testNewEstimateFormOpens() {
        openCarterEstimates()
        // (one-option menus banned): the "More" menu is gone — the list now shows a permanent "+"
        // navbar button (a11y label "New Estimate") alongside a direct "Select".
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.textFields["Job title"].waitForExistence(timeout: 5),
                      "New Estimate should open the estimate form.")
    }

    func testStatisticsOpens() {
        app.openContacts("Customers")
        app.buttons["Menu"].tap()
        // "Business" is the Menu's SECTION HEADER, not a row — the old `staticTexts["Business"]`
        // tap landed on the header, went nowhere, and then searched the Menu for a Statistics row
        // that lives one screen deeper. The company hub is opened by "My Business Details".
        app.tapMenuRow("My Business Details")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        app.tapMenuRow("Income & Expenses")

        // The period picker sits at the top of Statistics and renders regardless of data.
        XCTAssertTrue(app.buttons["Year"].waitForExistence(timeout: 5),
                      "Statistics should open with its period picker.")
    }

    /// Customers → Danielle Carter → her Estimates list (she has EST-0002 in the demo data).
    private func openCarterEstimates() {
        app.openContacts("Customers")
        app.staticTexts["Carter, Danielle"].tap()
        app.staticTexts["Estimates"].tap()
        XCTAssertTrue(app.glNavBar("Estimates").waitForExistence(timeout: 5),
                      "The customer's Estimates list should open.")
    }
}
