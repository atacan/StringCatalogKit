import Foundation
import XCTest
@testable import StringCatalog

final class StringCatalogCodableTests: XCTestCase {
    func testDecodeStringUnitCatalog() throws {
        let catalogJson = try String(contentsOf: InputFiles.dipDictSettings)
        _ = try JSONDecoder().decode(StringCatalog.self, from: Data(catalogJson.utf8))
    }

    func testDecodeStringSetCatalog() throws {
        let catalogJson = try String(contentsOf: InputFiles.appShortcuts)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: Data(catalogJson.utf8))

        let oneEntry = catalog.strings["${applicationName} insert latest"]
        let oneLocalization = oneEntry?.localizations?[.english]

        XCTAssertNil(oneLocalization?.stringUnit)
        XCTAssertNotNil(oneLocalization?.stringSet)
    }

    func testEncodeSameStringUnitCatalog() throws {
        let catalogJson = try String(contentsOf: InputFiles.dipDictSettings)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: Data(catalogJson.utf8))
        let encoded = try catalog.encodePrettyToString()
        let decodedAgain = try JSONDecoder().decode(StringCatalog.self, from: Data(encoded.utf8))
        XCTAssertEqual(catalog, decodedAgain)
    }

    func testEncodeSameStringSetCatalog() throws {
        let catalogJson = try String(contentsOf: InputFiles.appShortcuts)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: Data(catalogJson.utf8))
        let encoded = try catalog.encodePrettyToString()
        let decodedAgain = try JSONDecoder().decode(StringCatalog.self, from: Data(encoded.utf8))
        XCTAssertEqual(catalog, decodedAgain)
    }

    func testShouldTranslateRoundTrips() throws {
        let json = #"{"sourceLanguage":"en","strings":{"Brand":{"shouldTranslate":false}},"version":"1.0"}"#

        let catalog = try JSONDecoder().decode(StringCatalog.self, from: Data(json.utf8))

        XCTAssertEqual(catalog.strings["Brand"]?.shouldTranslate, false)

        let encoded = try catalog.encodePrettyToString()
        let encodedCatalog = try JSONDecoder().decode(StringCatalog.self, from: Data(encoded.utf8))
        XCTAssertEqual(encodedCatalog.strings["Brand"]?.shouldTranslate, false)
    }
}

enum InputFiles {
    static var testResourcesDirectory: URL {
        URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("TestResources")
    }

    static var dipDictSettings: URL {
        testResourcesDirectory.appending(path: "DipDictSettings.xcstrings")
    }

    static var appShortcuts: URL {
        testResourcesDirectory.appending(path: "AppShortcuts.xcstrings")
    }
}
