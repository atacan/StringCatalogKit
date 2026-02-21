import Foundation
import StringCatalog

public protocol CatalogTextTranslator: Sendable {
    func translate(_ request: TranslationRequest) async throws -> String
}

public struct TranslationRequest: Sendable, Hashable {
    public let text: String
    public let sourceLanguage: LanguageCode
    public let targetLanguage: LanguageCode
    public let stringKey: String
    public let developerComment: String?
    public let segment: TranslationSegment

    public init(
        text: String,
        sourceLanguage: LanguageCode,
        targetLanguage: LanguageCode,
        stringKey: String,
        developerComment: String?,
        segment: TranslationSegment
    ) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.stringKey = stringKey
        self.developerComment = developerComment
        self.segment = segment
    }
}

public enum TranslationSegment: Sendable, Hashable {
    case stringUnit
    case stringSet(index: Int)
    case variation(path: String)
}

public enum TranslationMode: Sendable {
    case bestEffort
    case strict
}

public struct TranslationOptions: Sendable {
    public var maxConcurrentRequests: Int

    public init(maxConcurrentRequests: Int = 6) {
        self.maxConcurrentRequests = max(1, maxConcurrentRequests)
    }

    public static let `default` = Self()
}

public struct TranslationFailure: Sendable, Hashable {
    public let stringKey: String
    public let segment: TranslationSegment
    public let sourceLanguage: LanguageCode
    public let targetLanguage: LanguageCode
    public let reason: String

    public init(
        stringKey: String,
        segment: TranslationSegment,
        sourceLanguage: LanguageCode,
        targetLanguage: LanguageCode,
        reason: String
    ) {
        self.stringKey = stringKey
        self.segment = segment
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.reason = reason
    }
}

public struct TranslationStats: Sendable, Hashable {
    public var attemptedSegments: Int
    public var translatedSegments: Int
    public var failedSegments: Int
    public var skippedSegments: Int

    public init(
        attemptedSegments: Int = 0,
        translatedSegments: Int = 0,
        failedSegments: Int = 0,
        skippedSegments: Int = 0
    ) {
        self.attemptedSegments = attemptedSegments
        self.translatedSegments = translatedSegments
        self.failedSegments = failedSegments
        self.skippedSegments = skippedSegments
    }
}

public struct TranslationReport: Sendable, Hashable {
    public let stats: TranslationStats
    public let failures: [TranslationFailure]

    public init(stats: TranslationStats, failures: [TranslationFailure]) {
        self.stats = stats
        self.failures = failures
    }
}

public struct CatalogTranslationResult: Sendable {
    public let catalog: StringCatalog
    public let report: TranslationReport

    public init(catalog: StringCatalog, report: TranslationReport) {
        self.catalog = catalog
        self.report = report
    }
}

public enum CatalogTranslationEngineError: Error, Sendable {
    case strictFailure(TranslationFailure)
}

public struct PlannedFileChange: Sendable {
    public let fileURL: URL
    public let originalContent: String
    public let updatedContent: String

    public init(fileURL: URL, originalContent: String, updatedContent: String) {
        self.fileURL = fileURL
        self.originalContent = originalContent
        self.updatedContent = updatedContent
    }
}

public struct FileTranslationPlan: Sendable {
    public struct Item: Sendable {
        public let fileURL: URL
        public let changed: Bool
        public let stats: TranslationStats
        public let failures: [TranslationFailure]

        public init(fileURL: URL, changed: Bool, stats: TranslationStats, failures: [TranslationFailure]) {
            self.fileURL = fileURL
            self.changed = changed
            self.stats = stats
            self.failures = failures
        }
    }

    public let items: [Item]
    public let changes: [PlannedFileChange]

    public init(items: [Item], changes: [PlannedFileChange]) {
        self.items = items
        self.changes = changes
    }
}

public struct FileApplyReport: Sendable {
    public let writtenFiles: [URL]

    public init(writtenFiles: [URL]) {
        self.writtenFiles = writtenFiles
    }
}
