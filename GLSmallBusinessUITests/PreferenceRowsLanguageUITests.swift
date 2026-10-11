//  PreferenceRowsLanguageUITests.swift GLSmallBusinessUITests
//
//  Audit 2026-10-03 F73 (the screen you are on included). On an English iPhone with the app set to
//  Español, Settings > Language and Settings > Appearance read their rows in Spanish. Before the
//  fix the package built the rows with `String(localized:)`, which reads the DEVICE language, so
//  they stayed English.

import XCTest

final class PreferenceRowsLanguageUITests: GLUITestCase {
    /// The device stays English (the base flags); `-demoES` sets the app's own language to Español.
    override class var extraLaunchArguments: [String] { ["-demoES"] }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openSettings() {
        app.tabBars.buttons["Contactos"].tap()
        let menu = app.buttons["Menú"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), app.visibleSummary())
        menu.tap()
        app.tapMenuRow("Ajustes")
    }

    private func openSetting(_ prefix: String) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(app.scrollUntilHittable(row), app.visibleSummary())
        row.tap()
    }

    func testLanguageAndAppearanceRowsFollowTheAppLanguage() {
        openSettings()
        openSetting("Idioma")
        XCTAssertTrue(app.buttons["Sistema"].waitForExistence(timeout: 5), app.visibleSummary())
        XCTAssertTrue(app.buttons["Ajuste del Gold Life ID"].exists, app.visibleSummary())
        XCTAssertFalse(app.buttons["System"].exists)
        XCTAssertFalse(app.buttons["Gold Life ID Setting"].exists)
        shot("settings-language-es")

        app.navigationBars.buttons.firstMatch.tap()
        openSetting("Apariencia")
        XCTAssertTrue(app.buttons["Oscuro"].waitForExistence(timeout: 5), app.visibleSummary())
        XCTAssertTrue(app.buttons["Claro"].exists, app.visibleSummary())
        XCTAssertFalse(app.buttons["Dark"].exists)
        XCTAssertFalse(app.buttons["Light"].exists)
        shot("settings-appearance-es")
    }
}
