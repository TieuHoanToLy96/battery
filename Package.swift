// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatteryMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "BatteryKit",
            linkerSettings: [
                .linkedFramework("IOBluetooth")
            ]
        ),
        .executableTarget(
            name: "battery",
            dependencies: ["BatteryKit"]
        ),
        .testTarget(
            name: "BatteryKitTests",
            dependencies: ["BatteryKit"],
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
