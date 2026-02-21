import Foundation

public struct StringVariation: Codable, Equatable, Sendable {
    public var stringUnit: StringUnit

    public init(stringUnit: StringUnit) {
        self.stringUnit = stringUnit
    }
}
