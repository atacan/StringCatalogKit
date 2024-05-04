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
        @Dependency(OpenAIUrlSessionDependency.self) var openAi

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
                    You are a highly skilled translator with expertise in many languages. Your task is to accurately translate the \(sourceLanguage.englishDisplayName) text into \(targetLanguage.englishDisplayName) while preserving the meaning, tone, and nuance of the original text. Please maintain proper grammar, spelling, and punctuation in the translated version. The content will be given with a hint to understand the context. The content is the copy text of a macOS app that provides speech-to-text functionality. Only output the translation without any comment.

                    Example Input:

                    <content>
                    You can start the recording by
                     • clicking on the status bar item or
                     • using the keyboard shortcut defined below
                    </content>
                    <hint>
                    the description for the audio recording settings
                    </hint>
                    <output>
                    Sie können die Aufnahme starten, indem Sie
                     • auf das Symbol in der Statusleiste klicken oder
                     • die unten definierte Tastenkombination verwenden
                    """

                let userPrompt = {
                    var content = "<content>\n\(text)\n</content>"
                    guard let comment else { return content + "\n<output>\n" }
                    return content + "\n<hint>\n\(comment)\n</hint>" + "\n<output>\n"
                }()

                let client = openAi.client()
                let response = try await client.createChatCompletion(
                    body: .json(
                        .init(
                            messages: [
                                .ChatCompletionRequestSystemMessage(.init(content: systemPrompt, role: .system)),
                                .ChatCompletionRequestUserMessage(.init(content: .case1(userPrompt), role: .user)),
                            ],
                            model: .init(value2: .gpt_hyphen_3_period_5_hyphen_turbo)
                        )
                    )
                )
                guard let translation = try response.ok.body.json.choices[0].message.content else {
                    throw StringCatalogTranslator.Failure.translationsPayloadNil
                }

                return translation
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
        }
    }
}
