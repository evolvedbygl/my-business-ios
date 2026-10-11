//  AIAssistantLiveDeletionTests.swift
//  GLSmallBusinessTests
//
//  The TestFlight crash on build 81 (APTgSqmpO9qyluK_7eZ9Hww): the AI made an estimate and
//  a new client, the tester deleted that client, the cascade deleted the estimate, and the
//  STILL-OPEN chat re-rendered its estimate card over the dead model — Estimate.discountType
//  trapped uncatchably. The gesture only exists on a LIVE screen: a fresh render after the
//  delete never reaches the re-render path, which is why these use `renderAcross` (see
//  DetailScreenSurvivesRebuildTests for the same shape on the detail screens).
//
//  On the new screen the class of bug is designed out: a conversation holds `GLAIRecordRef`
//  (kind + id), never a `@Model`, and the router re-fetches by id at draw time. These tests are
//  the proof — the same gesture, against `AssistantScreen`, plus the router's own answer once the
//  record is gone.
//
//  `.serialized` is load-bearing: hosted @Query views and RunLoop pumping must not
//  interleave across tests (project_swiftdata_test_process_trap).

import Testing
import Foundation
import SwiftUI
import SwiftData
import GoldLifeAI
@testable import GLSmallBusiness

@MainActor
@Suite(.serialized)
struct AIAssistantLiveDeletionTests {

    private func onScreen(_ kind: String, _ record: some PersistentModel & GLSyncIdentified,
                          _ label: String, in context: ModelContext) -> GLAIOnScreen {
        let id = (try? DomainSyncIdentity.ensure(record, in: context, subscription: nil))?.uuidString
        return GLAIOnScreen(kind: kind, id: id ?? UUID().uuidString, label: label)
    }

    /// The tester's exact gesture: the assistant open on an estimate, its client deleted underneath.
    @Test func chatSurvivesClientDeletedUnderLiveEstimateCard() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let customer = TS.customer(in: context)
        let estimate = TS.estimate(number: "EST-AI-0001", in: context)
        estimate.customer = customer
        try context.save()
        #expect(estimate.total > 0)

        let screen = AssistantScreen(onScreen: onScreen("estimate", estimate, "EST-AI-0001", in: context),
                                     isSheet: true)
        GLTestHost.renderAcross(screen, container: container) {
            // An edit saved while the chat is off screen (a follow-up turn, a sync pull) re-faults
            // the estimate — then the client goes, cascade and all.
            estimate.jobTitle = "Master bath — revised"
            try? context.save()
            context.delete(customer)
            try? context.save()
        }

        // The cascade really committed: a saved delete leaves the row without a context.
        #expect(estimate.modelContext == nil)
    }

    /// The same gesture with an invoice on screen.
    @Test func chatSurvivesClientDeletedUnderLiveInvoiceCard() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let customer = TS.customer(in: context)
        let invoice = TS.invoice(number: "INV-AI-0001", in: context)
        invoice.customer = customer
        try context.save()
        #expect(invoice.total > 0)

        let screen = AssistantScreen(onScreen: onScreen("invoice", invoice, "INV-AI-0001", in: context),
                                     isSheet: true)
        GLTestHost.renderAcross(screen, container: container) {
            invoice.jobTitle = "Master bath — revised"
            try? context.save()
            context.delete(customer)
            try? context.save()
        }

        #expect(invoice.modelContext == nil)
    }

    /// The estimate deleted directly (Estimates list, sync) rather than by cascade.
    @Test func chatSurvivesEstimateDeletedDirectlyUnderLiveCard() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let estimate = TS.estimate(number: "EST-AI-0002", in: context)
        try context.save()

        let screen = AssistantScreen(onScreen: onScreen("estimate", estimate, "EST-AI-0002", in: context),
                                     isSheet: true)
        GLTestHost.renderAcross(screen, container: container) {
            estimate.jobTitle = "Master bath — revised"
            try? context.save()
            context.delete(estimate)
            try? context.save()
        }

        #expect(estimate.modelContext == nil)
    }

    /// The card's row still points at the deleted record: the router refuses it and the destination
    /// view draws the app's own "this is gone" screen instead of trapping.
    @Test func anActivityRowForADeletedRecordNeitherPushesNorTraps() throws {
        let container = try TestStore.makeContainer()
        let context = container.mainContext
        let estimate = TS.estimate(number: "EST-AI-0003", in: context)
        try context.save()
        let id = try #require(try DomainSyncIdentity.ensure(estimate, in: context, subscription: nil)).uuidString

        #expect(MBAssistantDestination(record: GLAIRecordRef(kind: "estimate", id: id),
                                       in: context) == .record(kind: "estimate", id: id))
        context.delete(estimate)
        try context.save()
        #expect(MBAssistantDestination(record: GLAIRecordRef(kind: "estimate", id: id), in: context) == nil)

        // Even if a stale destination is drawn, it resolves to the "removed" screen, not a trap.
        GLTestHost.render(MBAssistantDestinationView(destination: .record(kind: "estimate", id: id)),
                          container: container)
    }
}
