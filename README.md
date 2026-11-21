# StringCatalogKit

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fatacan%2FStringCatalogKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/atacan/StringCatalogKit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fatacan%2FStringCatalogKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/atacan/StringCatalogKit)

`StringCatalogKit` provides model types for `.xcstrings` files and a provider-agnostic translation engine.

## Products

- `StringCatalog`: Codable model types for Xcode string catalogs.
- `CatalogTranslation`: Translation engine + file planning/apply API.
- `CatalogTranslationLLM`: LLM adapter with customizable prompt templates.

## Quick Start

```swift
import CatalogTranslation
import StringCatalog

struct MyTranslator: CatalogTextTranslator {
    func translate(_ request: TranslationRequest) async throws -> String {
        // Your API call here (OpenAI, DeepL, custom service...)
        return "translated: \(request.text)"
    }
}

let translator = MyTranslator()
let engine = CatalogTranslationEngine(translator: translator)

let catalog = try StringCatalog(contentsOf: URL(fileURLWithPath: "/path/Localizable.xcstrings"))
let result = try await engine.translateCatalog(catalog, to: .german)

print(result.report.stats)
```

## Durable Runs

Long runs can save progress and stop early when retrying is pointless:

```swift
let engine = CatalogTranslationEngine(
    translator: translator,
    options: TranslationOptions(
        maxConcurrentRequests: 4,
        maxConsecutiveFailures: 10,  // stop after 10 failures in a row (nil = never)
        checkpointPolicy: TranslationCheckpointPolicy(everySegments: 25, interval: 5)
    )
)

let result = try await engine.translateCatalog(catalog, to: .german) { partial in
    // Every segment translated so far is applied to partial.catalog.
    try partial.catalog.encodePrettyToString().write(to: outputURL, atomically: true, encoding: .utf8)
}

if let abort = result.report.abort {
    print("Stopped early: \(abort.reason); \(result.report.stats.skippedSegments) segments not attempted")
}
```

- The checkpoint handler runs on the collecting task. If it throws, the run stops and the error is rethrown.
- A translator can throw `CatalogTranslationAbort(reason:)` for errors that will fail every segment, such as bad credentials or exhausted quota. In best-effort mode the engine records that failure, starts no new requests, cancels in-flight ones, and returns everything translated so far, with `report.abort` set.
- `report.translatedRequests` lists the segments applied to the result's catalog. A segment that is neither translated nor failed was skipped.
- A new request starts only after the previous outcome has been processed, so an abort never lets extra requests through.

## File Workflow

```swift
let service = CatalogFileTranslationService(engine: engine)
let plan = try await service.plan(
    in: [URL(fileURLWithPath: "/path/to/project")],
    targetLanguages: [.german, .french]
)

// Dry run first:
print(plan.items.filter(\.changed).count)

// Explicitly apply:
let applyReport = try service.apply(plan)
print(applyReport.writtenFiles)
```

## LLM Usage

`CatalogTranslationLLM` provides `LLMTranslator`, which adapts system/user prompts to any model provider:

```swift
import CatalogTranslation
import CatalogTranslationLLM

let translator = LLMTranslator { _, systemPrompt, userPrompt in
    // Call your LLM API here and return translated text.
    try await myLLMClient.complete(system: systemPrompt, user: userPrompt)
}

let engine = CatalogTranslationEngine(translator: translator)
```

For a full runnable example with OpenAI integration, see:
- `examples/README.md`
- `examples/Sources/TranslateCatalogWithOpenAI/main.swift`
