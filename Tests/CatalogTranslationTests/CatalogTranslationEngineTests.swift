import CatalogTranslation
import Foundation
import StringCatalog
import XCTest

final class CatalogTranslationEngineTests: XCTestCase {
    func testBestEffortCollectsFailures() async throws {
        let translator = ClosureTranslator { _ in
            struct DummyError: Error {}
            throw DummyError()
        }

        let engine = CatalogTranslationEngine(translator: translator)
        let catalog = makeSimpleCatalog()

        let result = try await engine.translateCatalog(catalog, to: .german, mode: .bestEffort)

        XCTAssertEqual(result.report.stats.attemptedSegments, 1)
        XCTAssertEqual(result.report.stats.translatedSegments, 0)
        XCTAssertEqual(result.report.stats.failedSegments, 1)
        XCTAssertEqual(result.report.failures.count, 1)
        XCTAssertEqual(result.catalog, catalog)
    }

    func testStrictThrowsOnFailure() async throws {
        let translator = ClosureTranslator { _ in
            struct DummyError: Error {}
            throw DummyError()
        }

        let engine = CatalogTranslationEngine(translator: translator)
        let catalog = makeSimpleCatalog()

        do {
            _ = try await engine.translateCatalog(catalog, to: .german, mode: .strict)
            XCTFail("Expected strict mode to throw")
        } catch let error as CatalogTranslationEngineError {
            switch error {
            case .strictFailure(let failure):
                XCTAssertEqual(failure.stringKey, "Hello")
            }
        }
    }

    func testTranslatesAllSegmentKindsAndPreservesExistingTargets() async throws {
        let translator = ClosureTranslator { request in
            "de::\(request.text)"
        }

        let engine = CatalogTranslationEngine(translator: translator)
        let catalog = makeComplexCatalog()

        let result = try await engine.translateCatalog(catalog, to: .german, mode: .bestEffort)

        let hello = result.catalog.strings["Hello"]?.localizations?[.german]?.stringUnit?.value
        XCTAssertEqual(hello, "de::Hello")

        let listValues = result.catalog.strings["List"]?.localizations?[.german]?.stringSet?.values
        XCTAssertEqual(listValues?[0], "de::One")
        XCTAssertEqual(listValues?[1], "de::Two")

        let preserved = result.catalog.strings["Already Translated"]?.localizations?[.german]?.stringUnit?.value
        XCTAssertEqual(preserved, "Bereits da")

        let deviceVariation = result.catalog.strings["Variant"]?
            .localizations?[.german]?
            .variations?
            .device?[.iPhone]?
            .stringUnit
            .value
        XCTAssertEqual(deviceVariation, "de::Open")

        let substitutionPlural = result.catalog.strings["Variant"]?
            .localizations?[.german]?
            .substitutions?["count"]?
            .variations?
            .plural?[.one]?
            .stringUnit
            .value
        XCTAssertEqual(substitutionPlural, "de::One file")
    }

    func testSkipsStringUnitWhenTargetTranslationAlreadyExists() async throws {
        let recorder = TranslationRequestRecorder()
        let translator = ClosureTranslator { request in
            await recorder.record(request)
            return "de::\(request.text)"
        }

        let engine = CatalogTranslationEngine(translator: translator)
        let catalog = StringCatalog(
            sourceLanguage: .english,
            strings: [
                "Hello": StringEntry(
                    localizations: [
                        .english: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Hello")),
                        .german: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Hallo"))
                    ]
                )
            ],
            version: "1.0"
        )

        let result = try await engine.translateCatalog(catalog, to: .german, mode: .bestEffort)
        let recordedCount = await recorder.count

        XCTAssertEqual(result.report.stats.attemptedSegments, 0)
        XCTAssertEqual(result.report.stats.translatedSegments, 0)
        XCTAssertEqual(recordedCount, 0)
        XCTAssertEqual(
            result.catalog.strings["Hello"]?.localizations?[.german]?.stringUnit?.value,
            "Hallo"
        )
    }

