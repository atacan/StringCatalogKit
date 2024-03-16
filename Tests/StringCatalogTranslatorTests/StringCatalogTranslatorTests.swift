//
// https://github.com/atacan
// 16.03.24
	

import XCTest
import StringCatalogTranslator
import Dependencies
import StringCatalog

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
        
        try await withDependencies {
            $0.stringCatalogTranslator.translateWithDeepL = { catalog, targetLanguage in
                return catalog
            }
        } operation: {
            let translatedCatalog = try await stringCatalogTranslator.translateWithDeepL(catalog, .german)
            
            XCTAssertEqual(catalog, translatedCatalog)
            XCTAssertEqual(catalogJson, try catalog.encodePrettyToString())
            XCTAssertEqual(catalogJson, try translatedCatalog.encodePrettyToString())
        }
    }
    
    func testManualCheck() async throws {
        let catalogJson = try String(contentsOf: InputFiles.DipDictSettings)
        
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: catalogJson.data(using: .utf8)!)
        
        try await withDependencies {
            $0.stringCatalogTranslator = .previewValue
        } operation: {
            let translatedCatalog = try await stringCatalogTranslator.translateWithDeepL(catalog, .german)
            let translatedCatalogPath = InputFiles.testResourcesDirectory.appending(component: "_DipDictSettings.json").path()
//            let translatedCatalogPath = InputFiles.testResourcesDirectory.appending(component: "_DipDictSettings.xcstrings").path()
            try translatedCatalog.encodePrettyToString().write(toFile: translatedCatalogPath, atomically: true, encoding: .utf8)
//            XCTAssertEqual(catalog, translatedCatalog)
//            XCTAssertEqual(catalogJson, try catalog.encodePrettyToString())
//            XCTAssertEqual(catalogJson, try translatedCatalog.encodePrettyToString())
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
