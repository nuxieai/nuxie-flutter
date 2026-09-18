// swift-tools-version: 5.9
import PackageDescription
import Foundation

let nativeDependency: Package.Dependency = ProcessInfo.processInfo.environment["NUXIE_IOS_SDK_PATH"].map {
  .package(name: "nuxie-ios", path: $0)
} ?? .package(url: "https://github.com/nuxieai/nuxie-ios.git", revision: "95d76d41eb4cc945cb57e5c1bcd8333ed15d55cc")

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
