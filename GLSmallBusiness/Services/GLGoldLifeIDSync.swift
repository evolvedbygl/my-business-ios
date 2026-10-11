//  GLGoldLifeIDSync.swift — My Business's one door to the person's Gold Life ID, and the
//  one-release move of the old UserProfile copy into it.
//
//   / 48a (F70): the person's name, contact, address, photo
//  and signature live ONLY in the shared Gold Life ID (GoldLifeID package). Screens read
//  them through `MBIdentity.shared`, and the signature is saved through the package's
//  engine (`updateIdentity`), never onto a local row.
//
//  `UserProfile` still has its old identity columns in 3.3.0 (dropping them needs a store
//  This file is the only code that touches them (besides HomeAddressBackfill, which copies
//  the dormant address composite into the flat columns): at each store mount, `runLegacyUpload`
//  offers what a pre-3.3.0 phone still holds to the Gold Life ID (which fills only the
//  fields it doesn't have), then clears every column the Gold Life ID now holds, so a
//  field the person later deletes or changes in the Gold Life ID is never brought back.
//  A signature is shrunk to what the Gold Life ID server takes (`signatureForUpload`) before
//  it is saved or offered. Pinned by GLSmallBusinessTests/IdentitySourceTests and
//  SignatureUploadSizeTests.

import Foundation
import GoldLifeID
import ImageIO
import SwiftData
import UIKit

enum GLGoldLifeIDSync {

    /// What this phone still holds from before 3.3.0, in the shared record's shape. `nil` fields
    /// (no row) pass straight through; `migrateLegacyProfileIfNeeded` only fills the shared fields
    /// that are still empty. `includeAddress` is false once the address has moved: the
    /// write-forbidden legacy composite refills the flat columns at every mount
    /// (`HomeAddressBackfill`), and an address the person later cleared must not come back.
    static func legacyProfile(from profile: UserProfile?, includeAddress: Bool = true) -> GoldLifeLegacyProfile {
        GoldLifeLegacyProfile(
            firstName: profile?.firstName,
            lastName: profile?.lastName,
            phone: profile?.phone,
            address: includeAddress ? profile.map {
                GoldLifeAddress(number: "", street: $0.addressStreet1,
                                city: $0.addressCity, state: $0.addressState, zip: $0.addressPostalCode)
            } : nil,
            avatarData: profile?.photoData,
            // Shrunk to what the Gold Life ID takes: a 3.2 photo-import signature can be several
            // MB, and the server refuses it whole.
            signatureData: profile?.signatureData.flatMap(signatureForUpload)
        )
    }

    /// The most a signature may weigh on its way to the Gold Life ID. The server refuses a
    /// `signature_png` over 1,400,000 base64 characters (about 1.05 MB); this leaves room.
    nonisolated static let signatureByteLimit = 1_000_000

    /// A signature that fits the Gold Life ID: a PNG (transparency kept) at most
    /// `ImageDownsampler.intakeMaxEdge` px on its long edge and at most
    /// `signatureByteLimit` bytes. Data that already fits is returned unchanged; ImageIO
    /// thumbnailing shrinks the rest without decoding the full image. nil only when it
    /// can't be made to fit (not a picture, and too big to send as it is).
    nonisolated static func signatureForUpload(_ data: Data) -> Data? {
        let limit = signatureByteLimit
        let maxEdge = Double(ImageDownsampler.intakeMaxEdge)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else {
            // Not a picture: it goes as it is if it fits, as before.
            return data.count <= limit ? data : nil
        }
        let longEdge = max(width, height)
        if data.count <= limit, longEdge <= maxEdge { return data }
        // PNG size follows the pixel count, so each try shrinks the edge by the square root of how
        // far over it is, a little more for margin; never past half or less than a tenth.
        var edge = min(longEdge, maxEdge).rounded(.down)
        for _ in 0..<8 {
            guard let image = ImageDownsampler.thumbnail(from: data, maxPixelSize: CGFloat(edge)),
                  let png = image.pngData() else { return nil }
            if png.count <= limit { return png }
            let step = min(0.9, max(0.5, (Double(limit) / Double(png.count)).squareRoot() * 0.95))
            edge = (edge * step).rounded(.down)
            guard edge >= 64 else { return nil }
        }
        return nil
    }

    /// Clears each legacy column the Gold Life ID now holds. The copy is redundant then, so nothing
    /// is lost if the upload failed; a field the Gold Life ID doesn't hold yet keeps its copy for
    /// the next mount. The dormant `address` composite is write-forbidden (its doc in
    /// MBUserProfile.swift) and is never touched; only the flats are cleared. Returns whether
    /// anything changed.
    @discardableResult
    static func retireLegacyColumns(_ profile: UserProfile, after identity: GoldLifeIdentity,
                                    addressRetired: Bool = false) -> Bool {
        var changed = false
        func clear(_ value: inout String, when held: Bool) {
            guard held, !value.isEmpty else { return }
            value = ""
            changed = true
        }
        clear(&profile.firstName, when: !identity.firstName.isEmpty)
        clear(&profile.lastName, when: !identity.lastName.isEmpty)
        clear(&profile.email, when: !identity.email.isEmpty)
        clear(&profile.phone, when: !identity.phone.isEmpty)
        if (addressRetired || !identity.address.isEmpty), !profile.homeAddress.isEmpty {
            profile.homeAddress = Address()
            changed = true
        }
        if identity.avatarData != nil, profile.photoData != nil {
            profile.photoData = nil
            changed = true
        }
        if identity.signatureData != nil, profile.signatureData != nil {
            profile.signatureData = nil
            changed = true
        }
        return changed
    }

