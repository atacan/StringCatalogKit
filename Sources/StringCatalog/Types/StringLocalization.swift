import Foundation

public struct StringLocalization: Codable, Equatable, Sendable {
    public var stringUnit: StringUnit?
    public var stringSet: StringSet?
    public var substitutions: [String: StringSubstitution]?
    public var variations: StringVariations?

    public init(
        stringUnit: StringUnit? = nil,
        stringSet: StringSet? = nil,
        substitutions: [String: StringSubstitution]? = nil,
        variations: StringVariations? = nil
    ) {
        self.stringUnit = stringUnit
        self.stringSet = stringSet
        self.substitutions = substitutions
        self.variations = variations
    }
}
