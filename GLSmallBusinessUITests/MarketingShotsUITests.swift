//  MarketingShotsUITests.swift
//  GLSmallBusinessUITests
//
//  Captures real, in-shell app screenshots for the marketing website + App Store. Driven entirely by
//  environment variables so ONE test method can capture any slice of the full screenshot matrix
//  (screen list × light/dark × plain/brand × orientation). The driver script
//  `Scripts/regenerate-screenshots.sh` invokes this once per variant and stitches the whole matrix
//  together; run it on every version bump so every website screenshot is refreshed and nothing is
//  overlooked. Not a real test — it makes no assertions.
//
//  Environment (read from the UI-test process; the driver passes them via `TEST_RUNNER_` prefixes,
//  which xcodebuild forwards to the runner with the prefix stripped):
//    MB_SCREENS comma-separated -demoScreen names to capture (default: the full plain iPhone set).
//    MB_BRAND "1" → launch the app with -demoBrand (white-label sample logo).
//    MB_DARK "1" → launch the app with -demoDark (forces dark appearance).
//    MB_LANDSCAPE "1" → rotate to landscape before capturing (iPad marketing shots).
//
//  Each screen is attached as "shot-<screen>"; the driver renames per the manifest.

import XCTest

final class MarketingShotsUITests: XCTestCase {
    /// The full plain iPhone set (also the default when MB_SCREENS is unset). `stripe` is FIRST so
    /// the idempotent demo seed turns on the connected Stripe state before any other screen is
    /// captured.
    private let defaultScreens = ["stripe", "company", "receipts", "customers", "1099",
                                  "employees", "stats", "estimate", "subcontractors", "invoice", "calendar"]

    func testCapture() throws {
        let env = ProcessInfo.processInfo.environment
        // A screenshot DRIVER (11 launches, 66s of sleeps, zero assertions), not a regression test
        // — it only runs when the screenshot script asks for it. Belt-and-braces with the test
        // plans' skip.
        guard env["MB_SCREENS"] != nil || env["MB_MARKETING"] == "1" else {
            throw XCTSkip("screenshot driver — run via the regenerate-screenshots script")
        }
        let screens = (env["MB_SCREENS"].map { $0.split(separator: ",").map(String.init) } ?? defaultScreens)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let brand = env["MB_BRAND"] == "1"
        let dark = env["MB_DARK"] == "1"
        let landscape = env["MB_LANDSCAPE"] == "1"

        for screen in screens {
            let app = XCUIApplication()
            var args = ["-demoMode", "-demoScreen", screen]
            if brand { args.append("-demoBrand") }
            if dark { args.append("-demoDark") }
            app.launchArguments = args
            app.launch()
            XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
            _ = app.wait(for: .runningForeground, timeout: 10)
            sleep(6)   // let the demo deep-link navigate and the shell settle (PDF-heavy screens included)
            let shot = XCUIScreen.main.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.lifetime = .keepAlways
            att.name = "shot-\(screen)"
            add(att)
            app.terminate()
        }
    }
}
