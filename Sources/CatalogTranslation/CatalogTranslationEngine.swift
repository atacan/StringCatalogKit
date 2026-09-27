import Foundation
import StringCatalog

public struct CatalogTranslationEngine: Sendable {
    private let options: TranslationOptions
    private let translateClosure: @Sendable (TranslationRequest) async throws -> String

    public init(translator: any CatalogTextTranslator, options: TranslationOptions = .default) {
        self.options = options
        self.translateClosure = { request in
            try await translator.translate(request)
        }
    }

    public func translateCatalog(
        _ catalog: StringCatalog,
        to targetLanguage: LanguageCode,
        mode: TranslationMode = .bestEffort
    ) async throws -> CatalogTranslationResult {
        let jobs = buildJobs(for: catalog, targetLanguage: targetLanguage)
        var stats = TranslationStats(attemptedSegments: jobs.count)
        var failures = [TranslationFailure]()
        var successfulTranslations = [(job: Job, translatedText: String)]()

        // `withThrowingTaskGroup` can start all jobs at once. This semaphore enforces the
        // user-configured cap on in-flight translation requests (API rate limits / resource use).
        let semaphore = AsyncSemaphore(value: options.maxConcurrentRequests)

        do {
            try await withThrowingTaskGroup(of: JobOutcome.self) { group in
                for job in jobs {
                    group.addTask {
                        await semaphore.wait()

                        do {
                            let translatedText = try await translateClosure(job.request)
                            await semaphore.signal()
                            return .success(job: job, translatedText: translatedText)
                        } catch {
                            await semaphore.signal()
                            let failure = TranslationFailure(
                                stringKey: job.request.stringKey,
                                segment: job.request.segment,
                                sourceLanguage: job.request.sourceLanguage,
                                targetLanguage: job.request.targetLanguage,
                                reason: String(describing: error)
                            )

                            if mode == .strict {
                                throw StrictModeError.failure(failure)
                            }

                            return .failure(failure)
                        }
                    }
                }

                while let outcome = try await group.next() {
                    switch outcome {
                    case .success(let job, let translatedText):
                        successfulTranslations.append((job: job, translatedText: translatedText))
                    case .failure(let failure):
                        failures.append(failure)
                    }
                }
            }
        } catch let strictError as StrictModeError {
            switch strictError {
            case .failure(let failure):
                throw CatalogTranslationEngineError.strictFailure(failure)
            }
        }

        var translatedCatalog = catalog

        for translation in successfulTranslations {
            let sourceLocalization = catalog.strings[translation.job.request.stringKey]?.localizations?[catalog.sourceLanguage]

            apply(
                translatedText: translation.translatedText,
                segment: translation.job.internalSegment,
                stringKey: translation.job.request.stringKey,
                sourceLocalization: sourceLocalization,
                targetLanguage: targetLanguage,
                to: &translatedCatalog
            )
            stats.translatedSegments += 1
        }

        stats.failedSegments = failures.count
        stats.skippedSegments = max(0, stats.attemptedSegments - stats.translatedSegments - stats.failedSegments)

        return CatalogTranslationResult(
            catalog: translatedCatalog,
            report: TranslationReport(stats: stats, failures: failures)
        )
    }
}

private extension CatalogTranslationEngine {
    struct Job: Sendable {
        let request: TranslationRequest
        let internalSegment: InternalSegment
    }

    enum InternalSegment: Sendable {
        case stringUnit
        case stringSet(index: Int, sourceCount: Int)
        case variation(InternalVariationPath)
    }

    enum InternalVariationPath: Sendable {
        case localizationDevice(StringVariations.DeviceKey)
        case localizationPlural(StringVariations.PluralKey)
        case substitutionDevice(substitutionKey: String, deviceKey: StringVariations.DeviceKey)
        case substitutionPlural(substitutionKey: String, pluralKey: StringVariations.PluralKey)

        var publicPath: String {
            switch self {
            case .localizationDevice(let deviceKey):
                return "variations.device.\(deviceKey.rawValue)"
            case .localizationPlural(let pluralKey):
                return "variations.plural.\(pluralKey.rawValue)"
            case .substitutionDevice(let substitutionKey, let deviceKey):
                return "substitutions.\(substitutionKey).variations.device.\(deviceKey.rawValue)"
            case .substitutionPlural(let substitutionKey, let pluralKey):
                return "substitutions.\(substitutionKey).variations.plural.\(pluralKey.rawValue)"
            }
        }
    }

    enum JobOutcome: Sendable {
        case success(job: Job, translatedText: String)
        case failure(TranslationFailure)
    }

    enum StrictModeError: Error {
        case failure(TranslationFailure)
    }

