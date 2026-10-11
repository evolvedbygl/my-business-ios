//  GLGoldLifeIDSyncTests.swift — the one-release legacy upload into the shared Gold Life ID and
//  what happens to the old UserProfile columns after it. No network, no Stytch session: the upload
//  and the identity are passed in, so the mount step runs here exactly as GatePhase runs it.

import Testing
import Foundation
import SwiftData
import GoldLifeID
@testable import GLSmallBusiness

@Suite("GLGoldLifeIDSync", .serialized)
@MainActor
struct GLGoldLifeIDSyncTests {

    /// A row holding every legacy identity column.
    private static func filledRow(in context: ModelContext) -> UserProfile {
        let profile = UserProfile()
        profile.firstName = "Jordan"
        profile.lastName = "Avery"
        profile.email = "old@example.com"
        profile.phone = "1-850-555-0133"
        profile.addressStreet1 = "100 Example Ave"
        profile.addressCity = "Tallahassee"
        profile.addressState = "FL"
        profile.addressPostalCode = "32308"
        profile.photoData = Data([0x01, 0x02])
        profile.signatureData = Data([0x03, 0x04])
        context.insert(profile)
        return profile
    }

    /// What `GoldLifeID.migrateLegacyProfileIfNeeded` does to the shared record: fills only the
    /// fields it doesn't have yet.
    private static func fillEmpty(_ identity: inout GoldLifeIdentity, from legacy: GoldLifeLegacyProfile) {
        if identity.firstName.isEmpty, let v = legacy.firstName, !v.isEmpty { identity.firstName = v }
        if identity.lastName.isEmpty, let v = legacy.lastName, !v.isEmpty { identity.lastName = v }
        if identity.phone.isEmpty, let v = legacy.phone, !v.isEmpty { identity.phone = v }
        if identity.address.isEmpty, let v = legacy.address, !v.isEmpty { identity.address = v }
        if identity.avatarData == nil, let v = legacy.avatarData { identity.avatarData = v }
        if identity.signatureData == nil, let v = legacy.signatureData { identity.signatureData = v }
    }

    /// The shared record, held by reference so the upload and the identity read see one value.
    private final class Shared {
        var identity = GoldLifeIdentity.empty
        var offered: GoldLifeLegacyProfile?
        func upload(_ legacy: GoldLifeLegacyProfile) {
            offered = legacy
            GLGoldLifeIDSyncTests.fillEmpty(&identity, from: legacy)
        }
    }

    private static func scratchStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("glid-sync-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("default.store")
    }

    @Test("legacyProfile(from:) carries every field this app already knows, nil-safe when there is no row yet")
    func legacyProfileFromRow() throws {
        let container = try TestStore.makeContainer()
        let profile = Self.filledRow(in: container.mainContext)

        let legacy = GLGoldLifeIDSync.legacyProfile(from: profile)
        #expect(legacy.firstName == "Jordan")
        #expect(legacy.lastName == "Avery")
        #expect(legacy.phone == "1-850-555-0133")
        #expect(legacy.address?.street == "100 Example Ave")
        #expect(legacy.address?.city == "Tallahassee")
        #expect(legacy.address?.state == "FL")
        #expect(legacy.address?.zip == "32308")
        #expect(legacy.avatarData == Data([0x01, 0x02]))
        #expect(legacy.signatureData == Data([0x03, 0x04]))

        let empty = GLGoldLifeIDSync.legacyProfile(from: nil)
        #expect(empty.firstName == nil)
        #expect(empty.address == nil)
        #expect(empty.avatarData == nil)
    }

    @Test("Once the address has moved, the old copy is never offered again")
    func retiredAddressIsNotOffered() throws {
        let container = try TestStore.makeContainer()
        let profile = Self.filledRow(in: container.mainContext)
        #expect(GLGoldLifeIDSync.legacyProfile(from: profile, includeAddress: false).address == nil)
        #expect(GLGoldLifeIDSync.legacyProfile(from: profile, includeAddress: true).address?.city == "Tallahassee")
    }

