import Foundation

public struct StringEntry: Codable, Equatable {
    //    public typealias Localizations = DictionaryWrapper<StringLanguage, StringLocalization>

    public var comment: String?
    public var extractionState: StringExtractionState?
    //    public var localizations: Localizations?
    public var localizations: [StringLanguage: StringLocalization]?
}
