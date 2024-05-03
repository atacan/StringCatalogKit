import Foundation

/// ```json
/// "stringUnit" : {
///   "state" : "translated",
///   "value" : "Diktieren"
/// }
/// ```
public struct StringUnit: Codable, Equatable {
    public var state: StringUnitState
    public var value: String

    public init(state: StringUnitState, value: String) {
        self.state = state
        self.value = value
    }
}

/// ```json
/// "stringSet" : {
///   "state" : "translated",
///   "values" : [
///     "${applicationName} Letzte einfügen",
///     "${applicationName} Letzte",
///     "${applicationName} Letzte Notiz"
///   ]
/// }
/// ```
public struct StringSet: Codable, Equatable {
    public var state: StringUnitState
    public var values: [String]

    public init(state: StringUnitState, values: [String]) {
        self.state = state
        self.values = values
    }
}