    /// After a signature save or delete lands in the Gold Life ID, the old local copy is stale
    /// either way: cleared so the next mount can't offer it back.
    static func retireLegacySignature(in context: ModelContext) {
        let rows = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        var changed = false
        for row in rows where row.signatureData != nil {
            row.signatureData = nil
            changed = true
        }
        if changed { context.saveChanges() }
    }

    /// The marker beside the store that says the address has moved (it dies with the store on a
    /// wipe, so it is per account; never a device-global flag).
    static func addressRetiredMarker(for storeURL: URL?) -> URL? {
        storeURL.map {
            $0.deletingLastPathComponent()
                .appendingPathComponent($0.lastPathComponent + ".legacy-address-moved")
        }
    }

    /// The mount step GatePhase runs: offer the old copy to the Gold Life ID, then, signed in only,
    /// clear what the Gold Life ID now holds from EVERY row (ProfileDedup can leave two filled
    /// copies). Signed out, the upload is a no-op and nothing is cleared.
    static func runLegacyUpload(in context: ModelContext, storeURL: URL?) async {
        await runLegacyUpload(
            in: context, storeURL: storeURL,
            isSignedIn: GoldLifeID.shared.sessionState == .signedIn,
            identity: { GoldLifeID.shared.identity },
            upload: { await GoldLifeID.shared.migrateLegacyProfileIfNeeded($0) })
    }

    /// The testable body of the mount step: the session, the identity and the upload come in.
    static func runLegacyUpload(in context: ModelContext, storeURL: URL?,
                                isSignedIn: Bool, identity: () -> GoldLifeIdentity,
                                upload: (GoldLifeLegacyProfile) async -> Void) async {
        let rows = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard !rows.isEmpty else { return }
        let marker = addressRetiredMarker(for: storeURL)
        let addressMoved = marker.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        // The row with something left to offer; dedup keeps every filled copy, and each one is
        // offered on a later mount if this one's fields are already held. Built once per row:
        // building it shrinks an oversized signature.
        let offer = rows.lazy
            .map { legacyProfile(from: $0, includeAddress: !addressMoved) }
            .first { $0.hasContent }
        if let offer {
            await upload(offer)
        }
        guard isSignedIn else { return }
        let held = identity()
        var changed = false
        for row in rows where retireLegacyColumns(row, after: held, addressRetired: addressMoved) {
            changed = true
        }
        if !addressMoved, !held.address.isEmpty, let marker {
            FileManager.default.createFile(atPath: marker.path, contents: Data())
        }
        if changed { context.saveChanges() }
    }
}

private extension GoldLifeLegacyProfile {
    var hasContent: Bool {
        !(firstName ?? "").isEmpty || !(lastName ?? "").isEmpty || !(phone ?? "").isEmpty
            || !(address?.isEmpty ?? true) || avatarData != nil || signatureData != nil
    }
}

/// Why a signature couldn't be saved before it ever reached the Gold Life ID.
enum MBSignatureError: Error, Equatable {
    /// It can't be shrunk to what the Gold Life ID takes.
    case tooLarge
}

/// The signed-in person's Gold Life ID, as My Business reads and writes it. Sample data shows the
/// fleet's sample person (`GoldLifeIdentity.demo`) and keeps a signature in memory only: nothing
/// done in sample data reaches the real Gold Life ID.
@MainActor
@Observable
final class MBIdentity {
    static let shared = MBIdentity()

    /// The signature drawn while exploring sample data. Never sent anywhere.
    private var sampleSignature: Data?

    #if DEBUG
    /// DEBUG only (tests, simulator proof): a stand-in identity, launched with
    /// `-mbStubIdentityFirstName <name>`. Saves land on it, never on the server.
    var standIn: GoldLifeIdentity?
    #endif

    private init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let flag = args.firstIndex(of: "-mbStubIdentityFirstName"), args.indices.contains(flag + 1) {
            var stub = GoldLifeIdentity.demo
            stub.firstName = args[flag + 1]
            standIn = stub
        }
        #endif
    }

    /// Sample data is showing (the demo launch flag or the person's "Explore sample data").
    var isSampleData: Bool { DemoMode.isActive || UserDemoMode.shared.isDemoActive }

    /// Who the person is right now.
    var current: GoldLifeIdentity {
        #if DEBUG
        if let standIn { return standIn }
        #endif
        if isSampleData {
            var sample = GoldLifeIdentity.demo
            sample.signatureData = sampleSignature
            return sample
        }
        return GoldLifeID.shared.identity
    }

    /// The saved signature (a transparent PNG), or nil.
    var signatureData: Data? { current.signatureData }

    /// Saves (`data`) or deletes (`nil`) the signature in the Gold Life ID, then clears the old
    /// local copy in `context` so it can never be offered back. The signature is first shrunk to
    /// what the Gold Life ID takes (`signatureForUpload`); `MBSignatureError.tooLarge` when it
    /// can't be. Throws when the Gold Life ID refuses or can't be reached; nothing is changed then.
    func saveSignature(_ data: Data?, legacyIn context: ModelContext?) async throws {
        var fitted: Data?
        if let data {
            fitted = await Task.detached(priority: .userInitiated) {
                GLGoldLifeIDSync.signatureForUpload(data)
            }.value
            guard fitted != nil else { throw MBSignatureError.tooLarge }
        }
        #if DEBUG
        if standIn != nil {
            standIn?.signatureData = fitted
            if let context { GLGoldLifeIDSync.retireLegacySignature(in: context) }
            return
        }
        #endif
        if isSampleData {
            sampleSignature = fitted
            return
        }
        var edit = GoldLifeIdentityEdit()
        edit.signature = fitted.map { .set($0) } ?? .cleared
        _ = try await GoldLifeID.shared.updateIdentity(edit)
        if let context { GLGoldLifeIDSync.retireLegacySignature(in: context) }
    }
}
