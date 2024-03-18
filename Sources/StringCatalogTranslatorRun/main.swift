//
// https://github.com/atacan
// 17.03.24
	

import Foundation
import StringCatalogTranslator
import StringCatalog
import Dependencies

func translateCatalog(at catalogFile: URL, targetLanguage: StringLanguage ) async throws {
    @Dependency(\.stringCatalogTranslator) var stringCatalogTranslator
    
    let jsonData = try String(contentsOf: catalogFile).data(using: .utf8)!
    let decoder = JSONDecoder()
    let catalog = try decoder.decode(StringCatalog.self, from: jsonData)
    
    let translatedCatalog = try await stringCatalogTranslator.translateCatalog(catalog, to: targetLanguage, translationService: .deepL)
    let translatedCatalogJson = try translatedCatalog.encodePrettyToString()
    try translatedCatalogJson.write(to: catalogFile, atomically: true, encoding: .utf8)
    print(translatedCatalogJson)
}

let fileUrls = [
    URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/NotesHistory/Resources/Localizable.xcstrings"),
    URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/OpenAIClient/Resources/Localizable.xcstrings"),
    URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/ReplacementDependency/Resources/Localizable.xcstrings"),
    URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/Settings/Resources/Localizable.xcstrings"),
    URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/SpeechToType/Resources/Localizable.xcstrings"),
]

try await withDependencies {
    // $0.stringCatalogTranslator = .previewValue
    $0.stringCatalogTranslator = .liveValue
} operation: {
    try await translateCatalog(at: URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/NotesHistory/Resources/Localizable.xcstrings"),
                               targetLanguage: .turkish
    )
}

