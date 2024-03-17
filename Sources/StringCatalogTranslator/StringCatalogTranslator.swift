import ConcurrencyExtras
import DeepLURLSessionClient
import DeepLURLSessionDependency
import Dependencies
import StringCatalog

public struct StringCatalogTranslator {
    public var translateWithDeepL: @Sendable (_ text: String, _ comment: String?, _ sourceLanguage: StringLanguage, _ targetLanguage: StringLanguage) async throws -> String

    public func translateCatalog(_ catalog: StringCatalog, to targetLanguage: StringLanguage, translationService: TranslationService) async throws -> StringCatalog {
        switch translationService {
        case .deepL:
            try await translateCatalogWithDeepl(catalog, to: targetLanguage)
        case .chatgpt:
            fatalError()
        }
    }

    func translateCatalogWithDeepl(_ catalog: StringCatalog, to targetLanguage: StringLanguage) async throws -> StringCatalog {
        var newCatalog = catalog

        await withTaskGroup(of: (String, String?).self) { group in

            for (textToTranslate, stringEntry) in catalog.strings {

                if stringEntry.localizations == nil {

                    group.addTask {
                        let translation = try? await self.translateWithDeepL(textToTranslate, stringEntry.comment, catalog.sourceLanguage, targetLanguage)
                        return (textToTranslate, translation)
                    }
                } else if stringEntry.localizations?[targetLanguage] == nil {

                    group.addTask {
                        let translation = try? await self.translateWithDeepL(textToTranslate, stringEntry.comment, catalog.sourceLanguage, targetLanguage)
                        return (textToTranslate, translation)
                    }
                }
            }

            for await (original, translation) in group {

                if let translation {
                    if newCatalog.strings[original]?.localizations == nil {
                        newCatalog.strings[original]?.localizations = [StringLanguage: StringLocalization]()
                    }

                    newCatalog.strings[original]?.localizations?[targetLanguage] = StringLocalization(stringUnit: .init(state: .translated, value: translation))
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
            }
        )
    }()

    public static var previewValue: Self {
        Self(
            translateWithDeepL: { text, comment, sourceLanguage, targetLanguage in
                "This is a translation from \(sourceLanguage) to \(targetLanguage). Original text: [\(text)]"
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
        }
    }
}
