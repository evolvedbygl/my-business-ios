//  PushedScreenBannerUITests.swift GLSmallBusinessUITests
//
//  Audit 2026-10-03 F34, on screen. The standing notice (here: the sample-data card) rides under
//  the bar of the Menu, What's New, How To and About, WHOLE: in its own gutter, its sentence
//  readable, and tappable above the page. The old screens showed none of it, or showed a card whose
//  sentence a title margin had pushed down or in.
//
//  Launches WITHOUT `-demoMode` (that DEBUG harness skips the gate); the simulator must be signed
//  out so the gate offers the sample door.

import XCTest

final class PushedScreenBannerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestNoAnimations", "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()
    }

    override func tearDown() {
        if testRun?.hasSucceeded == false, let app, app.state != .notRunning {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "a11y-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        super.tearDown()
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private var card: XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Exploring sample data")).firstMatch
    }

    /// The card is on screen, tappable, and sits in the screen's own gutter at (almost) full width.
    private func assertWholeCard(on screen: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(card.waitForExistence(timeout: 10), "\(screen): the notice card should show. \(app.debugDescription.prefix(400))",
                      file: file, line: line)
        let frame = card.frame
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(frame.minX, 24, "\(screen): the card is pushed in from the left (x=\(frame.minX))", file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.width, window.width - 56, "\(screen): the card is narrowed (w=\(frame.width))", file: file, line: line)
        XCTAssertTrue(card.isHittable, "\(screen): the card is covered", file: file, line: line)
        attach("banner-\(screen)")
    }

    func testTheNoticeShowsWholeOnTheMenuWhatsNewHowToAndAbout() {
        let sampleDoor = app.buttons["Explore with sample data"]
        if !card.waitForExistence(timeout: 3) {
            XCTAssertTrue(sampleDoor.waitForExistence(timeout: 15),
                          "The gate should offer sample data (is the simulator signed in?). \(app.debugDescription.prefix(400))")
            sampleDoor.tap()
            XCTAssertTrue(card.waitForExistence(timeout: 15), "the sample should open")
        }
        let contacts = app.tabBars.buttons["Contacts"].firstMatch
        XCTAssertTrue(contacts.waitForExistence(timeout: 10))
        contacts.tap()
        let menu = app.buttons["Menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        XCTAssertTrue(app.buttons["Gold Life ID"].firstMatch.waitForExistence(timeout: 5))

        assertWholeCard(on: "menu")

        for (row, name) in [("What’s New", "whats-new"), ("How To", "how-to"), ("About", "about")] {
            let link = app.buttons[row].firstMatch
            var tries = 0
            while !link.isHittable && tries < 6 { app.swipeUp(); tries += 1 }
            XCTAssertTrue(link.isHittable, "the \(row) row should be reachable")
            link.tap()
            assertWholeCard(on: name)
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["Gold Life ID"].firstMatch.waitForExistence(timeout: 5)
                          || app.buttons[row].firstMatch.waitForExistence(timeout: 5))
        }
    }
}
