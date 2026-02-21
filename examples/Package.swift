// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "StringCatalogKitExamples",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TranslateCatalogWithOpenAI",
            targets: ["TranslateCatalogWithOpenAI"]
        )
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/atacan/UsefulThings.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "TranslateCatalogWithOpenAI",
            dependencies: [
                .product(name: "CatalogTranslation", package: "StringCatalogKit"),
                .product(name: "CatalogTranslationLLM", package: "StringCatalogKit"),
                .product(name: "StringCatalog", package: "StringCatalogKit"),
                .product(name: "UsefulThings", package: "UsefulThings")
            ]
        )
    ]
)
