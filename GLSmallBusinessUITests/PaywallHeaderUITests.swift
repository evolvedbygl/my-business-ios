//  PaywallHeaderUITests.swift GLSmallBusinessUITests
//
//  QA audit L17, on screen: the paywall's header sentence is shown IN FULL, at the default text
//  size and at an accessibility size. It used to end in "Every…" because the store's header slot
//  cut it after two lines (an accessibility label still reads whole, so this test measures the
//  rendered height of the sentence, not its text).

import XCTest

final class PaywallHeaderUITests: GLUITestCase {

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func openPaywall() {
        let menu = app.buttons["Menu"]
        if !menu.waitForExistence(timeout: 10) {
            app.tabBars.buttons["Contacts"].firstMatch.tap()
        }
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "the Menu button should show")
        menu.tap()
        let row = app.buttons["Subscription"].firstMatch
        var tries = 0
        while !row.isHittable && tries < 6 { app.swipeUp(); tries += 1 }
        row.tap()
        let subscribe = app.buttons["Subscribe"].firstMatch
        // A larger text size pushes the button below the fold of a lazy list: scroll to it.
        _ = subscribe.waitForExistence(timeout: 5)
        var swipes = 0
        while !subscribe.isHittable && swipes < 10 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(subscribe.isHittable, "the Subscription screen should offer Subscribe")
        subscribe.tap()
    }

    private func assertWholeSentence(_ label: String) {
        let text = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Everything you’ve already created stays yours either way")).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 15), "\(label): the header sentence should show")
        let window = app.windows.firstMatch.frame
        // Three or more lines: a clipped header is exactly two.
        XCTAssertGreaterThan(text.frame.height, 55, "\(label): the sentence is cut short (h=\(text.frame.height))")
        XCTAssertLessThanOrEqual(text.frame.maxX, window.width, "\(label): the sentence runs off the right edge")
        attach("paywall-header-\(label)")
    }

    func testTheHeaderSentenceIsWholeAtTheDefaultSize() {
        openPaywall()
        assertWholeSentence("default")
    }

    func testTheHeaderSentenceIsWholeAtAnAccessibilitySize() {
        relaunch(adding: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        openPaywall()
        assertWholeSentence("accessibility")
    }
}
