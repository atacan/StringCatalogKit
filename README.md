# StringCatalogKit

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