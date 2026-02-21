import CatalogTranslation
import Foundation
import StringCatalog

public struct PromptTemplate: Sendable {
    public var makeSystemPrompt: @Sendable (TranslationRequest) -> String
    public var makeUserPrompt: @Sendable (TranslationRequest) -> String

    public init(
        makeSystemPrompt: @escaping @Sendable (TranslationRequest) -> String,
        makeUserPrompt: @escaping @Sendable (TranslationRequest) -> String
    ) {
        self.makeSystemPrompt = makeSystemPrompt
        self.makeUserPrompt = makeUserPrompt
    }

    public static let appLocalizationDefault = Self(
        makeSystemPrompt: { request in
            let source = request.sourceLanguage.englishDisplayName
            let target = request.targetLanguage.englishDisplayName
            return """
            You are an expert app localization translator.
            Translate from \(source) to \(target).
            Preserve placeholders and markdown formatting.
            Return only the translated text.
            """
        },
        makeUserPrompt: { request in
            let context = request.developerComment.map { "Context: \($0)\n" } ?? ""
            return """
            \(context)String key: \(request.stringKey)
            Segment: \(segmentDescription(request.segment))

            Text:
            \(request.text)
            """
        }
    )
}

public struct LLMExampleTranslator: CatalogTextTranslator, Sendable {
    private let template: PromptTemplate
    private let complete: @Sendable (_ request: TranslationRequest, _ systemPrompt: String, _ userPrompt: String) async throws -> String

    public init(
        template: PromptTemplate = .appLocalizationDefault,
        complete: @escaping @Sendable (_ request: TranslationRequest, _ systemPrompt: String, _ userPrompt: String) async throws -> String
    ) {
        self.template = template
        self.complete = complete
    }

    public func translate(_ request: TranslationRequest) async throws -> String {
        let systemPrompt = template.makeSystemPrompt(request)
        let userPrompt = template.makeUserPrompt(request)
        return try await complete(request, systemPrompt, userPrompt)
    }
}

private func segmentDescription(_ segment: TranslationSegment) -> String {
    switch segment {
    case .stringUnit:
        return "stringUnit"
    case .stringSet(let index):
        return "stringSet[\(index)]"
    case .variation(let path):
        return path
    }
}
