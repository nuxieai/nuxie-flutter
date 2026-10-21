# Nuxie for Flutter

Native Experiences, typed App Actions, and reactive Feature access for Flutter.

```sh
flutter pub add nuxie_flutter:^1.0.0
```

Use Flutter 3.41+ / Dart 3.11+, iOS 15+, and Android API 23+. Enable Swift Package
Manager in your Flutter application's configuration for iOS.

Start with the [integration guide](https://github.com/nuxieai/nuxie-flutter#your-first-integration).
Use `Nuxie.instance` as your production client and depend on `NuxieClient` in
application code. Native SDKs own Journeys, presentation, and billing. Optional
`nuxie_flutter_bloc` and `nuxie_flutter_riverpod` packages mirror the same Feature
snapshot.

- [API reference](https://github.com/nuxieai/nuxie-flutter/blob/main/docs/api-reference.md)
- [Native setup](https://github.com/nuxieai/nuxie-flutter/blob/main/docs/native-setup.md)
