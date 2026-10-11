//  AssistantInfoWordingTests.swift GLSmallBusinessTests
//
//  They used to say "Google's Gemini API", which named neither the payment nor Gold Life's server
//  the disclosure now names.

import Testing
import Foundation
@testable import GLSmallBusiness

@Suite(.serialized)
@MainActor
struct AssistantInfoWordingTests {

    private static let english = "The assistant sends what you type and the records it needs to Google\u{2019}s Gemini, a paid service, through Gold Life\u{2019}s server, to answer. Stop sharing and it asks again the next time you use it."
    private static let spanish = "El asistente env\u{ED}a lo que escribes y los registros que necesita a Gemini de Google, un servicio de pago, a trav\u{E9}s del servidor de Gold Life, para responder. Si dejas de compartir, te preguntar\u{E1} de nuevo la pr\u{F3}xima vez que lo uses."

    private func assistantTopic() throws -> MBHelpCatalog.Topic {
        try #require(MBHelpCatalog.topics.first { MBHelpTool.english($0.topic) == "Assistant" })
    }

    /// The help answer reads the approved sentence in English and in Spanish, and names the same
    /// provider, word for word, as the consent sheet does in that language.
    @Test func theAssistantHelpTopicUsesTheApprovedWordsInBothLanguages() throws {
        let saved = MBLocalization.shared.language
        defer { MBLocalization.shared.language = saved }
        let topic = try assistantTopic()
        #expect(MBHelpTool.english(topic.text) == Self.english)

        MBLocalization.shared.language = .en
        #expect(mbLoc(topic.text) == Self.english)
        #expect(mbLoc(topic.text).contains(MBAssistantStrings.providerName))

        MBLocalization.shared.language = .es
        #expect(mbLoc(topic.text) == Self.spanish)
        #expect(mbLoc(topic.text).contains(MBAssistantStrings.providerName))
    }

    /// Settings shows the same catalog key the help answer reads, so the two can't drift; the old
    /// "Gemini API" wording is gone from the screens, the help and the catalog.
    @Test func settingsShowsTheSameWordsAndTheOldOnesAreGone() throws {
        let settings = try #require(GLSource.file("Screens/SettingsScreen.swift"))
        #expect(settings.contains("InfoLabel(\"Assistant\", info: \"\(Self.english)\", topic: \"Assistant\")"))
        for file in GLSource.files() {
            #expect(!file.text.contains("Gemini API"), "\(file.path) still says \"Gemini API\"")
        }
        let url = GLSource.appRoot.appendingPathComponent("Localizable.xcstrings")
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        let entry = try #require(strings[Self.english] as? [String: Any])
        let es = ((entry["localizations"] as? [String: Any])?["es"] as? [String: Any])?["stringUnit"] as? [String: Any]
        #expect(es?["value"] as? String == Self.spanish)
        #expect(es?["state"] as? String == "translated")
        #expect(!strings.keys.contains { $0.contains("Gemini API") }, "the old wording is still in the catalog")
    }
}
