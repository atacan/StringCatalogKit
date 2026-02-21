// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StringCatalogKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "StringCatalog", targets: ["StringCatalog"]),
        .library(name: "CatalogTranslation", targets: ["CatalogTranslation"]),
        .library(name: "CatalogTranslationLLM", targets: ["CatalogTranslationLLM"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "StringCatalog"),
        .target(
            name: "CatalogTranslation",
            dependencies: [
                .StringCatalog,
            ]
        ),
        .target(
            name: "CatalogTranslationLLM",
            dependencies: [
                .CatalogTranslation,
            ]
        ),
        .testTarget(
            name: "StringCatalogTests",
            dependencies: [.StringCatalog],
            resources: [
                .copy("TestResources")
            ]
        ),
        .testTarget(
            name: "CatalogTranslationTests",
            dependencies: [.CatalogTranslation, .StringCatalog],
            resources: [
                .copy("TestResources")
            ]
        ),
    ]
)

extension Target.Dependency {
    static let StringCatalog: Self = "StringCatalog"
    static let CatalogTranslation: Self = "CatalogTranslation"
}
