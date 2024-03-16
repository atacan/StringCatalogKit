import Foundation

public struct StringSubstitution: Codable, Equatable {
    public let argNum: Int
    public let formatSpecifier: String
    public let variations: StringVariations?
}
