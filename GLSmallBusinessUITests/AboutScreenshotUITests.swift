//  AboutScreenshotUITests.swift — navigates Menu → About and captures a screenshot of the About
//  screen (temporary verification harness).

import XCTest

final class AboutScreenshotUITests: GLUITestCase {

    func testCaptureAboutScreen() throws {
        // Menu → About (the App section's bottom row since the menu-parity pass — About moved off
        // Settings and onto the Menu).
        app.openContacts("Customers")
        app.buttons["Menu"].tap()

        // About is in the Menu's last section, below the fold - the shared helper scrolls.
        app.tapMenuRow("About")

        // The screen renders and is reachable without crashing. (The "More from Gold Life" carousel
        // is intentionally absent until another GL app is live on the App Store, so it is not
        // asserted here.)
        XCTAssertTrue(app.glNavBar("About").waitForExistence(timeout: 5), "About screen should open.")
        XCTAssertTrue(app.staticTexts["My Business"].waitForExistence(timeout: 3), "About header should show the app name.")
        // A Button, not a static text, since fd2828f made the legal rows open the published pages
        // in a WKWebView instead of leaving the app via a Link.
        XCTAssertTrue(app.row("Terms of Use").waitForExistence(timeout: 3), "Legal & Support should render.")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "about"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
