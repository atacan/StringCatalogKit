import Foundation
import StringCatalog

public struct CatalogFileTranslationService: Sendable {
    private let engine: CatalogTranslationEngine

    public init(engine: CatalogTranslationEngine) {
        self.engine = engine
    }

    public func plan(
        in directories: [URL],
        targetLanguages: [LanguageCode],
        mode: TranslationMode = .bestEffort
    ) async throws -> FileTranslationPlan {
        let files = try Self.stringCatalogFiles(in: directories)

        var items = [FileTranslationPlan.Item]()
        var changes = [PlannedFileChange]()

        for fileURL in files {
            let originalContent = try String(contentsOf: fileURL)
            var catalog = try StringCatalog(contentsOf: fileURL)

            var aggregateStats = TranslationStats()
            var aggregateFailures = [TranslationFailure]()

            for targetLanguage in targetLanguages {
                let result = try await engine.translateCatalog(catalog, to: targetLanguage, mode: mode)
                catalog = result.catalog

                aggregateStats.attemptedSegments += result.report.stats.attemptedSegments
                aggregateStats.translatedSegments += result.report.stats.translatedSegments
                aggregateStats.failedSegments += result.report.stats.failedSegments
                aggregateStats.skippedSegments += result.report.stats.skippedSegments
                aggregateFailures.append(contentsOf: result.report.failures)
            }

            let updatedContent = try catalog.encodePrettyToString()
            let changed = updatedContent != originalContent

            if changed {
                changes.append(
                    PlannedFileChange(
                        fileURL: fileURL,
                        originalContent: originalContent,
                        updatedContent: updatedContent
                    )
                )
            }

            items.append(
                .init(
                    fileURL: fileURL,
                    changed: changed,
                    stats: aggregateStats,
                    failures: aggregateFailures
                )
            )
        }

        return FileTranslationPlan(items: items, changes: changes)
    }

    public func apply(_ plan: FileTranslationPlan) throws -> FileApplyReport {
        var writtenFiles = [URL]()

        for change in plan.changes {
            try change.updatedContent.write(to: change.fileURL, atomically: true, encoding: .utf8)
            writtenFiles.append(change.fileURL)
        }

        return FileApplyReport(writtenFiles: writtenFiles)
    }

    public static func stringCatalogFiles(in directories: [URL]) throws -> [URL] {
        var seen = Set<String>()
        var files = [URL]()

        for directory in directories {
            let discovered = try stringCatalogFiles(in: directory)
            for file in discovered {
                let path = file.path
                if seen.insert(path).inserted {
                    files.append(file)
                }
            }
        }

        return files.sorted(by: { $0.path < $1.path })
    }

    public static func stringCatalogFiles(in directory: URL) throws -> [URL] {
        var files = [URL]()

        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if let isRegularFile = fileAttributes.isRegularFile,
                       isRegularFile,
                       fileURL.lastPathComponent.hasSuffix("xcstrings") {
                        files.append(fileURL)
                    }
                } catch {
                    continue
                }
            }
        }

        return files.sorted(by: { $0.path < $1.path })
    }
}
