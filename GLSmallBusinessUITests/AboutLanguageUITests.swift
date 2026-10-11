//  AboutLanguageUITests.swift GLSmallBusinessUITests
//
//  Audit 2026-10-03 F72 (2, 53) + L14. On an English iPhone with the app set to Español, Menu >
//  About reads its legal rows, version line and apps header in Spanish, and the Kitchen & Bath card
//  reads the new line (no "3D design") in Spanish. Before the fix those rows were drawn from plain
//  Strings and stayed English.

import XCTest

final class AboutLanguageUITests: GLUITestCase {
    /// The device stays English (the base flags); `-demoES` sets the app's own language to Español.
    override class var extraLaunchArguments: [String] { ["-demoES"] }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAboutReadsInTheAppLanguage() {
        app.tabBars.buttons["Contactos"].tap()
        let menu = app.buttons["Menú"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), app.visibleSummary())
        menu.tap()
        app.tapMenuRow("Acerca de")

        XCTAssertTrue(app.row("Política de privacidad").waitForExistence(timeout: 5), app.visibleSummary())
        XCTAssertTrue(app.row("Términos de uso").exists, app.visibleSummary())
        XCTAssertTrue(app.row("Contactar a soporte").exists, app.visibleSummary())
        let version = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Versión ")).firstMatch
        XCTAssertTrue(version.exists, app.visibleSummary())
        XCTAssertFalse(app.row("Privacy Policy").exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Version ")).firstMatch.exists)
        shot("about-es")

        let kitchenAndBath = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen & Bath.")).firstMatch
        XCTAssertTrue(app.scrollUntilHittable(kitchenAndBath), app.visibleSummary())
        XCTAssertTrue(kitchenAndBath.label.contains("Azulejos, pisos y remodelación llave en mano."), kitchenAndBath.label)
        XCTAssertFalse(kitchenAndBath.label.contains("3D"), kitchenAndBath.label)
        XCTAssertTrue(app.staticTexts["Más apps creadas por Gold Life LLC"].exists
                      || app.otherElements["Más apps creadas por Gold Life LLC"].exists, app.visibleSummary())
        app.swipeUp()   // the whole card on screen for the proof shot
        shot("about-es-kitchen-and-bath-card")
    }
}
