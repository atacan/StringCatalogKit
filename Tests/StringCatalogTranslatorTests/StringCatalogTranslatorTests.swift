//
// https://github.com/atacan
// 16.03.24

import CustomDump
import Dependencies
import StringCatalog
import StringCatalogTranslator
import XCTest

final class StringCatalogTranslatorTests: XCTestCase {
    @Dependency(StringCatalogTranslator.self) var stringCatalogTranslator

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNoChange() async throws {
        let catalogJson = try String(contentsOf: InputFiles.DipDictSettings)

        let catalog = try JSONDecoder().decode(StringCatalog.self, from: catalogJson.data(using: .utf8)!)
        enum LocalError: Error { case failToTranslate }
        try await withDependencies {
            $0.stringCatalogTranslator.translateWithDeepL = { text, _, _, _ in
                throw LocalError.failToTranslate
            }
        } operation: {
            let translatedCatalog = try await stringCatalogTranslator.translateCatalog(catalog, to: .german, translationService: .deepL)

            XCTAssertNoDifference(catalog, translatedCatalog)
            XCTAssertNoDifference(catalogJson, try catalog.encodePrettyToString())
            XCTAssertNoDifference(catalogJson, try translatedCatalog.encodePrettyToString())
        }
    }

    func testDeepL() async throws {
        let catalogJson = try String(contentsOf: InputFiles.DipDictSettings)

        let catalog = try JSONDecoder().decode(StringCatalog.self, from: catalogJson.data(using: .utf8)!)

        try await withDependencies {
            $0.stringCatalogTranslator = .previewValue
        } operation: {
            let targetLanguage = StringLanguage.german
            let translatedCatalog = try await stringCatalogTranslator.translateCatalog(catalog, to: targetLanguage, translationService: .deepL)

            // every string has localization
            for (textToTranslate, stringEntry) in translatedCatalog.strings {
                guard let localizations = stringEntry.localizations else {
                    fatalError()
                }
                // every localization has entry for target language
                guard let localization = localizations[targetLanguage] else {
                    fatalError()
                }

                // the existing translation stayed the same
                if let existing = catalog.strings[textToTranslate]?.localizations?[targetLanguage]?.stringUnit?.value {
                    XCTAssertEqual(localization.stringUnit?.value, existing)
                }

            }

            // same amount of keys
            XCTAssertEqual(catalog.strings.keys.count, translatedCatalog.strings.keys.count)

            let translatedCatalogPath = InputFiles.testResourcesDirectory.appending(component: "_DipDictSettings.json").path()
            //            let translatedCatalogPath = InputFiles.testResourcesDirectory.appending(component: "_DipDictSettings.xcstrings").path()
            try translatedCatalog.encodePrettyToString().write(toFile: translatedCatalogPath, atomically: true, encoding: .utf8)

        }
    }
}

enum InputFiles {

    static var testResourcesDirectory: URL {
        let currentFile = URL(fileURLWithPath: #file).deletingLastPathComponent()
        return currentFile.appendingPathComponent("TestResources")
    }

    static var DipDictSettings: URL {
        return Self.testResourcesDirectory.appending(component: "DipDictSettings.xcstrings")
    }

}
