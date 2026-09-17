import Foundation

public struct StringEntry: Codable, Equatable, Sendable {
    public var comment: String?
    public var extractionState: StringExtractionState?
    public var localizations: [LanguageCode: StringLocalization]?
    public var shouldTranslate: Bool?

    public init(
        comment: String? = nil,
        extractionState: StringExtractionState? = nil,
        localizations: [LanguageCode: StringLocalization]? = nil,
        shouldTranslate: Bool? = nil
    ) {
        self.comment = comment
        self.extractionState = extractionState
        self.localizations = localizations
        self.shouldTranslate = shouldTranslate
    }

    enum CodingKeys: String, CodingKey {
        case comment
        case extractionState
        case localizations
        case shouldTranslate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
        self.extractionState = try container.decodeIfPresent(StringExtractionState.self, forKey: .extractionState)
        self.shouldTranslate = try container.decodeIfPresent(Bool.self, forKey: .shouldTranslate)

        if let rawLocalizations = try container.decodeIfPresent([String: StringLocalization].self, forKey: .localizations) {
            self.localizations = Dictionary(uniqueKeysWithValues: rawLocalizations.map { key, value in
                (LanguageCode(rawValue: key), value)
            })
        } else {
            self.localizations = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(extractionState, forKey: .extractionState)
        try container.encodeIfPresent(shouldTranslate, forKey: .shouldTranslate)

        if let localizations {
            let rawLocalizations = Dictionary(uniqueKeysWithValues: localizations.map { key, value in
                (key.rawValue, value)
            })
            try container.encode(rawLocalizations, forKey: .localizations)
        }
    }
}
