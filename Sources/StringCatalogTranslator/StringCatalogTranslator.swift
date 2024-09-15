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
    public static var liveValue: Self = {
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
                let systemPrompt = """
                    You’re a skilled translator with extensive experience in translating \(sourceLanguage) text to \(targetLanguage) while maintaining the original formatting, especially for markdown. Your expertise allows you to ensure that nuances in meaning and cultural context are carefully preserved in the translation, making it accessible and appropriate for \(targetLanguage) speakers.

                    Your task is to translate \(sourceLanguage) UI copy of an macOS app formatted in markdown to \(targetLanguage), ensuring that the markdown formatting remains intact.

                    Please keep in mind any specific context or tone that should be maintained during the translation, particularly regarding cultural references or idiomatic expressions. Also, ensure that any headers, lists, or emphasis in markdown are preserved in the \(targetLanguage) version.

                    For further clarity, here’s how I would like the output formatted:
                    - For headings, translate the text while maintaining the heading level (e.g., # for H1, ## for H2).
                    - For lists, keep the bullet points or numbering intact while translating the content.
                    - For emphasized text (bold or italics), use the appropriate markdown syntax in \(targetLanguage).
                    
                    Only output the translation without backticks.
                    """
                
                let userPrompt = """
                    Here is the text I need you to translate delimited by triple backticks:
                    ```
                    \(text)
                    ```
                    """

                let client = openAi.client()
                let query = ChatQuery(messages: [
                    .system(.init(content: systemPrompt)),
                    .user(.init(content: .string(userPrompt)))
                ], model: .gpt4_o)
                
                let response = try await client.chats(query: query)
                return response.choices.first?.message.content?.string ?? "NO CHOICE"
            }
        )
    }()

    public static var previewValue: Self {
        Self(
            translateWithDeepL: { text, comment, sourceLanguage, targetLanguage in
                "This is a DeepL translation from \(sourceLanguage) to \(targetLanguage). Original text: [\(text)]"
            },
            translateWithChatGPT: { text, comment, sourceLanguage, targetLanguage in
                "This is a ChatGPT translation from \(sourceLanguage) to \(targetLanguage). Original text: [\(text)]"
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
