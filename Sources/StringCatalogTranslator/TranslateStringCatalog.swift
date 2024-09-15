import Dependencies
import Foundation
import StringCatalog

public enum TranslateStringCatalog {
    static public func translateCatalogFiles(at directory: URL, to targetLanguages: [StringLanguage], using translationService: StringCatalogTranslator.TranslationService) async throws {
        for language in targetLanguages {
            try await translateCatalogFiles(at: directory, to: language, using: translationService)
        }
    }

    static func translateCatalogFiles(at directory: URL, to targetLanguage: StringLanguage, using translationService: StringCatalogTranslator.TranslationService) async throws {
        for file in try stringCatalogFiles(at: directory) {
            try await translateCatalogFile(at: file, to: targetLanguage, using: translationService)
        }
    }
    static func translateCatalogFile(at catalogFile: URL, to targetLanguage: StringLanguage, using translationService: StringCatalogTranslator.TranslationService) async throws {
        @Dependency(\.stringCatalogTranslator) var stringCatalogTranslator

        let json = try String(contentsOf: catalogFile)
        let jsonData = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let catalog = try decoder.decode(StringCatalog.self, from: jsonData)

        let translatedCatalog = try await stringCatalogTranslator.translateCatalog(catalog, to: targetLanguage, translationService: translationService)
        let translatedCatalogJson = try translatedCatalog.encodePrettyToString()
        if translatedCatalogJson != json {
            try translatedCatalogJson.write(to: catalogFile, atomically: true, encoding: .utf8)
            print("🌐", targetLanguage)
        }
    }
    
    public static func stringCatalogs(at directory: URL) throws -> [StringCatalog] {
        var catalogs = [StringCatalog]()
        for file in try stringCatalogFiles(at: directory) {
            let json = try String(contentsOf: file)
            let jsonData = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            let catalog = try decoder.decode(StringCatalog.self, from: jsonData)
            catalogs.append(catalog)
        }
        return catalogs
    }

    /// ```swift
    /// dump(
    ///     try stringCatalogFiles(at: URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources"))
    /// )
    /// ```
    public static func stringCatalogFiles(at directory: URL) throws -> [URL] {
        var files = [URL]()

        if let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if let isRegularFile = fileAttributes.isRegularFile,
                        isRegularFile,
                        fileURL.lastPathComponent.hasSuffix("xcstrings")
                    {
                        files.append(fileURL)
                    }
                } catch { print(error, fileURL) }
            }
        }

        return files
    }

}
