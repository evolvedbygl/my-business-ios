//  MenuSignOutWarningUITests.swift
//  GLSmallBusinessUITests
//
//  Audit 2026-10-03 F12, on screen: toggle a Settings option inside the Menu, come back, tap
//  Sign out at once, and the alert names the change that hasn't been backed up. The old Menu
//  counted once when it appeared, before the edit, and showed the plain question.
//  `-uiTestSignOutWarning` (DEBUG) gives the demo store an engine with no session, so the
//  count runs the production fold-then-count path and nothing reaches the network.

import XCTest

final class MenuSignOutWarningUITests: GLUITestCase {
    override class var extraLaunchArguments: [String] { ["-uiTestSignOutWarning"] }

    func testAnEditJustSavedInSettingsIsNamedInTheSignOutAlert() {
        app.openContacts("Customers")
        app.buttons["Menu"].tap()
        app.tapMenuRow("Settings")

        let toggle = app.switches["Show address on documents"]
        XCTAssertTrue(app.scrollUntilHittable(toggle), "Settings should show the address toggle. \(app.visibleSummary())")
        let before = toggle.value as? String
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        let flipped = NSPredicate(format: "value != %@", before ?? "")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: flipped, evaluatedWith: toggle)], timeout: 5), .completed,
                       "the switch did not change (was \(before ?? "nil")). \(app.visibleSummary())")
        let edited = XCTAttachment(screenshot: app.screenshot())
        edited.name = "settings-after-switch"
        edited.lifetime = .keepAlways
        add(edited)

        app.navigationBars.buttons.firstMatch.tap()
        app.tapMenuRow("Sign out")

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Sign out should ask first. \(app.visibleSummary())")
        let warning = alert.staticTexts["1 change hasn’t been backed up yet. If you sign out now, it’s lost. Connect to the internet first to keep it."]
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "sign-out-alert-after-settings-edit"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(warning.exists, "the alert must name the edit just saved: \(alert.debugDescription)")
        alert.buttons["Cancel"].tap()
    }
}
