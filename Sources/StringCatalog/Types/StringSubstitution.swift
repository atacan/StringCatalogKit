import Foundation

public struct StringSubstitution: Codable, Equatable, Sendable {
    public var argNum: Int
    public var formatSpecifier: String
    public var variations: StringVariations?

    public init(argNum: Int, formatSpecifier: String, variations: StringVariations? = nil) {
        self.argNum = argNum
        self.formatSpecifier = formatSpecifier
        self.variations = variations
    }
}
