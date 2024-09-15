import Foundation

//public struct StringLanguage: Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral {
//    public let rawValue: String
//
//    public init(rawValue: String) {
//        self.rawValue = rawValue
//    }
//
//    public init(stringLiteral value: StringLiteralType) {
//        self.init(rawValue: value)
//    }
//
//    public static let english = Self(rawValue: "en")
//}

public enum StringLanguage: String, Codable, CodingKey, CodingKeyRepresentable, Equatable {
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
    // Add any other supported languages here
}

extension StringLanguage {
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
