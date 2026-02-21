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
            You're a skilled translator with extensive experience in translating \(source) text to \(target) while maintaining the original formatting, especially for markdown. Your expertise allows you to ensure that nuances in meaning and cultural context are carefully preserved in the translation, making it accessible and appropriate for \(target) speakers.

            Your task is to translate a piece of UI of an iOS app written in \(source) to \(target) language. The text was taken from Xcode string catalog.
            If there is markdown formatting, ensure that the markdown formatting remains intact.
            Keep the placeholder values such as ["@", "lld", ".2f", "1$@", "2$@", "3$@", "1$lld", "2$lld"] used in the string catalogs at the meaningfully correct place in the translation.

            Please keep in mind any specific context or tone that should be maintained during the translation, particularly regarding cultural references or idiomatic expressions. The author may add additional context on where the text is used in the UI. Use that information to choose the most suitable translation if there are multiple options.

            For further clarity, here's how I would like the output formatted:
            - For headings, translate the text while maintaining the heading level (e.g., # for H1, ## for H2).
            - For lists, keep the bullet points or numbering intact while translating the content.
            - For emphasized text (bold or italics), use the appropriate markdown syntax in \(target).
            - Keep the line breaks intact.

            Only output the translation without backticks.
            """
        },
        makeUserPrompt: { request in
            let additionalContext = request.developerComment.map { " Additional context from the author: \($0)." } ?? ""
            return """
            The text I need you to translate is below delimited by triple backticks.\(additionalContext)
            ```
            \(request.text)
            ```
            """
        }
    )
}

public struct LLMTranslator: CatalogTextTranslator, Sendable {
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

@available(*, deprecated, renamed: "LLMTranslator")
public typealias LLMExampleTranslator = LLMTranslator
