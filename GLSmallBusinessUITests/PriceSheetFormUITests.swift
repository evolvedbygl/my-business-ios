//  PriceSheetFormUITests.swift GLSmallBusinessUITests
//
//  data-entry screens PUSH, and an unsaved edit is never lost to a stray gesture (so a swipe down
//  threw a half-typed item away). Pushed, it carries the house guard: once edited, Back asks
//  "Discard changes?" first.

import XCTest

final class PriceSheetFormUITests: GLUITestCase {

    func testEditedNewItemAsksBeforeDiscarding() {
        openPriceSheet()
        app.buttons["New Catalog Item"].tap()
        XCTAssertTrue(app.glNavBar("New Catalog Item").waitForExistence(timeout: 5),
                      "+ should push the new item form. \(app.visibleSummary())")

        let name = app.textFields["Service or item name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Grout sealing")

        let back = app.buttons["discardBackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5),
                      "An edited form swaps in the guarded Back button. \(app.visibleSummary())")
        back.tap()
        let alert = app.alerts["Discard changes?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Back on an edited form should ask first.")

        // Keep Editing keeps the entry.
        alert.buttons["Keep Editing"].tap()
        XCTAssertEqual(name.value as? String, "Grout sealing")

        // Discard Changes goes back to the Price Sheet with nothing saved.
        back.tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        XCTAssertTrue(app.glNavBar("Price Sheet").waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Grout sealing"].exists, "A discarded item is not saved.")
    }

    func testUneditedFormGoesBackWithoutAsking() {
        openPriceSheet()
        app.buttons["New Catalog Item"].tap()
        XCTAssertTrue(app.glNavBar("New Catalog Item").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["discardBackButton"].exists, "An untouched form keeps the system Back.")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.glNavBar("Price Sheet").waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Discard changes?"].exists)
    }

    private func openPriceSheet() {
        app.openRecordsHub()
        app.openRecordsList("Price Sheet")
    }
}
