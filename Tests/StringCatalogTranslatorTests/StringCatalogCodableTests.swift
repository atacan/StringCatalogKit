//
// https://github.com/atacan
// 03.05.24
	

import CustomDump
import XCTest
import Foundation
@testable import StringCatalog

final class StringCatalogCodableTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testStringUnit() throws {
        let catalogJson = try String(contentsOf: InputFiles.DipDictSettings)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: catalogJson.data(using: .utf8)!)
    }

    func testStringSet() throws {
        let catalogJson = try String(contentsOf: InputFiles.AppShortcuts)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: catalogJson.data(using: .utf8)!)
        
        let oneOfThem = catalog.strings["${applicationName} insert latest"]!
        let oneLocalization = oneOfThem.localizations![StringLanguage.english]!
        
        XCTAssertNil(oneLocalization.stringUnit)
        XCTAssertNotNil(oneLocalization.stringSet)
    }
    
    func testEncodeSameStringUnit() throws {
        let catalogJson: String = try String(contentsOf: InputFiles.AppShortcuts)
        let catalog: StringCatalog = try JSONDecoder().decode(StringCatalog.self, from: catalogJson.data(using: .utf8)!)
        
        XCTAssertNoDifference(catalogJson, try catalog.encodePrettyToString())
    }

    func testEncodeSameStringSet() throws {
        let catalogJson: String = try String(contentsOf: InputFiles.AppShortcuts)
        let catalog: StringCatalog = try JSONDecoder().decode(StringCatalog.self, from: catalogJson.data(using: .utf8)!)
        
        XCTAssertNoDifference(catalogJson, try catalog.encodePrettyToString())
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

public class TestingUtility {
    
    public static func readFile(_ path: String) -> String {
        let absolutePath = Bundle.module.url(forResource: path, withExtension: "")!
        return try! String(contentsOf: absolutePath, encoding: .utf8)
    }
    
    public static func readBytes(_ path: String) -> Foundation.Data {
        let absolutePath = Bundle.module.url(forResource: path, withExtension: "")!
        return try! Data(contentsOf: absolutePath)
    }
}
