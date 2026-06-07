// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TransactApp",
    defaultLocalization: "es",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TransactApp", targets: ["TransactApp"]),
        .library(name: "Models", targets: ["Models"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Database", targets: ["Database"]),
        .library(name: "Services", targets: ["Services"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "Models",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "DesignSystem",
            dependencies: ["Models"]
        ),
        .target(
            name: "Database",
            dependencies: [
                "Models",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .target(
            name: "Services",
            dependencies: [
                "Models",
                "Database",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .executableTarget(
            name: "TransactApp",
            dependencies: [
                "Models",
                "DesignSystem",
                "Database",
                "Services"
            ]
        ),
        .testTarget(
            name: "TransactAppTests",
            dependencies: [
                "TransactApp",
                "Models",
                "DesignSystem",
                "Database",
                "Services"
            ]
        ),
        .executableTarget(
            name: "Seeder",
            dependencies: [
                "Models",
                "Database",
                "Services",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/Seeder"
        )
    ],
    swiftLanguageModes: [.v6]
)
