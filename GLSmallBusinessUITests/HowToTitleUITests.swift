//  HowToTitleUITests.swift GLSmallBusinessUITests
//
//  Menu ▸ How To opens with its LARGE title showing at rest. The guides are a live web page, so the
//  test needs the network the walkthroughs use.

import XCTest

final class HowToTitleUITests: GLUITestCase {

    func testHowToShowsLargeTitleAtRest() {
        openHowTo(contacts: "Contacts", menu: "Menu", row: "How To")
        assertLargeTitleDrawn("How To", shotName: "howto-en-at-rest")

        // the large title still collapses to the inline one when the guides scroll.
        app.webViews.firstMatch.swipeUp()
        let bar = app.glNavBar("How To")
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        var height = bar.frame.height
        for _ in 0..<10 where height >= 80 {
            Thread.sleep(forTimeInterval: 0.5)
            height = bar.frame.height
        }
        XCTAssertLessThan(height, 80, "Scrolled, How To should show the inline title.")
        attachScreenshot("howto-en-scrolled")
    }

    func testHowToShowsLargeTitleAtRestInSpanish() {
        relaunch(adding: ["-demoES"])
        openHowTo(contacts: "Contactos", menu: "Menú", row: "Guías")
        assertLargeTitleDrawn("Guías", shotName: "howto-es-at-rest")
    }

    /// About ▸ Privacy Policy opens the fleet's one embed web sheet with its large title drawn.
    func testPrivacyPolicyOpensInTheSharedSheet() {
        app.tabBars.buttons["Contacts"].tap()
        app.buttons["Menu"].tap()
        app.tapMenuRow("About")
        app.tapMenuRow("Privacy Policy")
        assertLargeTitleDrawn("Privacy Policy", shotName: "about-privacy-policy")
        XCTAssertTrue(app.buttons["Done"].exists, "The legal sheet closes with Done.")
    }

    private func openHowTo(contacts: String, menu: String, row: String) {
        app.tabBars.buttons[contacts].tap()
        app.buttons[menu].tap()
        app.tapMenuRow(row)
    }

    /// Waits for the page to load and the bar to settle, then checks the bar's large title is on
    /// its own line AND actually drawn.
    private func assertLargeTitleDrawn(_ text: String, shotName: String) {
        let bar = app.glNavBar(text)
        XCTAssertTrue(bar.waitForExistence(timeout: 10),
                      "\(text) should open. \(app.visibleSummary())")

        // Let the page load and the bar settle, the moment the walkthrough shot showed the blank band.
        let page = app.webViews.firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 20), "The embed web view should appear.")
        _ = page.links.firstMatch.waitForExistence(timeout: 20)
        Thread.sleep(forTimeInterval: 2)

        let title = bar.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
        XCTAssertTrue(title.exists, "The bar should carry the \(text) title. \(app.visibleSummary())")

        // At rest the bar is in its LARGE state: the title on its own line below the back button.
        XCTAssertGreaterThan(bar.frame.height, 80, "At rest \(text) should show the large title.")
        let back = bar.buttons.firstMatch
        if back.exists {
            XCTAssertGreaterThan(title.frame.minY, back.frame.maxY - 1, "The large title sits below the bar's buttons.")
        }

        // Pixel truth: the bar's frames say "large" even when nothing is drawn (the blank band of
        // F35 had exactly these frames), so the title's own area must actually carry ink.
        let screenshot = attachScreenshot(shotName)
        let ink = Self.inkFraction(in: title.frame, of: screenshot.image,
                                   pointsWide: app.windows.firstMatch.frame.width)
        XCTAssertGreaterThan(ink, 0.02, "The \(text) large title should be drawn at rest, not a blank band (ink \(ink)).")
    }

    @discardableResult
    private func attachScreenshot(_ name: String) -> XCUIScreenshot {
        let screenshot = app.screenshot()
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        return screenshot
    }

    /// The share of pixels in `rect` (points) that differ clearly from the area's background (its
    /// top-left pixel): text drawn there gives a few percent, an empty band gives ~0.
    static func inkFraction(in rect: CGRect, of image: UIImage, pointsWide: CGFloat) -> Double {
        guard let cg = image.cgImage, pointsWide > 0 else { return 0 }
        let scale = CGFloat(cg.width) / pointsWide
        let pixels = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                            width: rect.width * scale, height: rect.height * scale).integral
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard let crop = cg.cropping(to: pixels), crop.width > 0, crop.height > 0 else { return 0 }
        let width = crop.width, height = crop.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return 0 }
        func luminance(_ i: Int) -> Double {
            (0.299 * Double(bytes[i]) + 0.587 * Double(bytes[i + 1]) + 0.114 * Double(bytes[i + 2])) / 255
        }
        let background = luminance(0)
        var inked = 0
        for pixel in 0..<(width * height) where abs(luminance(pixel * 4) - background) > 0.25 {
            inked += 1
        }
        return Double(inked) / Double(width * height)
    }
}
