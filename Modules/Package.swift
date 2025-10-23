// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartTripPlannerModules",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Services", targets: ["Services"]),
        .library(name: "Features", targets: ["Features"]),
        .library(name: "UIComponents", targets: ["UIComponents"]),
        .library(name: "AppShell", targets: ["AppShell"])
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.52.13")
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [],
            path: "Sources/Core",
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint"),
                .plugin(name: "SwiftFormatPlugin", package: "SwiftFormat")
            ]
        ),
        .target(
            name: "Services",
            dependencies: ["Core"],
            path: "Sources/Services",
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint"),
                .plugin(name: "SwiftFormatPlugin", package: "SwiftFormat")
            ]
        ),
        .target(
            name: "UIComponents",
            dependencies: ["Core"],
            path: "Sources/UIComponents",
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint"),
                .plugin(name: "SwiftFormatPlugin", package: "SwiftFormat")
            ]
        ),
        .target(
            name: "Features",
            dependencies: ["Core", "Services", "UIComponents"],
            path: "Sources/Features",
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint"),
                .plugin(name: "SwiftFormatPlugin", package: "SwiftFormat")
            ]
        ),
        .target(
            name: "AppShell",
            dependencies: ["Core", "Services", "Features", "UIComponents"],
            path: "Sources/AppShell",
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint"),
                .plugin(name: "SwiftFormatPlugin", package: "SwiftFormat")
            ]
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"],
            path: "Tests/AppShellTests"
        )
    ]
)
