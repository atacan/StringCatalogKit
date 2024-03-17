import Foundation

public struct StringCatalog: Codable, Equatable {
    public var sourceLanguage: StringLanguage
    public var strings: [String: StringEntry]
    public var version: String  // TODO: Use a Version type?
}

// MARK: - Init
extension StringCatalog {
    public init(contentsOf fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        self = try decoder.decode(Self.self, from: data)
    }
}

extension StringCatalog {
    public func encodePrettyToString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let encodedData = try encoder.encode(self)
        return String(data: encodedData, encoding: .utf8)!
    }
}
