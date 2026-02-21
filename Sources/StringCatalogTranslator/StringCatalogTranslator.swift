import OpenAI
import ConcurrencyExtras
import DeepLURLSessionClient
import DeepLURLSessionDependency
import Dependencies
import OpenAIDependency
import StringCatalog

public struct StringCatalogTranslator {
    public var translateWithDeepL: @Sendable (_ text: String, _ comment: String?, _ sourceLanguage: StringLanguage, _ targetLanguage: StringLanguage) async throws -> String
    public var translateWithChatGPT: @Sendable (_ text: String, _ comment: String?, _ sourceLanguage: StringLanguage, _ targetLanguage: StringLanguage) async throws -> String

    public func translateCatalog(_ catalog: StringCatalog, to targetLanguage: StringLanguage, translationService: TranslationService) async throws -> StringCatalog {
        var newCatalog = catalog
        let sourceLanguage = catalog.sourceLanguage

        await withTaskGroup(of: (String, String, String?).self) { group in

            for (stringKey, stringEntry) in catalog.strings {
                let textToTranslate: String
                
                if let localizations = stringEntry.localizations { // there is some localization
                    if let targetLocalization = localizations[targetLanguage] { // there is localization in the target language already. skip
                        continue
                    } else if let sourceLocalization = localizations[sourceLanguage] { // there is localization in the source language. use it
                        if let stringUnit = sourceLocalization.stringUnit { // stringUnit not stringSet
                            textToTranslate = stringUnit.value
                        } else { // stringSet
                            continue
                        }
                    } else { // there is localization in another language other than source or target
                        textToTranslate = stringKey
                    }
                } else {
                    textToTranslate = stringKey
                }
                
                guard !textToTranslate.isEmpty else {
                    continue
                }

                group.addTask {
                    switch translationService {
                    case .deepL:
                        let translation = try? await self.translateWithDeepL(textToTranslate, stringEntry.comment, sourceLanguage, targetLanguage)
                        return (stringKey, textToTranslate, translation)
                    case .chatgpt:
                        let translation = try? await self.translateWithChatGPT(textToTranslate, stringEntry.comment, sourceLanguage, targetLanguage)
                        return (stringKey, textToTranslate, translation)
                    }
                }
            }

            for await (stringKey, original, translation) in group {

                if let translation {
                    if newCatalog.strings[stringKey]?.localizations == nil {
                        newCatalog.strings[stringKey]?.localizations = [StringLanguage: StringLocalization]()
                    }

                    newCatalog.strings[stringKey]?.localizations?[targetLanguage] = StringLocalization(stringUnit: .init(state: .translated, value: translation))
                }

                //                #if DEBUG
                //                print("📜", original, "🎢", translation!)
                //                print("🥁 value", newCatalog.strings[original]!.localizations![targetLanguage]!)
                //                #endif
            }
        }

        return newCatalog
    }
}

