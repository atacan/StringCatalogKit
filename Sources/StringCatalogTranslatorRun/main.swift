//
// https://github.com/atacan
// 17.03.24

import Dependencies
import Foundation
import StringCatalog
import StringCatalogTranslator

try await withDependencies {
    //     $0.stringCatalogTranslator = .previewValue
    $0.stringCatalogTranslator = .liveValue
} operation: {
    try await TranslateStringCatalog.translateCatalogFiles(at: URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/"), to: [.german, .french, .turkish], using: .chatgpt)
}
