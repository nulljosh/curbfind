// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "curbside-tui",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/rensbreur/SwiftTUI", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "curbside-tui",
            dependencies: ["SwiftTUI"],
            path: ".",
            sources: ["Sources/Models/CraigslistAPI.swift", "Sources/Models/Listing.swift", "tui/main.swift"]
        )
    ]
)
