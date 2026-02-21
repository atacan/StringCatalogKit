import Foundation

public struct LanguageCode: Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral, CodingKey, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init?(stringValue: String) {
        self.rawValue = stringValue
    }

    public var stringValue: String {
        rawValue
    }

    public init?(intValue: Int) {
        return nil
    }

    public var intValue: Int? {
        nil
    }
}

public enum KnownLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case german = "de"
    case french = "fr"
    case turkish = "tr"
    case polish = "pl"
    case spanish = "es"
    case chineseSimplified = "zh-Hans"
    case japanese = "ja"
    case italian = "it"
    case korean = "ko"
    case portuguesePortugal = "pt-PT"
    case portugueseBrazil = "pt-BR"
    case russian = "ru"
}

extension KnownLanguage {
    public var code: LanguageCode {
        LanguageCode(rawValue: rawValue)
    }

    public var englishDisplayName: String {
        switch self {
        case .english: return "English"
        case .german: return "German"
        case .french: return "French"
        case .turkish: return "Turkish"
        case .polish: return "Polish"
        case .spanish: return "Spanish"
        case .chineseSimplified: return "Chinese Simplified"
        case .japanese: return "Japanese"
        case .italian: return "Italian"
        case .korean: return "Korean"
        case .portuguesePortugal: return "Portuguese Portugal"
        case .portugueseBrazil: return "Portuguese Brazil"
        case .russian: return "Russian"
        }
    }
}

public extension LanguageCode {
    static let english = KnownLanguage.english.code
    static let german = KnownLanguage.german.code
    static let french = KnownLanguage.french.code
    static let turkish = KnownLanguage.turkish.code
    static let polish = KnownLanguage.polish.code
    static let spanish = KnownLanguage.spanish.code
    static let chineseSimplified = KnownLanguage.chineseSimplified.code
    static let japanese = KnownLanguage.japanese.code
    static let italian = KnownLanguage.italian.code
    static let korean = KnownLanguage.korean.code
    static let portuguesePortugal = KnownLanguage.portuguesePortugal.code
    static let portugueseBrazil = KnownLanguage.portugueseBrazil.code
    static let russian = KnownLanguage.russian.code

    var knownLanguage: KnownLanguage? {
        KnownLanguage(rawValue: rawValue)
    }

    var englishDisplayName: String {
        knownLanguage?.englishDisplayName ?? rawValue
    }
}

@available(*, deprecated, renamed: "LanguageCode")
public typealias StringLanguage = LanguageCode
