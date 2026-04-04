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
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("Security"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/RealmOnline/Info.plist",
                ]),
            ]
        )
    ]
)
