// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Audio Convolution Reverb",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AudioConvolutionReverbCore", targets: ["AudioConvolutionReverbCore"]),
        .executable(name: "Audio Convolution Reverb", targets: ["AudioConvolutionReverbApp"]),
        .executable(name: "audio-reverb-swift", targets: ["AudioConvolutionReverbCLI"])
    ],
    targets: [
        .target(
            name: "AudioConvolutionReverbCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "AudioConvolutionReverbApp",
            dependencies: ["AudioConvolutionReverbCore"]
        ),
        .executableTarget(
            name: "AudioConvolutionReverbCLI",
            dependencies: ["AudioConvolutionReverbCore"]
        ),
        .testTarget(
            name: "AudioConvolutionReverbCoreTests",
            dependencies: ["AudioConvolutionReverbCore"],
            path: "tests/AudioConvolutionReverbCoreTests"
        )
    ]
)
