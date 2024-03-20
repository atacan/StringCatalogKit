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
    // Add any other supported languages here
}

extension StringLanguage {
    public var englishDisplayName: String {
        switch self {
        case .english: return "English"
        case .german: return "German"
        case .french: return "French"
        case .turkish: return "Turkish"
        }
    }
}