    @Test("Each column the Gold Life ID holds is cleared from the phone")
    func heldColumnsAreRetired() throws {
        let container = try TestStore.makeContainer()
        let profile = Self.filledRow(in: container.mainContext)
        var identity = GoldLifeIdentity.demo
        identity.avatarData = Data([0xAA])
        identity.signatureData = Data([0xBB])

        #expect(GLGoldLifeIDSync.retireLegacyColumns(profile, after: identity))
        #expect(profile.firstName.isEmpty && profile.lastName.isEmpty)
        #expect(profile.email.isEmpty && profile.phone.isEmpty)
        #expect(profile.homeAddress.isEmpty)
        #expect(profile.photoData == nil && profile.signatureData == nil)
        #expect(!GLGoldLifeIDSync.retireLegacyColumns(profile, after: identity), "a second pass has nothing to clear")
    }

    @Test("A column the Gold Life ID doesn't hold yet keeps its copy for the next try")
    func unheldColumnsAreKept() throws {
        let container = try TestStore.makeContainer()
        let profile = Self.filledRow(in: container.mainContext)

        #expect(!GLGoldLifeIDSync.retireLegacyColumns(profile, after: .empty))
        #expect(profile.firstName == "Jordan")
        #expect(profile.signatureData == Data([0x03, 0x04]))
        #expect(profile.addressCity == "Tallahassee")
    }

    @Test("A signature deleted in the Gold Life ID stays deleted on the next launch")
    func deletedSignatureIsNotUploadedBack() async throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        _ = Self.filledRow(in: context)
        let shared = Shared()

        // Launch 1: the old signature moves into the Gold Life ID.
        await GLGoldLifeIDSync.runLegacyUpload(
            in: context, storeURL: nil, isSignedIn: true, identity: { shared.identity },
            upload: { shared.upload($0) })
        #expect(shared.identity.signatureData == Data([0x03, 0x04]))

        // The person deletes it (in this app or any other).
        shared.identity.signatureData = nil
        shared.offered = nil

