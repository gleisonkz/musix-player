// swift-tools-version: 5.10
import PackageDescription

var products: [Product] = [.library(name: "MusixCore", targets: ["MusixCore"])]
var targets: [Target] = [
    .target(name: "MusixCore"),
    .testTarget(name: "MusixCoreTests", dependencies: ["MusixCore"]),
]

// AVFoundation only exists on Apple platforms; on Windows/Linux only the pure core builds.
#if os(macOS)
products.append(.library(name: "MusixAudio", targets: ["MusixAudio"]))
targets += [
    .target(name: "MusixAudio", dependencies: ["MusixCore"]),
    .testTarget(name: "MusixAudioTests", dependencies: ["MusixAudio"]),
]
#endif

let package = Package(
    name: "MusixCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: products,
    targets: targets
)
