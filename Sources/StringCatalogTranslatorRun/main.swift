//
// https://github.com/atacan
// 17.03.24
	

import Foundation
import StringCatalogTranslator
import StringCatalog
import Dependencies

func translateCatalogFile(at catalogFile: URL, to targetLanguage: StringLanguage, using translationService: StringCatalogTranslator.TranslationService ) async throws {
    @Dependency(\.stringCatalogTranslator) var stringCatalogTranslator
    
    let jsonData = try String(contentsOf: catalogFile).data(using: .utf8)!
    let decoder = JSONDecoder()
    let catalog = try decoder.decode(StringCatalog.self, from: jsonData)
    
    let translatedCatalog = try await stringCatalogTranslator.translateCatalog(catalog, to: targetLanguage, translationService: translationService)
    let translatedCatalogJson = try translatedCatalog.encodePrettyToString()
    try translatedCatalogJson.write(to: catalogFile, atomically: true, encoding: .utf8)
//    print(translatedCatalogJson)
}


/// ```swift
/// dump(
///     try stringCatalogFiles(at: URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources"))
/// )
/// ```
func stringCatalogFiles(at directory: URL) throws -> [URL] {
    var files = [URL]()

    if let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
        for case let fileURL as URL in enumerator {
            do {
                let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                if let isRegularFile = fileAttributes.isRegularFile,
                    isRegularFile,
                    fileURL.lastPathComponent.hasSuffix("xcstrings") {
                    files.append(fileURL)
                }
            } catch { print(error, fileURL) }
        }
    }
    
    return files
}

for file in try stringCatalogFiles(at: URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/")) {
    try await translateCatalogFile(at: file, to: .turkish, using: .deepL)
    print("👍", file)
}

// try await withDependencies {
// //     $0.stringCatalogTranslator = .previewValue
//     $0.stringCatalogTranslator = .liveValue
// } operation: {
// //    let file = URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/Settings/Resources/Localizable.xcstrings")
// //    let file = URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/SharedModels/Resources/Localizable.xcstrings")
//     let file = URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/ReplacementDependency/Resources/Localizable.xcstrings")
//     try await translateCatalogFile(at: file, to: .turkish, using: .deepL)
// //    @Dependency(\.stringCatalogTranslator) var stringCatalogTranslator
// //    let output = try await stringCatalogTranslator.translateWithChatGPT("Hello new user", "welcome text", .english, .german)
// //    print(output)
// }

