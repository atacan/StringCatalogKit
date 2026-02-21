# StringCatalogKit OpenAI Example

This is a standalone executable Swift package that:

- depends on `StringCatalogKit` via a local relative path (`..`)
- uses `CatalogTranslationLLM.LLMTranslator` with default prompts
- makes a minimal `URLSession` request to OpenAI
- reads `OPENAI_API_KEY` from `.env` using `UsefulThings.getEnvironmentVariable`

## Setup

1. Create a `.env` file in this folder:

```dotenv
OPENAI_API_KEY=your_api_key_here
```

2. Build and run:

```bash
cd examples
swift run TranslateCatalogWithOpenAI <path-to-xcstrings> <target-language-code> [model]
```

Example:

```bash
swift run TranslateCatalogWithOpenAI ../Tests/StringCatalogTests/TestResources/StringSetUntranslated.xcstrings de gpt-4.1-mini
```

The executable writes:

`<input-file-name>.<target-language>.translated.xcstrings`

next to the input file.
