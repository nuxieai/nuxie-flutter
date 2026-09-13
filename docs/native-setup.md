# Native setup

This 0.2 source preview requires matching native source changes for coherent Feature snapshots and public restore results. Old 0.1 native artifacts are incompatible. Package publication is disabled until native dependency qualification is complete.

## Acquire the pinned sources

From the Flutter repository root, run `python3 scripts/prepare-native.py`. This fetches and verifies both immutable revisions in `NATIVE-PINS.json`; it refuses to overwrite a modified checkout. The Android example resolves `.native/android` automatically. iOS resolves the pinned Git revision through SwiftPM.

## iOS

Use Flutter 3.41+, iOS 15+, Xcode with the matching iOS SDK, and Swift Package Manager. Enable SwiftPM in your application's pubspec:

```yaml
flutter:
  config:
    enable-swift-package-manager: true
```

The Flutter plugin exposes a Swift package; CocoaPods is not a supported integration path. The example includes Flutter's generated SwiftPM integration and UIScene host.

For a local source checkout, set `NUXIE_IOS_SDK_PATH` to the matching nuxie-ios repository. Prepare that repository's runtime using its documented `make fetch-runtime-xcframework`, then build with `NUXIE_RUNTIME_USE_LOCAL=1`.

```sh
cd packages/nuxie_flutter/example
NUXIE_IOS_SDK_PATH=/absolute/path/nuxie-ios NUXIE_RUNTIME_USE_LOCAL=1 \
  flutter build ios --simulator --debug
```

## Android

Use API 23+ devices, compile SDK 36, Java 17+ and the Android SDK. The example uses `FlutterFragmentActivity` so the native SDK can present Experiences. Set `ANDROID_HOME` if your SDK is not automatically discovered.

For local native source validation, the example's Gradle settings substitute the native dependency with a composite build when `NUXIE_ANDROID_SDK_PATH` points to the matching repository:

```sh
cd packages/nuxie_flutter/example
NUXIE_ANDROID_SDK_PATH=/absolute/path/nuxie-android flutter build apk --debug
```

Keep the example's AGP and Kotlin versions aligned with the native composite build. The `0.2.0-source` coordinate is deliberately substituted by the pinned source checkout; it is not a Maven release. For another host app, copy the example’s `includeBuild` dependency-substitution block into its settings and point it at the prepared Android checkout. Registry publication requires a qualified native artifact.

## Local backend validation

The SDK Lab uses the development environment. Its debug native hosts also support loopback-only endpoint overrides: iOS reads `NUXIE_LOCAL_INGEST_URL` from the process environment; Android reads the `nuxieLocalIngestUrl` launch intent extra. Android emulator host access uses `10.0.2.2`. These hooks are debug host configuration and are not public Dart configuration.

Use public keys for apps created in that local backend. Publish a Journey for the app/environment before expecting a trigger to present anything. The production wrapper does not expose testing SPI or endpoint overrides.
