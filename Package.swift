// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RealmOnline",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "RealmOnline",
            path: "Sources/RealmOnline",
            linkerSettings: [
                .linkedFramework("Security"),
            ]
        )
    ]
)
