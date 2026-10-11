//  MBUserProfile.swift — legacy SwiftData schema entity for store compatibility. GLSmallBusiness
//
//  Created by Gold Life LLC on 6/15/26.
//
//  The person's identity lives ONLY in the Gold Life ID. This row now holds one app setting,
//  `useMyNameInEmails`. Nothing shows or syncs them: GLGoldLifeIDSync offers them to the Gold Life
//  ID once and clears each one as soon as the Gold Life ID holds it. The one other writer is
//  HomeAddressBackfill (SyncIdentity.swift), which copies the dormant address composite into the
//  flat address columns at mount. Pinned by IdentitySourceTests.

import Foundation
import SwiftData

@SwiftData.Model
final class UserProfile {

    // MARK: Sync identity (platform Phase 0 — additive into GLSchemaV1)
    /// Stable identity for the coming server sync. Optional, NOT `= UUID()`: a SwiftData
    /// attribute default is captured once in schema metadata, so migration would give
    /// every existing record the SAME uuid. SyncIdentityBackfill mints these uniquely.
    /// `.preserveValueOnDeletion` keeps the uuid in the DELETE tombstone. Without it the
    /// tombstone is empty, the syncID dies with the row, and the server can never be told
    /// the record went away — i.e. deletes do not sync at all.
    @Attribute(.preserveValueOnDeletion) var syncID: UUID?
    /// Last local edit, stamped by `saveChanges`. Autosaved edits are not stamped yet — the GLSync
    /// client owns real change capture when it lands (migration Phase 3).
    var updatedAt: Date?

    // MARK: - Legacy identity columns: read and written only by GLGoldLifeIDSync (and
    // HomeAddressBackfill for the address flats) The person's name, contact, address, photo and
    // signature live in the Gold Life ID.
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    /// The owner's HOME address — distinct from the business address on BusinessProfile. Additive
    /// into GLSchemaV1; needs the manual CloudKit Production schema deploy before a build carrying
    /// it ships. Optional, NOT `= Address()`: a composite (struct) attribute added to an existing
    /// entity must be nullable — the Swift-side default is never applied during store migration, so
    /// old stores fail to open ("missing attribute values on mandatory destination attribute:
    /// street1", builds 39/40 crash).
    ///
    /// ⚠️ DORMANT-LEGACY, WRITE-FORBIDDEN (2026-08-29, the build-48 launch trap). A history UPDATE
    /// row cannot be materialized when its keypath crosses ANY Optional: this property being
    /// `Address?` fatals on "address.city", and — corrected 2026-09-01, the build-62 crash — an
    /// optional MEMBER inside the struct fatals identically ("address.street2"), which is why every
    /// Address composite in the schema is now dormant behind flats (the pattern this property
    /// pioneered). Writing this — even `nil` — poisons persistent history. Reads fall back to it
    /// once through `homeAddress`; every write goes to the flat columns below. Nothing may ever
    /// assign it again.
    var address: Address?

    /// The flattened home address (the write path since 2026-08-29 — see the warning above).
    /// Primitive columns, so their history rows always resolve.
    var addressStreet1: String = ""
    var addressStreet2: String = ""
    var addressCity: String = ""
    var addressState: String = ""
    var addressPostalCode: String = ""

    /// When true, customer emails are signed with THIS person's Gold Life ID name instead of the
    /// business owner's (Settings ▸ What customers see ▸ Name in emails). Per-person and synced
    /// (the one field user_profile still carries). Falls back to the owner's name when this
    /// person's own name is blank, so the signature never loses its name line. Default false =
    /// owner's name, the original behavior.
    var useMyNameInEmails: Bool = false

    /// Legacy: the person's photo before 3.3.0. The photo lives in the Gold Life ID.
    @Attribute(.externalStorage) var photoData: Data?

    /// Legacy: the signature before 3.3.0. The signature lives in the Gold Life ID
    /// (`MBIdentity.shared.signatureData`).
    @Attribute(.externalStorage) var signatureData: Data?

    init() {}
}

extension UserProfile {
    /// THE one door to the home address. Reads see the flat columns only — legacy rows are
    /// forward-copied once by `HomeAddressBackfill` at store mount, deliberately NOT read here as a
    /// fallback: a fallback cannot tell "flats never written" from "flats cleared by a synced
    /// delete", so a cleared address would resurrect. The setter writes FLATS ONLY — the composite
    /// is write-forbidden forever (its doc explains the uncatchable history trap). Note: since
    /// 2026-09-01 `Address.street2` is non-optional everywhere — empty string IS the no-value
    /// state, here and in the struct.
    var homeAddress: Address {
        get {
            Address(street1: addressStreet1,
                    street2: addressStreet2.isEmpty ? nil : addressStreet2,
                    city: addressCity,
                    state: addressState,
                    postalCode: addressPostalCode)
        }
        set {
            addressStreet1 = newValue.street1
            addressStreet2 = newValue.street2 ?? ""
            addressCity = newValue.city
            addressState = newValue.state
            addressPostalCode = newValue.postalCode
        }
    }

    /// Legacy: whether the pre-3.3.0 signature column holds bytes. Read only by the Assistant's W-9
    /// signing (AI/MBHandoffBuilder.swift), which is off in 3.3.0 and quarantined in
    /// IdentitySourceTests until it reads `MBIdentity.shared.signatureData`.
    var hasSignature: Bool { signatureData != nil }

    /// Settings ▸ Name in emails. Finds or creates the one row and saves it: a new account has no
    /// row until something writes one, and a write into nothing would look saved and be gone. A
    /// second copy minted by the sync bootstrap is merged by ProfileDedup and, server-side, by the
    /// singleton head.
    static func setUseMyNameInEmails(_ value: Bool, in context: ModelContext) {
        let row = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first ?? {
            let new = UserProfile()
            context.insert(new)
            return new
        }()
        row.useMyNameInEmails = value
        context.saveChanges()
    }
}
