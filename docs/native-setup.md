# Native setup

Install `nuxie_flutter: ^1.0.0` from pub.dev. The native plugin resolves the
released iOS SDK through SwiftPM and Android SDK 1.0.0 through Maven Central.

## Repository development

`pubspec_overrides.yaml` files select sibling packages when working in this
repository. They are excluded from published packages. Run
`python3 scripts/prepare-native.py` for the pinned native bridge products used
by Bazel checks. The example applications independently resolve the published
native SDK dependencies.

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

Use API 23+ devices, compile SDK 36, Java 21 and the Android SDK. The example uses `FlutterFragmentActivity` so the native SDK can present Experiences. Set `ANDROID_HOME` if your SDK is not automatically discovered.

The plugin and example resolve `ai.nuxie:nuxie-android:1.0.0` from Maven Central.
No repository checkout or native compilation is required by Flutter consumers.

```sh
cd packages/nuxie_flutter/example
flutter build apk --debug
```

## Local backend validation

The SDK Lab uses the development environment. Its debug native hosts also support loopback-only endpoint overrides: iOS reads `NUXIE_LOCAL_INGEST_URL` from the process environment; Android reads the `nuxieLocalIngestUrl` launch intent extra. Android emulator host access uses `10.0.2.2`. These hooks are debug host configuration and are not public Dart configuration.

Use public keys for apps created in that local backend. Publish a Journey for the app/environment before expecting a trigger to present anything. The production wrapper does not expose testing SPI or endpoint overrides.
