// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenshotRouter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ScreenshotRouter"),
        .testTarget(
            name: "ScreenshotRouterTests",
            dependencies: ["ScreenshotRouter"],
            swiftSettings: [.unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])],
            linkerSettings: [.unsafeFlags([
                "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
            ])]
        )
    ]
)
