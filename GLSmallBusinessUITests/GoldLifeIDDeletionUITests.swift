//  GoldLifeIDDeletionUITests.swift GLSmallBusinessUITests
//
//  Audit 2026-10-03 F1: Menu → Gold Life ID → Delete my Gold Life ID. My Business's own row holds
//  data and has a LIVE Delete (it used to read "open that app and delete it there", the app the
//  person was already in, with no button, so the Gold Life ID could never go). After the erase the
//  row reads empty and "Delete my Gold Life ID" turns on.
//
//  Runs on a STUBBED inventory (-uiTestStubGoldLifeIDDeletion, DEBUG only): a fixed list and Gold
//  Life ID. The erase is the shipping sequence and the shipping local wipe, run on the mounted,
//  seeded demo store; only the network step is replaced (it flips the stubbed row) and the sync
//  calls are skipped (a demo run has no engine). No account, no network. The shape that has trapped
//  before: another tab's detail stays pushed under the Menu sheet while the store empties. The
//  erase now takes the signed-in screens down, empties the store, mounts it again and puts Delete
//  Account back on screen (`MBStoreRemount`), so the person lands on step two with nothing of the
//  old screens left to trap. When TEST_RUNNER_MB_PROOF_DIR is set, the screens are saved there as
//  PNGs.

import XCTest

final class GoldLifeIDDeletionUITests: GLUITestCase {

    override class var extraLaunchArguments: [String] { ["-uiTestStubGoldLifeIDDeletion"] }

    func testMyBusinessRowErasesHereAndThenTheGoldLifeIDCanGo() {
        // A customer's detail pushed on the Contacts tab, left there under the Menu sheet.
        app.openContacts("Customers")
        let customer = app.row("Nguyen, Sofia")
        XCTAssertTrue(customer.waitForExistence(timeout: 5), "The demo data should list Sofia Nguyen.")
        customer.tap()
        XCTAssertTrue(app.descendants(matching: .any)["sofia@example.com"].waitForExistence(timeout: 5),
                      "Her detail should be pushed. \(app.visibleSummary())")
        app.tabBars.buttons["Contracts"].tap()
        app.buttons["Menu"].tap()
        app.buttons["Gold Life ID"].tap()
        XCTAssertTrue(app.glNavBar("Gold Life ID").waitForExistence(timeout: 5),
                      "Menu → the gold pill should open the Gold Life ID screen.")
        app.scrollToRow("Delete my Gold Life ID").tap()
        XCTAssertTrue(app.glNavBar("Delete Account").waitForExistence(timeout: 5),
                      "The Gold Life ID screen's deletion door should open Delete Account.")

        // Before: My Business holds data, here, with a live Delete; the Gold Life ID is locked.
        XCTAssertTrue(app.staticTexts["This app holds your data."].waitForExistence(timeout: 5),
                      "My Business's own row should say it holds the data. \(app.visibleSummary())")
        XCTAssertFalse(app.staticTexts["Still has your data \u{2014} open that app and delete it there."].exists,
                       "My Business's own row must never send the person to the app they are in.")
        let eraseButton = app.buttons["Delete all My Business data"]
        XCTAssertTrue(eraseButton.exists && eraseButton.isEnabled, "My Business's row should have a live Delete.")
        let identityButton = app.buttons["Delete my Gold Life ID"]
        XCTAssertTrue(identityButton.exists)
        XCTAssertFalse(identityButton.isEnabled, "The Gold Life ID stays locked while an app holds data.")
        saveProof("C17-1-before-erase")

        // The erase: type the Gold Life ID the alert prints, then Delete.
        eraseButton.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "The erase should ask for the Gold Life ID.")
        let confirm = alert.buttons["Delete"]
        XCTAssertFalse(confirm.isEnabled, "Delete stays off until the Gold Life ID is typed.")
        let field = alert.textFields.firstMatch
        XCTAssertTrue(field.tapForKeyboardFocus(), "The Gold Life ID field should take the keyboard.")
        field.typeText("4821-9037")
        XCTAssertTrue(field.waitForValue("4821-9037"), "The typed Gold Life ID should land in full.")
        let typed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: confirm)
        XCTAssertEqual(XCTWaiter().wait(for: [typed], timeout: 5), .completed, "Typing the Gold Life ID turns Delete on.")
        saveProof("C17-2-confirm-erase")
        confirm.tap()
        if alert.exists {
            confirm.tap()
        }

        // After: the screens came down and back, and Delete Account is open again (a sheet over the
        // remounted app). My Business's row reads empty (My Money's already did, so BOTH rows say
        // so), and the Gold Life ID can go.
        let held = app.staticTexts["This app holds your data."]
        XCTAssertTrue(held.waitForNonExistence(timeout: 10),
                      "After the erase My Business's row should stop saying it holds data. \(app.visibleSummary())")
        XCTAssertTrue(app.glNavBar("Delete Account").waitForExistence(timeout: 10),
                      "Delete Account should be back on screen for step two. \(app.visibleSummary())")
        let empty = app.staticTexts.matching(identifier: "Nothing left to delete")
        let bothEmpty = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 2"), object: empty)
        XCTAssertEqual(XCTWaiter().wait(for: [bothEmpty], timeout: 10), .completed,
                       "Both rows should read empty after the erase. \(app.visibleSummary())")
        let reopenedIdentityButton = app.buttons["Delete my Gold Life ID"]
        let unlocked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: reopenedIdentityButton)
        XCTAssertEqual(XCTWaiter().wait(for: [unlocked], timeout: 5), .completed,
                       "Delete my Gold Life ID should turn on once every app is empty.")
        XCTAssertEqual(app.state, .runningForeground, "The local wipe must not take the app down.")
        saveProof("C17-3-after-erase")

        // Back to the app: no trap, and the customer whose detail was pushed under the sheet is gone.
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5), "Delete Account should have a Close button.")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.tabBars.buttons["Contacts"].waitForExistence(timeout: 5),
                      "The app should be back on its tabs. \(app.visibleSummary())")
        app.tabBars.buttons["Contacts"].tap()
        saveProof("C17-4-pushed-detail-after-wipe")
        XCTAssertFalse(app.descendants(matching: .any)["sofia@example.com"].waitForExistence(timeout: 3),
                       "The customer pushed under the sheet was erased; her detail must not still show her. \(app.visibleSummary())")
        XCTAssertFalse(app.row("Nguyen, Sofia").exists, "The erased customer must not be listed. \(app.visibleSummary())")
        XCTAssertEqual(app.state, .runningForeground, "The local wipe must not take the app down.")
    }

    /// The screen as it stands, attached to the run and (when asked) written as a PNG.
    private func saveProof(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let folder = ProcessInfo.processInfo.environment["MB_PROOF_DIR"], !folder.isEmpty else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
