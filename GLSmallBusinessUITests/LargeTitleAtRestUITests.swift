//  LargeTitleAtRestUITests.swift GLSmallBusinessUITests
//
//  a pushed screen opens with its LARGE title showing at rest. Reached by normal navigation, the
//  way a person gets there.

import XCTest

final class LargeTitleAtRestUITests: GLUITestCase {

    func testCustomerMoreInfoOpensWithLargeTitle() {
        app.openContacts("Customers")
        app.scrollToRow("Carter, Danielle").tap()
        // The hub is long: reaching its More Info row scrolls it, the way a person does.
        app.scrollToRow("More Info").tap()
        assertLargeTitleAtRest("More Info", shotName: "customer-more-info-at-rest")
    }

    func testEstimateDetailOpensWithLargeTitle() {
        app.openContacts("Customers")
        app.scrollToRow("Reed, Marcus").tap()
        tapFirstButton(startingWith: "Estimates")
        tapFirstButton(startingWith: "Master Bath")
        assertLargeTitleAtRest("EST-", shotName: "estimate-detail-at-rest")
    }

    /// The control: Invoice detail always opened large.
    func testInvoiceDetailOpensWithLargeTitle() {
        app.openContacts("Customers")
        app.scrollToRow("Carter, Danielle").tap()
        tapFirstButton(startingWith: "Invoices")
        tapFirstButton(startingWith: "Luxury Vinyl")
        assertLargeTitleAtRest("INV-", shotName: "invoice-detail-at-rest")
    }

    private func tapFirstButton(startingWith prefix: String) {
        let query = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
        var swipes = 0
        while !(query.firstMatch.exists && query.firstMatch.isHittable) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(query.firstMatch.isHittable, "\(prefix)… should be on screen. \(app.visibleSummary())")
        query.firstMatch.tap()
    }

    /// Lets the screen settle, then checks the bar is in its LARGE state (the title on its own line
    /// below the bar's buttons) and that the title's area actually carries ink.
    private func assertLargeTitleAtRest(_ title: String, shotName: String) {
        let bar = app.glNavBar(title)
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "\(title) should open. \(app.visibleSummary())")
        Thread.sleep(forTimeInterval: 2)
        let screenshot = app.screenshot()
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = shotName
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertGreaterThan(bar.frame.height, 80, "At rest \(title) should show the large title, not the inline one.")
        let label = bar.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(label.exists, "The bar should carry the \(title) title. \(app.visibleSummary())")
        let back = bar.buttons.firstMatch
        if back.exists {
            XCTAssertGreaterThan(label.frame.minY, back.frame.maxY - 1, "The large title sits below the bar's buttons.")
        }
        let ink = HowToTitleUITests.inkFraction(in: label.frame, of: screenshot.image,
                                                pointsWide: app.windows.firstMatch.frame.width)
        XCTAssertGreaterThan(ink, 0.02, "The \(title) large title should be drawn at rest (ink \(ink)).")
    }
}
