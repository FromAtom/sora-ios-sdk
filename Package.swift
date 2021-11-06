// swift-tools-version:5.3

import PackageDescription
import Foundation

let file = "WebRTC-95.4638.3.0/WebRTC.xcframework.zip"

let package = Package(
    name: "Sora",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "Sora", targets: ["Sora"])
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", .exact("4.0.4")),
        .package(url: "https://github.com/stasel/WebRTC.git", .upToNextMajor(from: "95.0.0"))
    ],
    targets: [
        .target(
            name: "Sora",
            dependencies: ["WebRTC", "Starscream"],
            path: "Sora",
            exclude: ["Info.plist"],
            resources: [.process("Sora/VideoView.xib")])
    ]
)
