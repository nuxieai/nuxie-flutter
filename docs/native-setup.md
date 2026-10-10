# Native setup

This 0.2 source preview requires matching native source changes for coherent Feature snapshots and public restore results. Old 0.1 native artifacts are incompatible. Package publication is disabled until native dependency qualification is complete.

## Acquire the pinned sources

From the Flutter repository root, run `python3 scripts/prepare-native.py`. This fetches and verifies both immutable revisions in `NATIVE-PINS.json`; it refuses to overwrite a modified checkout. Bazel prepares the native bridge products under `.native/artifacts`. The Android example consumes that source-addressed AAR and its dependency POM. iOS resolves the pinned Git revision through SwiftPM for its independent consumer check.

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

For local native validation, prepare the pinned Bazel products before building the example:

```sh
python3 scripts/prepare-native.py --platform android
cd packages/nuxie_flutter/example
flutter build apk --debug
```

The source preview resolves `ai.nuxie:nuxie-android:0.2.0-<revision>` from the checkout's prepared Maven directory. `NUXIE_ANDROID_ARTIFACTS` can select an absolute product directory or its `sdk-artifacts.json`; the receipt must match `NATIVE-PINS.json`. The AAR contains the Bazel-built SDK and native runtime, and its POM supplies the transitive dependencies. Registry publication requires a qualified native artifact.

## Local backend validation

The SDK Lab uses the development environment. Its debug native hosts also support loopback-only endpoint overrides: iOS reads `NUXIE_LOCAL_INGEST_URL` from the process environment; Android reads the `nuxieLocalIngestUrl` launch intent extra. Android emulator host access uses `10.0.2.2`. These hooks are debug host configuration and are not public Dart configuration.

Use public keys for apps created in that local backend. Publish a Journey for the app/environment before expecting a trigger to present anything. The production wrapper does not expose testing SPI or endpoint overrides.
