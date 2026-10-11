//  UserProfileSyncTests.swift GLSmallBusinessTests
//
//  The user_profile row on gl-business-api carries app settings only (contact, address, photo and
//  signature live in the Gold Life ID alone). A push never sends them, and a pull — including an
//  old row the server still holds — never writes them back onto the phone, where the legacy upload
//  would hand them to the Gold Life ID again.

import Testing
import Foundation
import SwiftData
@testable import GLSmallBusiness

@Suite("user_profile sync carries no identity", .serialized)
@MainActor
struct UserProfileSyncTests {

    @Test("A push sends only the app's own settings")
    func pushSendsNoIdentity() throws {
        let container = try TestStore.makeContainer()
        let profile = UserProfile()
        profile.firstName = "Jordan"
        profile.phone = "850-555-0100"
        profile.homeAddress = Address(street1: "1 Main St", city: "Tallahassee", state: "FL", postalCode: "32301")
        profile.photoData = Data([0x01])
        profile.signatureData = Data([0x02])
        profile.useMyNameInEmails = true
        container.mainContext.insert(profile)

        let payload = profile.glSyncPayload()
        #expect(Set(payload.keys) == ["syncID", "updatedAt", "useMyNameInEmails"],
                "user_profile payload keys: \(payload.keys.sorted())")
        #expect(payload["useMyNameInEmails"] as? Bool == true)
        #expect(GLSyncRegistry.entry(for: "user_profile")?.blobFields.isEmpty == true,
                "the photo and signature files still upload to gl-business-api")
    }

    @Test("A pulled row's identity keys are never applied")
    func applyIgnoresIdentity() throws {
        let container = try TestStore.makeContainer()
        let profile = UserProfile()
        container.mainContext.insert(profile)
        profile.glSyncApply([
            "firstName": "Old", "lastName": "Name", "email": "old@example.com", "phone": "000",
            "address": ["street1": "9 Old Rd", "city": "Nowhere", "state": "FL", "postalCode": "1"],
            "useMyNameInEmails": true,
        ], in: container.mainContext)
        #expect(profile.firstName.isEmpty && profile.lastName.isEmpty)
        #expect(profile.email.isEmpty && profile.phone.isEmpty)
        #expect(profile.homeAddress.isEmpty)
        #expect(profile.useMyNameInEmails, "the app-only setting still syncs")
    }

    @Test("Pulling an old server row fetches no photo or signature file")
    func pullFetchesNoIdentityFiles() throws {
        let container = try TestStore.makeContainer()
        let id = UUID()
        let sha = String(repeating: "a", count: 64)
        let row = SyncFix.liveRow(id, type: "user_profile", version: 2, seq: 1, payload: [
            "syncID": id.uuidString, "firstName": "Old",
            "photoData": ["sha256": sha, "name": NSNull()],
            "signatureData": ["sha256": sha, "name": NSNull()],
            "useMyNameInEmails": true,
        ])
        let outcome = try #require(SyncFix.outcome(SyncFix.store(container).applyChanges([row])))
        #expect(outcome.blobFetches.filter { $0.recordType == "user_profile" }.isEmpty,
                "a pulled user_profile asks for \(outcome.blobFetches.map(\.field))")

        let rows = try SyncFix.reader(container).fetch(FetchDescriptor<UserProfile>())
        let landed = try #require(rows.first)
        #expect(landed.firstName.isEmpty && landed.photoData == nil && landed.signatureData == nil)
        #expect(landed.useMyNameInEmails)
    }

    @Test("Bytes for a user_profile file are never written onto the phone")
    func downloadedBytesAreNotApplied() throws {
        let container = try TestStore.makeContainer()
        let profile = UserProfile()
        profile.syncID = UUID()
        container.mainContext.insert(profile)
        container.mainContext.saveChanges()
        let entry = try #require(GLSyncRegistry.entry(for: "user_profile"))
        let id = try #require(profile.syncID)
        let record = try #require(entry.fetch(id, container.mainContext))
        entry.setBlobBytes(record, "signatureData", Data([0x07]))
        entry.setBlobBytes(record, "photoData", Data([0x08]))
        #expect(profile.signatureData == nil && profile.photoData == nil)
        #expect(entry.blobBytes(record).isEmpty)
    }
}
