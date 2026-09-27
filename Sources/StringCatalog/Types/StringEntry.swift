import Foundation

public struct StringEntry: Codable, Equatable, Sendable {
    public var comment: String?
    public var extractionState: StringExtractionState?
    public var localizations: [LanguageCode: StringLocalization]?
    /// Fields that are not modeled by `StringEntry` but must be preserved when re-encoding.
    public var additionalFields: [String: JSONValue]

    public init(
        comment: String? = nil,
        extractionState: StringExtractionState? = nil,
        localizations: [LanguageCode: StringLocalization]? = nil,
        additionalFields: [String: JSONValue] = [:]
    ) {
        self.comment = comment
        self.extractionState = extractionState
        self.localizations = localizations
        self.additionalFields = additionalFields
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case comment
        case extractionState
        case localizations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
        self.extractionState = try container.decodeIfPresent(StringExtractionState.self, forKey: .extractionState)

        if let rawLocalizations = try container.decodeIfPresent([String: StringLocalization].self, forKey: .localizations) {
            self.localizations = Dictionary(uniqueKeysWithValues: rawLocalizations.map { key, value in
                (LanguageCode(rawValue: key), value)
            })
        } else {
            self.localizations = nil
        }

        let additionalContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        let knownKeys = Set(CodingKeys.allCases.map(\.rawValue))
        self.additionalFields = try Dictionary(uniqueKeysWithValues: additionalContainer.allKeys.compactMap { key in
            guard !knownKeys.contains(key.stringValue) else { return nil }
            return (key.stringValue, try additionalContainer.decode(JSONValue.self, forKey: key))
        })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(extractionState, forKey: .extractionState)

        if let localizations {
            let rawLocalizations = Dictionary(uniqueKeysWithValues: localizations.map { key, value in
                (key.rawValue, value)
            })
            try container.encode(rawLocalizations, forKey: .localizations)
        }
        var additionalContainer = encoder.container(keyedBy: AnyCodingKey.self)
        let knownKeys = Set(CodingKeys.allCases.map(\.rawValue))
        for (key, value) in additionalFields where !knownKeys.contains(key) {
            try additionalContainer.encode(value, forKey: AnyCodingKey(key))
        }
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        return nil
    }
}