    func testMatchesTargetLanguageCaseInsensitiveAndDoesNotCreateDuplicateLocalizationKey() async throws {
        let recorder = TranslationRequestRecorder()
        let translator = ClosureTranslator { request in
            await recorder.record(request)
            return "pt::\(request.text)"
        }

        let engine = CatalogTranslationEngine(translator: translator)
        let lowercaseBrazilianPortuguese = LanguageCode(rawValue: "pt-br")
        let catalog = StringCatalog(
            sourceLanguage: .english,
            strings: [
                "Hello": StringEntry(
                    localizations: [
                        .english: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Hello")),
                        .portugueseBrazil: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Olá"))
                    ]
                )
            ],
            version: "1.0"
        )

        let result = try await engine.translateCatalog(catalog, to: lowercaseBrazilianPortuguese, mode: .bestEffort)
        let recordedCount = await recorder.count

        XCTAssertEqual(result.report.stats.attemptedSegments, 0)
        XCTAssertEqual(recordedCount, 0)

        let localizations = try XCTUnwrap(result.catalog.strings["Hello"]?.localizations)
        XCTAssertTrue(localizations.keys.contains(.portugueseBrazil))
        XCTAssertFalse(localizations.keys.contains(lowercaseBrazilianPortuguese))
        XCTAssertEqual(localizations[.portugueseBrazil]?.stringUnit?.value, "Olá")
    }

    func testFilePlanIsDryRunAndApplyWritesChanges() async throws {
        let translator = ClosureTranslator { request in
            "de::\(request.text)"
        }

        let engine = CatalogTranslationEngine(translator: translator)
        let service = CatalogFileTranslationService(engine: engine)

        let tempDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let fileURL = tempDirectory.appending(path: "Sample.xcstrings")
        let original = try String(contentsOf: InputFiles.dipDictSettings)
        try original.write(to: fileURL, atomically: true, encoding: .utf8)

        let plan = try await service.plan(in: [tempDirectory], targetLanguages: [.german], mode: .bestEffort)
        XCTAssertFalse(plan.changes.isEmpty)

        let beforeApply = try String(contentsOf: fileURL)
        XCTAssertEqual(beforeApply, original)

        let applyReport = try service.apply(plan)
        XCTAssertEqual(applyReport.writtenFiles.count, plan.changes.count)

        let afterApply = try String(contentsOf: fileURL)
        XCTAssertNotEqual(afterApply, original)
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

private actor TranslationRequestRecorder {
    private(set) var requests: [TranslationRequest] = []

    func record(_ request: TranslationRequest) {
        requests.append(request)
    }

    var count: Int {
        requests.count
    }
}

private func makeSimpleCatalog() -> StringCatalog {
    StringCatalog(
        sourceLanguage: .english,
        strings: [
            "Hello": StringEntry(
                localizations: [
                    .english: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Hello"))
                ]
            )
        ],
        version: "1.0"
    )
}

private func makeComplexCatalog() -> StringCatalog {
    let variantSourceVariations = StringVariations(
        device: [.iPhone: StringVariation(stringUnit: StringUnit(state: .translated, value: "Open"))],
        plural: nil
    )

    let substitutionVariations = StringVariations(
        device: nil,
        plural: [.one: StringVariation(stringUnit: StringUnit(state: .translated, value: "One file"))]
    )

    return StringCatalog(
        sourceLanguage: .english,
        strings: [
            "Hello": StringEntry(
                localizations: [
                    .english: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Hello"))
                ]
            ),
            "List": StringEntry(
                localizations: [
                    .english: StringLocalization(stringSet: StringSet(state: .translated, values: ["One", "Two"]))
                ]
            ),
            "Already Translated": StringEntry(
                localizations: [
                    .english: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Already")),
                    .german: StringLocalization(stringUnit: StringUnit(state: .translated, value: "Bereits da"))
                ]
            ),
            "Variant": StringEntry(
                localizations: [
                    .english: StringLocalization(
                        substitutions: [
                            "count": StringSubstitution(argNum: 1, formatSpecifier: "%lld", variations: substitutionVariations)
                        ],
                        variations: variantSourceVariations
                    )
                ]
            )
        ],
        version: "1.0"
    )
}

enum InputFiles {
    static var testResourcesDirectory: URL {
        URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("TestResources")
    }

    static var dipDictSettings: URL {
        testResourcesDirectory.appending(path: "DipDictSettings.xcstrings")
    }
}