    func buildJobs(for catalog: StringCatalog, targetLanguage: LanguageCode) -> [Job] {
        var jobs = [Job]()
        let sourceLanguage = catalog.sourceLanguage

        for (stringKey, stringEntry) in catalog.strings {
            guard stringEntry.shouldTranslate != false else {
                continue
            }

            let sourceLocalization = stringEntry.localizations?[sourceLanguage]
            let targetLocalization = localizedValue(for: targetLanguage, in: stringEntry.localizations)

            if targetLocalization?.stringUnit == nil {
                let text = sourceLocalization?.stringUnit?.value ?? stringKey
                if !text.isEmpty {
                    let request = TranslationRequest(
                        text: text,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        stringKey: stringKey,
                        developerComment: stringEntry.comment,
                        segment: .stringUnit
                    )

                    jobs.append(Job(request: request, internalSegment: .stringUnit))
                }
            }

            if let sourceStringSet = sourceLocalization?.stringSet {
                for (index, value) in sourceStringSet.values.enumerated() {
                    if value.isEmpty {
                        continue
                    }

                    if let targetValues = targetLocalization?.stringSet?.values,
                       targetValues.indices.contains(index),
                       !targetValues[index].isEmpty {
                        continue
                    }

                    let request = TranslationRequest(
                        text: value,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        stringKey: stringKey,
                        developerComment: stringEntry.comment,
                        segment: .stringSet(index: index)
                    )

                    jobs.append(
                        Job(
                            request: request,
                            internalSegment: .stringSet(index: index, sourceCount: sourceStringSet.values.count)
                        )
                    )
                }
            }

            if let sourceVariations = sourceLocalization?.variations {
                appendVariationJobs(
                    sourceVariations: sourceVariations,
                    targetVariations: targetLocalization?.variations,
                    stringKey: stringKey,
                    comment: stringEntry.comment,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    destination: &jobs
                )
            }

            if let sourceSubstitutions = sourceLocalization?.substitutions {
                for (substitutionKey, sourceSubstitution) in sourceSubstitutions {
                    guard let sourceVariations = sourceSubstitution.variations else {
                        continue
                    }

                    let targetVariations = targetLocalization?.substitutions?[substitutionKey]?.variations

                    appendVariationJobs(
                        sourceVariations: sourceVariations,
                        targetVariations: targetVariations,
                        stringKey: stringKey,
                        comment: stringEntry.comment,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        substitutionKey: substitutionKey,
                        destination: &jobs
                    )
                }
            }
        }

        return jobs
    }

    func appendVariationJobs(
        sourceVariations: StringVariations,
        targetVariations: StringVariations?,
        stringKey: String,
        comment: String?,
        sourceLanguage: LanguageCode,
        targetLanguage: LanguageCode,
        substitutionKey: String? = nil,
        destination: inout [Job]
    ) {
        for (deviceKey, variation) in sourceVariations.device ?? [:] {
            let text = variation.stringUnit.value
            if text.isEmpty {
                continue
            }

            let targetValue = targetVariations?.device?[deviceKey]?.stringUnit.value
            if let targetValue, !targetValue.isEmpty {
                continue
            }

            let internalPath: InternalVariationPath = if let substitutionKey {
                .substitutionDevice(substitutionKey: substitutionKey, deviceKey: deviceKey)
            } else {
                .localizationDevice(deviceKey)
            }

            destination.append(
                Job(
                    request: TranslationRequest(
                        text: text,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        stringKey: stringKey,
                        developerComment: comment,
                        segment: .variation(path: internalPath.publicPath)
                    ),
                    internalSegment: .variation(internalPath)
                )
            )
        }

        for (pluralKey, variation) in sourceVariations.plural ?? [:] {
            let text = variation.stringUnit.value
            if text.isEmpty {
                continue
            }

            let targetValue = targetVariations?.plural?[pluralKey]?.stringUnit.value
            if let targetValue, !targetValue.isEmpty {
                continue
            }

            let internalPath: InternalVariationPath = if let substitutionKey {
                .substitutionPlural(substitutionKey: substitutionKey, pluralKey: pluralKey)
            } else {
                .localizationPlural(pluralKey)
            }

            destination.append(
                Job(
                    request: TranslationRequest(
                        text: text,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        stringKey: stringKey,
                        developerComment: comment,
                        segment: .variation(path: internalPath.publicPath)
                    ),
                    internalSegment: .variation(internalPath)
                )
            )
        }
    }