extension StringCatalogTranslator: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.deepLURLSession) var deepLURLSession
        @Dependency(\.openAI) var openAi

        return Self(
            translateWithDeepL: { text, comment, sourceLanguage, targetLanguage in
                let response = try await deepLURLSession.client().translateText(
                    .init(
                        body: .json(
                            .init(
                                text: [text],
                                source_lang: sourceLanguage.deepLSourceLanguage,
                                target_lang: targetLanguage.deepLTargetLanguage,
                                context: comment
                            )
                        )
                    )
                )
                guard
                    let translation = try response.ok.body.json.translations?.compactMap({ translationsPayload in
                        translationsPayload.text
                    }).joined()
                else {
                    throw StringCatalogTranslator.Failure.translationsPayloadNil
                }
                return translation
            },
            translateWithChatGPT: { text, comment, sourceLanguage, targetLanguage in
                let additionalContext = if let comment {
                    " Additional context from the author: \(comment)."
                } else {
                    ""
                }
                
                let systemPrompt = """
                    You’re a skilled translator with extensive experience in translating \(sourceLanguage.englishDisplayName) text to \(targetLanguage.englishDisplayName) while maintaining the original formatting, especially for markdown. Your expertise allows you to ensure that nuances in meaning and cultural context are carefully preserved in the translation, making it accessible and appropriate for \(targetLanguage.englishDisplayName) speakers.

                    Your task is to translate a piece of UI of a macOS app written in \(sourceLanguage.englishDisplayName) to \(targetLanguage.englishDisplayName) language. The text was taken from Xcode string catalog.
                    If there is markdown formatting, ensure that the markdown formatting remains intact.
                    Keep the placeholder values such as ["@", "lld", ".2f", "1$@", "2$@", "3$@", "1$lld", "2$lld"] used in the string catalogs at the meaningfully correct place in the translation.

                    Please keep in mind any specific context or tone that should be maintained during the translation, particularly regarding cultural references or idiomatic expressions. The author may add additional context on where the text is used in the UI. Use that information to choose the most suitable translation if there are multiple options.

                    For further clarity, here’s how I would like the output formatted:
                    - For headings, translate the text while maintaining the heading level (e.g., # for H1, ## for H2).
                    - For lists, keep the bullet points or numbering intact while translating the content.
                    - For emphasized text (bold or italics), use the appropriate markdown syntax in \(targetLanguage.englishDisplayName).
                    - Keep the line breaks intact.
                    
                    Only output the translation without backticks.
                    """
                
                let userPrompt = """
                    The text I need you to translate is below delimited by triple backticks.\(additionalContext)
                    ```
                    \(text)
                    ```
                    """

                let model = text.count > 500 ? "gpt-4.1" : "gpt-4.1-mini"
                let client = openAi.client()
                let query = ChatQuery(messages: [
                    .system(.init(content: .textContent(systemPrompt))),
                    .user(.init(content: .string(userPrompt)))
                ], model: model)
                
                let response = try await client.chats(query: query)
                return response.choices.first?.message.content ?? "NO CHOICE"
            }
        )
    }()

    public static var previewValue: Self {
        Self(
            translateWithDeepL: { text, comment, sourceLanguage, targetLanguage in
                "This is a DeepL translation from \(sourceLanguage.englishDisplayName) to \(targetLanguage.englishDisplayName). Original text: [\(text)]"
            },
            translateWithChatGPT: { text, comment, sourceLanguage, targetLanguage in
                "This is a ChatGPT translation from \(sourceLanguage.englishDisplayName) to \(targetLanguage.englishDisplayName). Original text: [\(text)]"
            }
        )
    }
}

extension StringCatalogTranslator {
    public enum TranslationService {
        case deepL, chatgpt
    }

    public enum Failure: Error {
        case translationsPayloadNil
    }
}

extension DependencyValues {
    public var stringCatalogTranslator: StringCatalogTranslator {
        get { self[StringCatalogTranslator.self] }
        set { self[StringCatalogTranslator.self] = newValue }
    }
}

extension StringLanguage {
    var deepLTargetLanguage: DeepLURLSessionClient.Components.Schemas.TargetLanguageText {
        switch self {
        case .english:
            return .EN_hyphen_US
        case .german:
            return .DE
        case .french:
            return .FR
        case .turkish:
            return .TR
        case .polish:
            return .PL
        case .spanish:
            return .ES
        case .chineseSimplified:
            return .ZH
        case .japanese:
            return .JA
        case .italian:
            return .IT
        case .korean:
            return .KO
        case .portuguesePortugal:
            return .PT_hyphen_PT
        case .portugueseBrazil:
            return .PT_hyphen_BR
        case .russian:
            return .RU
        }
    }
    var deepLSourceLanguage: DeepLURLSessionClient.Components.Schemas.SourceLanguageText {
        switch self {
        case .english:
            return .EN
        case .german:
            return .DE
        case .french:
            return .FR
        case .turkish:
            return .TR
        case .polish:
            return .PL
        case .spanish:
            return .ES
        case .chineseSimplified:
            return .ZH
        case .japanese:
            return .JA
        case .italian:
            return .IT
        case .korean:
            return .KO
        case .portuguesePortugal:
            return .PT
        case .portugueseBrazil:
            return .PT
        case .russian:
            return .RU
        }
    }
}
