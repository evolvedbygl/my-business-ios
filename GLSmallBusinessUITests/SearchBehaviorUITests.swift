//  SearchBehaviorUITests.swift
//  GLSmallBusinessUITests
//
//  How the in-list search behaves, on screen:
//  - F51: a Price Sheet search with no matches kept "No Results" but dropped the search field
//    itself, so the person couldn't clear it and had to leave the screen.
//  - F129 / L9: All Jobs pushed from All Documents used the system nav-bar search while every
//    other pushed record list uses the in-list search row.
//  - F130: the lists with an in-list search field left the keyboard up on scroll and on a tap
//    outside the field, until some form had happened to install the tap recognizer.

import XCTest

final class SearchBehaviorUITests: GLUITestCase {

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// GoldLifeUI's in-list search field (`GLInListSearchHeader`, identifier `inListSearchField`)
    /// with this prompt. Addressed by prompt too: the Customers list under the Menu sheet keeps its
    /// own in-list field in the tree.
    private func inListSearchField(_ prompt: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ AND placeholderValue == %@", "inListSearchField", prompt)).firstMatch
    }

    /// Any OTHER search field with this prompt: the system `.searchable` one.
    private func systemSearchField(_ prompt: String) -> XCUIElement {
        app.searchFields.matching(NSPredicate(
            format: "identifier != %@ AND placeholderValue == %@", "inListSearchField", prompt)).firstMatch
    }

    func testPriceSheetNoMatchSearchKeepsTheFieldAndClearingRestoresTheRows() throws {
        try XCTSkipIf(isPad, "The iPhone Menu path.")
        app.openRecordsHub()
        app.openRecordsList("Price Sheet")
        let addFirst = app.buttons["Add First Item"]
        XCTAssertTrue(addFirst.waitForExistence(timeout: 5), "The demo Price Sheet should start empty.")
        addFirst.tap()
        let name = app.textFields["Service or item name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The New Catalog Item form should open.")
        XCTAssertTrue(name.tapForKeyboardFocus(), "The name field should take the keyboard.")
        name.typeText("Uitest Tile")
        XCTAssertTrue(name.waitForValue("Uitest Tile"), "The name should land in full.")
        app.buttons["Save"].tap()

        let item = app.staticTexts["Uitest Tile"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "The saved item should be listed.")
        let field = inListSearchField("Search services & materials")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "A Price Sheet with items shows its search row.")
        XCTAssertTrue(field.tapForKeyboardFocus(), "The search field should take the keyboard.")
        field.typeText("zzz")

        XCTAssertTrue(app.staticTexts["No Results for “zzz”"].waitForExistence(timeout: 5)
                      || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "No Results")).firstMatch.exists,
                      "A search with no matches should say so. \(app.visibleSummary())")
        attachShot("price-sheet-no-match")
        XCTAssertTrue(field.exists, "The search field must stay on screen after a search with no matches.")
        XCTAssertTrue(field.waitForValue("zzz"), "The field should still hold the search.")

        let clear = app.buttons["Clear search"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "The field's clear button should be reachable.")
        clear.tap()
        XCTAssertTrue(app.staticTexts["Uitest Tile"].waitForExistence(timeout: 5),
                      "Clearing the search should bring the rows back.")
    }

    func testAllJobsFromAllDocumentsUsesTheInListSearchField() throws {
        try XCTSkipIf(isPad, "The iPhone Menu path; the iPad column is checked by the source.")
        app.openRecordsHub()
        app.openRecordsList("All Jobs")
        XCTAssertTrue(inListSearchField("Search jobs").waitForExistence(timeout: 5),
                      "Pushed All Jobs should search through the in-list row, like its siblings. \(app.visibleSummary())")
        XCTAssertFalse(systemSearchField("Search jobs").exists,
                       "Pushed All Jobs should have no system search field.")
        attachShot("all-jobs-pushed-in-list-search")
    }

    /// The Contracts tab root keeps the system search behind its toolbar magnifying glass, and has
    /// no in-list row.
    func testContractsTabRootKeepsTheToolbarSearch() throws {
        try XCTSkipIf(isPad, "The iPhone Contracts tab.")
        app.tabBars.buttons["Contracts"].tap()
        XCTAssertTrue(app.glNavBar("Contracts").waitForExistence(timeout: 5), "The Contracts tab should open.")
        XCTAssertFalse(inListSearchField("Search contracts").exists, "The Contracts tab root has no in-list search row.")
        let glass = app.buttons["Search contracts"]
        XCTAssertTrue(glass.waitForExistence(timeout: 5), "The Contracts root shows its magnifying glass.")
        glass.tap()
        XCTAssertTrue(systemSearchField("Search contracts").waitForExistence(timeout: 5),
                      "The magnifying glass should open the system search. \(app.visibleSummary())")
    }

    func testScrollingAListDismissesTheSearchKeyboard() throws {
        try XCTSkipIf(isPad, "The iPhone Customers list.")
        app.openContacts("Customers")
        XCTAssertTrue(app.row("Carter, Danielle").waitForExistence(timeout: 10),
                      "The demo Customers list should list Danielle Carter.")
        let field = inListSearchField("Search customers")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The Customers search row should be on screen.")
        XCTAssertTrue(field.tapForKeyboardFocus(), "The search field should take the keyboard.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Search should raise the keyboard.")

        app.collectionViews.firstMatch.swipeUp()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5),
                      "Scrolling the list should put the keyboard away.")
    }

    func testTappingOutsideTheFieldDismissesTheSearchKeyboard() throws {
        try XCTSkipIf(isPad, "The iPhone Customers list.")
        // Fresh launch straight to Customers: no form or Menu has opened yet, so nothing else has
        // installed the app's tap-outside recognizer on the window.
        app.openContacts("Customers")
        let field = inListSearchField("Search customers")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The Customers search row should be on screen.")
        XCTAssertTrue(field.tapForKeyboardFocus(), "The search field should take the keyboard.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Search should raise the keyboard.")

        let bar = app.glNavBar("Customers")
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "The Customers bar should be on screen.")
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5),
                      "A tap outside the field should put the keyboard away.")
    }

    private func attachShot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
