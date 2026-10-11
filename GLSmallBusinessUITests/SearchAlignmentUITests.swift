//  SearchAlignmentUITests.swift GLSmallBusinessUITests
//
//  (search alignment parity), measured on screen: the search capsule's left and right edges sit
//  exactly on the cards' edges, on a plain list (Customers) and on a grouped-skin list (Price
//  Sheet). The source scan (SearchGutterTests) checks the call sites; this checks the pixels,
//  because the Price Sheet passed a scan while its search sat 8 pt inside its cards.
//
//  The capsule is found by GoldLifeUI's `<field identifier>.capsule` container. Customers' cards
//  have no element of their own: PersonRowCard draws its card `GLLayout.rowCardInset` (8 pt) inside
//  the full-width plain-list cell, so the card edges are the cell's edges moved in by 8. The Price
//  Sheet's grouped cards ARE the list cells.

import XCTest

final class SearchAlignmentUITests: GLUITestCase {

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// `GLTheme.gutter`, which is also `GLLayout.rowCardInset`, PersonRowCard's card
    /// inside its row.
    private let gutter: CGFloat = 8

    private var searchCapsule: XCUIElement {
        app.otherElements["inListSearchField.capsule"].firstMatch
    }

    func testCustomersSearchLinesUpWithTheCards() throws {
        try XCTSkipIf(isPad, "The iPhone Customers list; the iPad column is a split-view sidebar.")
        app.openContacts("Customers")
        let row = app.row("Carter, Danielle")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The demo Customers list should list Danielle Carter.")
        XCTAssertTrue(searchCapsule.waitForExistence(timeout: 5), "The Customers search row should be on screen.")
        attachShot("customers-search-alignment")

        let cell = app.cells.containing(NSPredicate(format: "label == %@", "Carter, Danielle")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Danielle Carter's row should be a list cell.")
        let capsule = searchCapsule.frame
        let card = cell.frame.insetBy(dx: gutter, dy: 0)
        XCTAssertEqual(capsule.minX, card.minX, accuracy: 0.5, "The search capsule's left edge should sit on the cards'.")
        XCTAssertEqual(capsule.maxX, card.maxX, accuracy: 0.5, "The search capsule's right edge should sit on the cards'.")
        XCTAssertEqual(capsule.minX, gutter, accuracy: 0.5, "Customers' search should sit on the 8 pt gutter.")
    }

    func testPriceSheetSearchLinesUpWithTheCards() throws {
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
        XCTAssertTrue(searchCapsule.waitForExistence(timeout: 5), "A Price Sheet with items shows its search row.")
        let cell = app.cells.containing(.staticText, identifier: "Uitest Tile").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "The item's card should be a list cell.")
        attachShot("price-sheet-search-alignment")

        let capsule = searchCapsule.frame
        XCTAssertEqual(capsule.minX, cell.frame.minX, accuracy: 0.5, "The search capsule's left edge should sit on the cards'.")
        XCTAssertEqual(capsule.maxX, cell.frame.maxX, accuracy: 0.5, "The search capsule's right edge should sit on the cards'.")
        XCTAssertEqual(capsule.minX, gutter, accuracy: 0.5, "The Price Sheet's search should sit on the 8 pt gutter, like Customers'.")
    }

    private func attachShot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
