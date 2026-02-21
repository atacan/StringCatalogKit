// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StringCatalogKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StringCatalog", targets: ["StringCatalog"]),
        .library(name: "StringCatalogTranslator", targets: ["StringCatalogTranslator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.2.1"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.0"),
        //
        .package(path: "../SwiftDeepL"),
        .package(path: "../OpenAIDependency"),
    ],
    targets: [
        .target(name: "StringCatalog"),
        .target(
            name: "StringCatalogTranslator",
            dependencies: [
                .StringCatalog,
                .ConcurrencyExtras,
                .Dependencies,
                .DependenciesMacros,
                .DeepLURLSessionDependency,
                .OpenAIDependency,
            ]
        ),
        .testTarget(
            name: "StringCatalogTranslatorTests",
            dependencies: [.StringCatalogTranslator, .CustomDump],
            resources: [
                .copy("TestResources")
            ]
        ),
        .executableTarget(name: "StringCatalogTranslatorRun",
                          dependencies: [.StringCatalogTranslator]
                         ),
        //
        .executableTarget(
            name: "_Playground",
            dependencies: [
                .StringCatalog,
                .StringCatalogTranslator,
            ]
        ),
    ]
)

extension Target.Dependency {
    static let ConcurrencyExtras: Self = .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras")
    static let StringCatalog: Self = "StringCatalog"
    static let StringCatalogTranslator: Self = "StringCatalogTranslator"
    static let Dependencies = Self.product(name: "Dependencies", package: "swift-dependencies")
    static let DependenciesMacros = Self.product(name: "DependenciesMacros", package: "swift-dependencies")
    static let DeepLURLSessionDependency = Self.product(name: "DeepLURLSessionDependency", package: "SwiftDeepL")
    static let CustomDump = Self.product(name: "CustomDump", package: "swift-custom-dump")
    static let OpenAIDependency = Self.product(name: "OpenAIDependency", package: "OpenAIDependency")
}
