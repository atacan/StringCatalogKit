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
    /// Stop a best-effort run after this many failures in a row (in completion order).
    /// `nil` never stops early on repeated failures.
    public var maxConsecutiveFailures: Int?
    /// When to hand partial results to the `onCheckpoint` handler of `translateCatalog`.
    public var checkpointPolicy: TranslationCheckpointPolicy

    public init(
        maxConcurrentRequests: Int = 6,
        maxConsecutiveFailures: Int? = nil,
        checkpointPolicy: TranslationCheckpointPolicy = .default
    ) {
        self.maxConcurrentRequests = max(1, maxConcurrentRequests)
        self.maxConsecutiveFailures = maxConsecutiveFailures.map { max(1, $0) }
        self.checkpointPolicy = checkpointPolicy
    }

    public static let `default` = Self()
}

/// A checkpoint is due once at least one new segment has been translated since the last
/// checkpoint and either `everySegments` new segments have been translated or
/// `interval` seconds have passed.
public struct TranslationCheckpointPolicy: Sendable, Hashable {
    public var everySegments: Int
    public var interval: TimeInterval

    public init(everySegments: Int = 25, interval: TimeInterval = 5) {
        self.everySegments = max(1, everySegments)
        self.interval = max(0, interval)
    }

    public static let `default` = Self()
}

/// Throw this from a `CatalogTextTranslator` when retrying other segments is pointless,
/// for example on an authentication or quota error. A best-effort run records the
/// failure, stops starting requests, cancels in-flight ones, and returns what succeeded.
public struct CatalogTranslationAbort: Error, CustomStringConvertible, Sendable {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public var description: String { reason }
}

public struct TranslationAbortInfo: Sendable, Hashable {
    public enum Cause: Sendable, Hashable {
        /// The translator threw `CatalogTranslationAbort`.
        case fatalError
        /// `TranslationOptions.maxConsecutiveFailures` was reached.
        case consecutiveFailures(Int)
    }

    public let cause: Cause
    public let reason: String

    public init(cause: Cause, reason: String) {
        self.cause = cause
        self.reason = reason
    }
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
    /// Requests whose translation is applied to the result's catalog. Requests that are
    /// neither translated nor failed were skipped (an aborted run or a partial checkpoint).
    public let translatedRequests: [TranslationRequest]
    /// Set when a best-effort run stopped before attempting every segment.
    public let abort: TranslationAbortInfo?

    public init(
        stats: TranslationStats,
        failures: [TranslationFailure],
        translatedRequests: [TranslationRequest] = [],
        abort: TranslationAbortInfo? = nil
    ) {
        self.stats = stats
        self.failures = failures
        self.translatedRequests = translatedRequests
        self.abort = abort
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
