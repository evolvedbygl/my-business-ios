//  ReadableWidthUITests.swift GLSmallBusinessUITests
//
//  Audit 2026-10-03 C66, on screen. On a wide screen (iPhone landscape, iPad) the standing notice
//  card and the list under it share ONE readable column: no wider than 640 pt, and both centred on
//  the same line. The old screens held the card to 640 while the rows ran the whole width, so on
//  iPad the card floated narrower than the list it sat on.
//
//  Launches WITHOUT `-demoMode` and takes the gate's sample door (the simulator must be signed
//  out), the same way PushedScreenBannerUITests does.

import XCTest

final class ReadableWidthUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestNoAnimations", "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        app.launch()
    }

    override func tearDown() {
        if testRun?.hasSucceeded == false, let app, app.state != .notRunning {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "a11y-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .portrait
        }
        super.tearDown()
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private var card: XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Exploring sample data")).firstMatch
    }

    func testTheCardAndTheListShareOneColumnOnAWideScreen() {
        let sampleDoor = app.buttons["Explore with sample data"]
        if !card.waitForExistence(timeout: 3) {
            XCTAssertTrue(sampleDoor.waitForExistence(timeout: 15),
                          "The gate should offer sample data (is the simulator signed in?). \(app.debugDescription.prefix(400))")
            sampleDoor.tap()
            XCTAssertTrue(card.waitForExistence(timeout: 15), "the sample should open")
        }
        // iPad lands on the split view; its Customers pane is the same list.
        let contacts = app.tabBars.buttons["Contacts"].firstMatch
        if contacts.waitForExistence(timeout: 5) { contacts.tap() }

        let cell = app.cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "a customer row should show. \(app.debugDescription.prefix(400))")
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, 700, "the check needs a wide window (w=\(window.width))")

        let cardFrame = card.frame
        let rowFrame = cell.frame
        XCTAssertLessThanOrEqual(cardFrame.width, 642, "the card runs wider than the column (w=\(cardFrame.width))")
        XCTAssertLessThanOrEqual(rowFrame.width, 642, "the rows run wider than the column (w=\(rowFrame.width))")
        XCTAssertEqual(cardFrame.midX, rowFrame.midX, accuracy: 2, "the card and the rows are not on one centre line")
        attach("readable-column-contacts")
    }
}