    func apply(
        translatedText: String,
        segment: InternalSegment,
        stringKey: String,
        sourceLocalization: StringLocalization?,
        targetLanguage: LanguageCode,
        to catalog: inout StringCatalog
    ) {
        guard var entry = catalog.strings[stringKey] else {
            return
        }

        var localizations = entry.localizations ?? [:]
        let targetLocalizationKey = canonicalLocalizationKey(for: targetLanguage, in: localizations) ?? targetLanguage
        var targetLocalization = localizations[targetLocalizationKey] ?? StringLocalization()

        switch segment {
        case .stringUnit:
            targetLocalization.stringUnit = StringUnit(state: .translated, value: translatedText)

        case .stringSet(let index, let sourceCount):
            var stringSet = targetLocalization.stringSet
            if stringSet == nil {
                var values = Array(repeating: "", count: sourceCount)
                if let sourceValues = sourceLocalization?.stringSet?.values {
                    for i in 0..<min(values.count, sourceValues.count) {
                        values[i] = sourceValues[i]
                    }
                }

                stringSet = StringSet(state: .translated, values: values)
            }

            if let currentCount = stringSet?.values.count, currentCount < sourceCount {
                stringSet?.values.append(contentsOf: Array(repeating: "", count: sourceCount - currentCount))
            }

            if stringSet?.values.indices.contains(index) == true {
                stringSet?.values[index] = translatedText
            }
            stringSet?.state = .translated
            targetLocalization.stringSet = stringSet

        case .variation(let path):
            applyVariation(
                translatedText: translatedText,
                path: path,
                sourceLocalization: sourceLocalization,
                targetLocalization: &targetLocalization
            )
        }

        localizations[targetLocalizationKey] = targetLocalization
        entry.localizations = localizations
        catalog.strings[stringKey] = entry
    }

    func localizedValue(
        for language: LanguageCode,
        in localizations: [LanguageCode: StringLocalization]?
    ) -> StringLocalization? {
        guard let localizations else {
            return nil
        }

        return localizations[language] ?? localizations[canonicalLocalizationKey(for: language, in: localizations) ?? language]
    }

    func canonicalLocalizationKey(
        for language: LanguageCode,
        in localizations: [LanguageCode: StringLocalization]
    ) -> LanguageCode? {
        localizations.keys.first { localizedKey in
            languageCodesMatch(localizedKey, language)
        }
    }

    func languageCodesMatch(_ lhs: LanguageCode, _ rhs: LanguageCode) -> Bool {
        lhs.rawValue.caseInsensitiveCompare(rhs.rawValue) == .orderedSame
    }

    func applyVariation(
        translatedText: String,
        path: InternalVariationPath,
        sourceLocalization: StringLocalization?,
        targetLocalization: inout StringLocalization
    ) {
        switch path {
        case .localizationDevice(let deviceKey):
            var variations = targetLocalization.variations ?? StringVariations()
            var device = variations.device?.wrappedValue ?? [:]
            device[deviceKey.rawValue] = StringVariation(stringUnit: .init(state: .translated, value: translatedText))
            variations.device = DictionaryWrapper(wrappedValue: device)
            targetLocalization.variations = variations

        case .localizationPlural(let pluralKey):
            var variations = targetLocalization.variations ?? StringVariations()
            var plural = variations.plural?.wrappedValue ?? [:]
            plural[pluralKey.rawValue] = StringVariation(stringUnit: .init(state: .translated, value: translatedText))
            variations.plural = DictionaryWrapper(wrappedValue: plural)
            targetLocalization.variations = variations

        case .substitutionDevice(let substitutionKey, let deviceKey):
            var substitutions = targetLocalization.substitutions ?? [:]
            let sourceSubstitution = sourceLocalization?.substitutions?[substitutionKey]
            var substitution = substitutions[substitutionKey] ?? sourceSubstitution ?? StringSubstitution(argNum: 0, formatSpecifier: "")
            var variations = substitution.variations ?? StringVariations()
            var device = variations.device?.wrappedValue ?? [:]
            device[deviceKey.rawValue] = StringVariation(stringUnit: .init(state: .translated, value: translatedText))
            variations.device = DictionaryWrapper(wrappedValue: device)
            substitution.variations = variations
            substitutions[substitutionKey] = substitution
            targetLocalization.substitutions = substitutions

        case .substitutionPlural(let substitutionKey, let pluralKey):
            var substitutions = targetLocalization.substitutions ?? [:]
            let sourceSubstitution = sourceLocalization?.substitutions?[substitutionKey]
            var substitution = substitutions[substitutionKey] ?? sourceSubstitution ?? StringSubstitution(argNum: 0, formatSpecifier: "")
            var variations = substitution.variations ?? StringVariations()
            var plural = variations.plural?.wrappedValue ?? [:]
            plural[pluralKey.rawValue] = StringVariation(stringUnit: .init(state: .translated, value: translatedText))
            variations.plural = DictionaryWrapper(wrappedValue: plural)
            substitution.variations = variations
            substitutions[substitutionKey] = substitution
            targetLocalization.substitutions = substitutions
        }
    }
}

// Actor-backed semaphore used to safely coordinate permits across many child tasks.
// This is only for throttling concurrent translation requests.
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = max(1, value)
    }

    func wait() async {
        if value > 0 {
            value -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}