        // Launch 2: nothing brings it back.
        await GLGoldLifeIDSync.runLegacyUpload(
            in: context, storeURL: nil, isSignedIn: true, identity: { shared.identity },
            upload: { shared.upload($0) })
        #expect(shared.offered?.signatureData == nil, "the deleted signature was offered to the Gold Life ID again")
        #expect(shared.identity.signatureData == nil)
    }

    @Test("Every copy of the row is cleaned, not just the first")
    func everyRowIsRetired() async throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let one = Self.filledRow(in: context)
        let two = Self.filledRow(in: context)
        let shared = Shared()

        await GLGoldLifeIDSync.runLegacyUpload(
            in: context, storeURL: nil, isSignedIn: true, identity: { shared.identity },
            upload: { shared.upload($0) })

        for row in [one, two] {
            #expect(row.signatureData == nil && row.photoData == nil)
            #expect(row.firstName.isEmpty && row.phone.isEmpty && row.homeAddress.isEmpty)
        }
    }

    @Test("Signed out, nothing is cleared (the upload couldn't have landed)")
    func signedOutKeepsEverything() async throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let row = Self.filledRow(in: context)

        await GLGoldLifeIDSync.runLegacyUpload(
            in: context, storeURL: nil, isSignedIn: false, identity: { .demo }, upload: { _ in })
        #expect(row.firstName == "Jordan" && row.signatureData != nil)
    }

    @Test("An address cleared in the Gold Life ID isn't brought back from the old composite")
    func clearedAddressStaysCleared() async throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let row = Self.filledRow(in: context)
        let storeURL = Self.scratchStoreURL()
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
        let shared = Shared()

        await GLGoldLifeIDSync.runLegacyUpload(
            in: context, storeURL: storeURL, isSignedIn: true, identity: { shared.identity },
            upload: { shared.upload($0) })
        #expect(shared.identity.address.city == "Tallahassee")
        #expect(row.homeAddress.isEmpty)

        // The person clears the address; HomeAddressBackfill refills the flats from the
        // write-forbidden legacy composite on the next mount.
        shared.identity.address = GoldLifeAddress()
        row.homeAddress = Address(street1: "100 Example Ave", city: "Tallahassee", state: "FL", postalCode: "32308")
        shared.offered = nil

        await GLGoldLifeIDSync.runLegacyUpload(
            in: context, storeURL: storeURL, isSignedIn: true, identity: { shared.identity },
            upload: { shared.upload($0) })
        #expect(shared.offered?.address == nil, "the cleared address was offered to the Gold Life ID again")
        #expect(shared.identity.address.isEmpty)
    }

    @Test("A signature saved from My Business lands in the Gold Life ID and retires the old copy")
    func savedSignatureGoesToTheGoldLifeID() async throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let row = Self.filledRow(in: context)
        let identity = MBIdentity.shared
        identity.standIn = .demo
        defer { identity.standIn = nil }

        try await identity.saveSignature(Data([0x09]), legacyIn: context)
        #expect(identity.signatureData == Data([0x09]))
        #expect(row.signatureData == nil, "the legacy copy would be uploaded again after a delete")

        try await identity.saveSignature(nil, legacyIn: context)
        #expect(identity.signatureData == nil)
    }

    @Test("Change the first name in the Gold Life ID and the next customer email signs with it")
    func emailSignatureShowsTheNewName() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let business = BusinessProfile()
        business.businessName = "Gold Life Tile"
        business.ownerFirstName = "Owner"
        business.ownerLastName = "Person"
        context.insert(business)
        UserProfile.setUseMyNameInEmails(true, in: context)
        let identity = MBIdentity.shared
        identity.standIn = .demo
        defer { identity.standIn = nil }

        identity.standIn?.firstName = "Taylor"
        #expect(EmailSignature.block(business: business, context: context).contains("Taylor Ellis"))
        identity.standIn?.firstName = "Morgan"
        let after = EmailSignature.block(business: business, context: context)
        #expect(after.contains("Morgan Ellis") && !after.contains("Taylor"))

        UserProfile.setUseMyNameInEmails(false, in: context)
        #expect(EmailSignature.block(business: business, context: context).contains("Owner Person"))
    }

    @Test("The email signature's name follows the Gold Life ID")
    func emailSenderNameFollowsTheGoldLifeID() {
        #expect(EmailSignature.senderName(owner: "Owner Name", useMyName: true, myName: "Taylor Ellis") == "Taylor Ellis")
        #expect(EmailSignature.senderName(owner: "Owner Name", useMyName: false, myName: "Taylor Ellis") == "Owner Name")
        #expect(EmailSignature.senderName(owner: "Owner Name", useMyName: true, myName: "  ") == "Owner Name",
                "a blank Gold Life ID name never blanks the name line")
    }
}

@Suite("Name in emails setting", .serialized)
@MainActor
struct EmailNameSettingTests {

    @Test("Choosing My name on a new account creates the one row and saves it")
    func createsTheRowOnFirstWrite() throws {
        let container = try TestStore.makeContainer()
        UserProfile.setUseMyNameInEmails(true, in: container.mainContext)
        let rows = try ModelContext(container).fetch(FetchDescriptor<UserProfile>())
        #expect(rows.count == 1)
        #expect(rows.first?.useMyNameInEmails == true)
    }

    @Test("An existing row is reused, never duplicated")
    func reusesTheExistingRow() throws {
        let container = try TestStore.makeContainer()
        container.mainContext.insert(UserProfile())
        container.mainContext.saveChanges()
        UserProfile.setUseMyNameInEmails(true, in: container.mainContext)
        UserProfile.setUseMyNameInEmails(false, in: container.mainContext)
        let rows = try ModelContext(container).fetch(FetchDescriptor<UserProfile>())
        #expect(rows.count == 1)
        #expect(rows.first?.useMyNameInEmails == false)
    }

    @Test("Settings writes through the find-or-create")
    func settingsUsesTheFindOrCreate() throws {
        let code = try #require(GLSource.code("Screens/SettingsScreen.swift"))
        #expect(code.contains("UserProfile.setUseMyNameInEmails("),
                "Settings ▸ Name in emails writes to a row a new account never has")
        #expect(!code.contains("userProfiles.first?.useMyNameInEmails = "))
    }
}
