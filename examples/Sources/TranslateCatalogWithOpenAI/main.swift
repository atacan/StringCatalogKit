import CatalogTranslation
import CatalogTranslationLLM
import Foundation
import StringCatalog
import UsefulThings

@main
struct TranslateCatalogWithOpenAI {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            printUsage()
            throw ExampleError.invalidArguments
        }

        let inputPath = arguments[1]
        let targetLanguage = LanguageCode(rawValue: arguments[2])
        let model = arguments.count >= 4 ? arguments[3] : "gpt-4.1-mini"

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let inputURL = URL(fileURLWithPath: inputPath, relativeTo: currentDirectory).standardizedFileURL
        let envFileURL = currentDirectory.appendingPathComponent(".env")

        guard let apiKey = getEnvironmentVariable("OPENAI_API_KEY", from: envFileURL), !apiKey.isEmpty else {
            throw ExampleError.missingAPIKey(envFileURL.path)
        }

        let catalog = try StringCatalog(contentsOf: inputURL)
        let openAIClient = OpenAIClient(apiKey: apiKey, model: model)

        let translator = LLMTranslator { _, systemPrompt, userPrompt in
            try await openAIClient.complete(systemPrompt: systemPrompt, userPrompt: userPrompt)
        }

        let engine = CatalogTranslationEngine(translator: translator)
        let result = try await engine.translateCatalog(catalog, to: targetLanguage)

        let outputFileName = "\(inputURL.deletingPathExtension().lastPathComponent).\(targetLanguage.rawValue).translated.xcstrings"
        let outputURL = inputURL.deletingLastPathComponent().appendingPathComponent(outputFileName)
        try result.catalog.encodePrettyToString().write(to: outputURL, atomically: true, encoding: .utf8)

        print("Wrote translated catalog to: \(outputURL.path)")
        print("Stats: attempted=\(result.report.stats.attemptedSegments), translated=\(result.report.stats.translatedSegments), failed=\(result.report.stats.failedSegments), skipped=\(result.report.stats.skippedSegments)")
    }

    private static func printUsage() {
        print("""
        Usage:
          swift run TranslateCatalogWithOpenAI <path-to-xcstrings> <target-language-code> [model]

        Example:
          swift run TranslateCatalogWithOpenAI ../Tests/StringCatalogTests/TestResources/StringSetUntranslated.xcstrings de gpt-4.1-mini
        """)
    }
}

private struct OpenAIClient: Sendable {
    let apiKey: String
    let model: String

    func complete(systemPrompt: String, userPrompt: String) async throws -> String {
        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = ChatCompletionsRequest(
            model: model,
            temperature: 0.2,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExampleError.invalidHTTPResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw ExampleError.openAIStatus(httpResponse.statusCode, responseBody)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw ExampleError.emptyModelResponse
        }
        return content
    }
}

private struct ChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let temperature: Double
    let messages: [Message]
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private enum ExampleError: LocalizedError {
    case invalidArguments
    case missingAPIKey(String)
    case invalidHTTPResponse
    case openAIStatus(Int, String)
    case emptyModelResponse

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Invalid arguments."
        case .missingAPIKey(let envPath):
            return "Missing OPENAI_API_KEY. Add it to process env vars or \(envPath)."
        case .invalidHTTPResponse:
            return "OpenAI request did not return an HTTP response."
        case .openAIStatus(let statusCode, let body):
            return "OpenAI request failed with status \(statusCode): \(body)"
        case .emptyModelResponse:
            return "OpenAI response did not contain a completion."
        }
    }
}
