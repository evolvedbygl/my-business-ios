//  UserProfileTests.swift GLSmallBusinessTests
//
//  The UserProfile row now holds one app setting (Name in emails); the person's name, contact,
//  photo and signature live in the Gold Life ID. What's left on the row: the home-address façade
//  the legacy upload reads, and the setting's default.

import Testing
import Foundation
@testable import GLSmallBusiness

@MainActor
struct UserProfileTests {

    @Test func emailsUseTheOwnersNameByDefault() {
        #expect(!UserProfile().useMyNameInEmails)
    }

    @Test func homeAddressWritesTheFlatColumnsOnly() {
        let p = UserProfile()
        p.homeAddress = Address(street1: "1 Main St", street2: "Unit 2", city: "Tallahassee",
                                state: "FL", postalCode: "32301")
        #expect(p.addressStreet1 == "1 Main St" && p.addressStreet2 == "Unit 2")
        #expect(p.addressCity == "Tallahassee" && p.addressState == "FL" && p.addressPostalCode == "32301")
        #expect(p.address == nil, "the dormant composite is write-forbidden")
        p.homeAddress = Address()
        #expect(p.homeAddress.isEmpty)
    }
}
