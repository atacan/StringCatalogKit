import ConcurrencyExtras
import StringCatalog
import Dependencies
import DeepLURLSessionDependency
import DeepLURLSessionClient

public struct StringCatalogTranslator {
    public var translateWithDeepL: @Sendable (StringCatalog, _ targetLanguage: StringLanguage) async throws -> StringCatalog
}

extension StringCatalogTranslator: DependencyKey {
    public static var liveValue: Self = {
        @Dependency(\.deepLURLSession) var deepLURLSession
        
        return Self(
        translateWithDeepL: { catalog, targetLanguage in
            let sourceLanguage = catalog.sourceLanguage
            
            return try await translateCatalog(catalog, to: targetLanguage) { text, comment in
                let response = try await deepLURLSession.client().translateText(.init(body: .json(.init(
                    text: [text], 
                    source_lang: sourceLanguage.deepLSourceLanguage,
                    target_lang: targetLanguage.deepLTargetLanguage,
                    context: comment
                ))))
                guard let translation = try response.ok.body.json.translations?.compactMap({ translationsPayload in
                    translationsPayload.text
                }).joined() else {
                    throw Failure.translationsPayloadNil
                }
                return translation
            }
        }
        )
    }()
    
    public static var previewValue: Self {
        return Self (
            translateWithDeepL: { catalog, targetLanguage in
                
                return try await translateCatalog(catalog, to: targetLanguage) { text, comment in
                        return "This is German translation 🇩🇪"
                }
            }
        )
    }
}

extension StringCatalogTranslator {
    enum TranslationService {
    case deepL, chatgpt
    }
    
    enum Failure: Error {
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
              return   .DE
        case .french:
            return .FR
        }
    }
    var deepLSourceLanguage: DeepLURLSessionClient.Components.Schemas.SourceLanguageText {
        switch self {
        case .english:
            return .EN
        case .german:
              return   .DE
        case .french:
            return .FR
        }
    }
}

//func translate(text: String, comment: String? = nil) async throws  -> String {
//    return "Translating [\(text)] using comment: [\(comment ?? "NO COMMENT")]"
//}


