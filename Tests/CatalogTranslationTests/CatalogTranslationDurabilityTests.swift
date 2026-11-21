import CatalogTranslation
import Foundation
import StringCatalog
import XCTest

final class CatalogTranslationDurabilityTests: XCTestCase {
    func testCheckpointsDeliverGrowingPartialResults() async throws {
        let checkpoints = CheckpointRecorder()
        let engine = CatalogTranslationEngine(
            translator: ClosureTranslator { "de::\($0.text)" },
            options: TranslationOptions(
                maxConcurrentRequests: 1,
                checkpointPolicy: TranslationCheckpointPolicy(everySegments: 2, interval: 3600)
            )
        )

        let result = try await engine.translateCatalog(makeCatalog(count: 5), to: .german) { partial in
            await checkpoints.record(partial)
        }

        let recorded = await checkpoints.results
        XCTAssertEqual(recorded.map(\.report.translatedRequests.count), [2, 4])
        for partial in recorded {
            let translated = partial.catalog.strings.values.filter { $0.localizations?[.german]?.stringUnit != nil }
            XCTAssertEqual(translated.count, partial.report.translatedRequests.count)
            XCTAssertEqual(partial.report.stats.skippedSegments, 5 - partial.report.translatedRequests.count)
        }
        XCTAssertEqual(result.report.stats.translatedSegments, 5)
        XCTAssertEqual(result.report.translatedRequests.count, 5)
        XCTAssertNil(result.report.abort)
    }

    func testCheckpointHandlerErrorStopsTheRun() async throws {
        struct DiskFull: Error {}
        let engine = CatalogTranslationEngine(
            translator: ClosureTranslator { $0.text },
            options: TranslationOptions(
                maxConcurrentRequests: 1,
                checkpointPolicy: TranslationCheckpointPolicy(everySegments: 1, interval: 3600)
            )
        )

        do {
            _ = try await engine.translateCatalog(makeCatalog(count: 3), to: .german) { _ in throw DiskFull() }
            XCTFail("Expected the checkpoint error to propagate")
        } catch is DiskFull {}
    }

    func testFatalErrorAbortsAndKeepsEarlierSuccesses() async throws {
        let calls = Counter()
        let engine = CatalogTranslationEngine(
            translator: ClosureTranslator { request in
                let call = await calls.increment()
                if call == 3 { throw CatalogTranslationAbort(reason: "HTTP 401") }
                return "de::\(request.text)"
            },
            options: TranslationOptions(maxConcurrentRequests: 1)
        )

        let result = try await engine.translateCatalog(makeCatalog(count: 10), to: .german)

        let callCount = await calls.value
        XCTAssertEqual(callCount, 3)
        XCTAssertEqual(result.report.abort, TranslationAbortInfo(cause: .fatalError, reason: "HTTP 401"))
        XCTAssertEqual(result.report.stats.translatedSegments, 2)
        XCTAssertEqual(result.report.stats.failedSegments, 1)
        XCTAssertEqual(result.report.stats.skippedSegments, 7)
        XCTAssertEqual(result.report.translatedRequests.count, 2)
    }

    func testConsecutiveFailureLimitAbortsTheRun() async throws {
        struct Flaky: Error {}
        let calls = Counter()
        let engine = CatalogTranslationEngine(
            translator: ClosureTranslator { _ in
                _ = await calls.increment()
                throw Flaky()
            },
            options: TranslationOptions(maxConcurrentRequests: 1, maxConsecutiveFailures: 3)
        )

        let result = try await engine.translateCatalog(makeCatalog(count: 10), to: .german)

        let callCount = await calls.value
        XCTAssertEqual(callCount, 3)
        XCTAssertEqual(result.report.abort?.cause, .consecutiveFailures(3))
        XCTAssertEqual(result.report.stats.failedSegments, 3)
        XCTAssertEqual(result.report.stats.skippedSegments, 7)
    }

    func testSuccessResetsConsecutiveFailureCount() async throws {
        struct Flaky: Error {}
        let calls = Counter()
        let engine = CatalogTranslationEngine(
            translator: ClosureTranslator { request in
                // Fail two out of every three calls: never three in a row.
                if await calls.increment() % 3 != 0 { throw Flaky() }
                return request.text
            },
            options: TranslationOptions(maxConcurrentRequests: 1, maxConsecutiveFailures: 3)
        )

        let result = try await engine.translateCatalog(makeCatalog(count: 9), to: .german)

        XCTAssertNil(result.report.abort)
        XCTAssertEqual(result.report.stats.failedSegments, 6)
        XCTAssertEqual(result.report.stats.translatedSegments, 3)
    }

    func testAbortWithConcurrencyStopsQueuedRequests() async throws {
        let calls = Counter()
        let engine = CatalogTranslationEngine(
            translator: ClosureTranslator { _ in
                _ = await calls.increment()
                throw CatalogTranslationAbort(reason: "quota exceeded")
            },
            options: TranslationOptions(maxConcurrentRequests: 4)
        )

        let result = try await engine.translateCatalog(makeCatalog(count: 200), to: .german)

        let callCount = await calls.value
        XCTAssertLessThan(callCount, 200)
        XCTAssertEqual(result.report.abort?.cause, .fatalError)
        XCTAssertEqual(result.report.stats.failedSegments, 1)
        XCTAssertEqual(result.report.stats.translatedSegments + result.report.stats.failedSegments + result.report.stats.skippedSegments, 200)
    }

    func testStrictFailureWithQueuedJobsReturnsInsteadOfHanging() async throws {
        struct Boom: Error {}
        let engine = CatalogTranslationEngine(
            translator: ClosureTranslator { _ in throw Boom() },
            options: TranslationOptions(maxConcurrentRequests: 2)
        )

        do {
            _ = try await engine.translateCatalog(makeCatalog(count: 50), to: .german, mode: .strict)
            XCTFail("Expected strict mode to throw")
        } catch is CatalogTranslationEngineError {}
    }
}

private struct ClosureTranslator: CatalogTextTranslator {
    let closure: @Sendable (TranslationRequest) async throws -> String

    init(_ closure: @escaping @Sendable (TranslationRequest) async throws -> String) {
        self.closure = closure
    }

    func translate(_ request: TranslationRequest) async throws -> String {
        try await closure(request)
    }
}

private actor Counter {
    private(set) var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

private actor CheckpointRecorder {
    private(set) var results: [CatalogTranslationResult] = []

    func record(_ result: CatalogTranslationResult) {
        results.append(result)
    }
}

private func makeCatalog(count: Int) -> StringCatalog {
    var strings: [String: StringEntry] = [:]
    for index in 0..<count {
        strings["key\(index)"] = StringEntry(
            localizations: [.english: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Text \(index)"))]
        )
    }
    return StringCatalog(sourceLanguage: .english, strings: strings, version: "1.0")
}
