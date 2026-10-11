//  SendFilesProofUITests.swift GLSmallBusinessUITests
//
//  Simulator proof for and F30, against the demo fixture invoice INV-0099 (`-uiTestChangeOrder`):
//  three photos picked onto an invoice reach the share sheet as three different files, and the
//  change order screen has no empty "…" button.

import XCTest

final class SendFilesProofUITests: GLUITestCase {
    override class var extraLaunchArguments: [String] { ["-uiTestChangeOrder"] }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openFixtureInvoice() {
        app.openRecordsHub()
        app.openRecordsList("All Invoices")
        let invoiceRow = app.staticTexts["INV-0099"]
        XCTAssertTrue(invoiceRow.waitForExistence(timeout: 10), "fixture invoice INV-0099 not found")
        invoiceRow.tap()
    }

    func testThreePickedPhotosShareAsThreeFiles() {
        openFixtureInvoice()

        let addPhotos = app.buttons["Add photos"]
        XCTAssertTrue(addPhotos.waitForExistence(timeout: 10), "Add photos missing. \(app.visibleSummary())")
        XCTAssertTrue(app.scrollUntilHittable(addPhotos), "Add photos should scroll on screen")
        if addPhotos.frame.maxY > 750 {
            app.swipeUp()
        }
        addPhotos.tap()

        // The system photo picker (out of process): wait for the library grid, pick three, then Add.
        let pickerPhotos = app.images.matching(identifier: "PXGGridLayout-Info")
        XCTAssertTrue(pickerPhotos.firstMatch.waitForExistence(timeout: 40), "photo picker didn't load. \(app.debugDescription)")
        var tapped = 0
        for index in 0..<pickerPhotos.count {
            let photo = pickerPhotos.element(boundBy: index)
            if photo.exists {
                photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                tapped += 1
                if tapped == 3 { break }
            }
        }
        XCTAssertEqual(tapped, 3, "Expected to select 3 photos")
        shot("picker-3-selected")
        let addOrDone = app.buttons["Done"].firstMatch.exists ? app.buttons["Done"].firstMatch : app.buttons["Add"].firstMatch
        XCTAssertTrue(addOrDone.waitForExistence(timeout: 10), "picker Add/Done button missing. \(app.debugDescription)")
        addOrDone.tap()

        XCTAssertTrue(app.buttons["Add more photos"].waitForExistence(timeout: 20), "photos weren't attached")
        shot("invoice-with-3-photos")

        let share = app.buttons["Share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        // The quick action bar sits above the photos: scroll back up to it.
        for _ in 0..<8 where !share.isHittable { app.swipeDown() }
        XCTAssertTrue(share.isHittable, "Share should be on screen. \(app.visibleSummary())")
        share.tap()
        // The share sheet is up: give the host time to inspect this send's folder on disk.
        sleep(4)
        shot("share-sheet")
        sleep(20)
        shot("share-sheet-later")
    }

    func testChangeOrderHasNoEmptyMoreButton() {
        openFixtureInvoice()
        let changeOrder = app.staticTexts["CO-0001"].firstMatch
        XCTAssertTrue(changeOrder.waitForExistence(timeout: 10), "CO-0001 missing. \(app.visibleSummary())")
        XCTAssertTrue(app.scrollUntilHittable(changeOrder))
        changeOrder.tap()
        XCTAssertTrue(app.buttons["Email"].waitForExistence(timeout: 10), "change order detail didn't open")
        XCTAssertFalse(app.navigationBars.buttons["More"].exists, "an empty … menu is still in the toolbar")
        shot("change-order-toolbar")
    }
}
