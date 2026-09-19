// swift-tools-version: 5.9
import PackageDescription
import Foundation

let nativeDependency: Package.Dependency = ProcessInfo.processInfo.environment["NUXIE_IOS_SDK_PATH"].map {
  .package(name: "nuxie-ios", path: $0)
} ?? .package(url: "https://github.com/nuxieai/nuxie-ios.git", revision: "48fa51d6591f61d437620abfa06eb7fcb1a64564")

let package = Package(
  name: "nuxie_flutter_native",
  platforms: [
    .iOS(.v15)
  ],
  products: [
    .library(name: "nuxie-flutter-native", targets: ["nuxie_flutter_native"])
  ],
  dependencies: [
    nativeDependency
  ],
  targets: [
    .target(
      name: "nuxie_flutter_native",
      dependencies: [
        .product(name: "Nuxie", package: "nuxie-ios")
      ],
      path: "Sources/nuxie_flutter_native",
      sources: [
        "NuxieBridge.g.swift",
        "NuxieFlutterNativePlugin.swift"
      ]
    )
  ]
)
