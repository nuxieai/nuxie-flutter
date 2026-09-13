# Testing

## Fast package checks

In each directory under `packages/` (including `nuxie_flutter/example`), run:

```sh
flutter pub get
flutter analyze
flutter test
```

The core suite verifies startup callback ordering, configuration conflicts and retry, old-session/customer snapshot fencing, fractional last-unit usage semantics, and input validation. Adapter suites verify forwarding and listener disposal. Mapper tests verify the generated transport preserves native results and rejects incomplete required fields. The example widget test verifies its unconfigured starting state.

## Native integration

The Lab’s validation button runs `lib/validation.dart` against the real client. It uses a disposable customer and never retries an ambiguous usage command. To run the same checks under Flutter's integration runner:

```sh
cd packages/nuxie_flutter/example
flutter test integration_test/sdk_test.dart -d <device-id> \
  --dart-define-from-file=/absolute/path/development-public-keys.json
```

Provide NUXIE_IOS_API_KEY, NUXIE_ANDROID_API_KEY, NUXIE_EVENT, and NUXIE_FEATURE. The attended local launcher may additionally set `NUXIE_VALIDATE=true` to run the visible validation action on startup, together with the documented native debug-host loopback override.



Build the SDK Lab for both platforms following [native setup](native-setup.md). Use a development app on the selected backend and inspect command outcomes together with native activities:

1. Configure and verify contract version 2 plus a native version.
2. Inspect anonymous identity, identify a customer, then reset and verify invalidation.
3. Observe unknown becoming ready, including a ready empty map.
4. Query a known Feature remotely and exercise usage with a positive whole-unit amount. Assert the command outcome, not merely a displayed balance.
5. Trigger a published Journey, verify native presentation, and exercise its App Action and dismissal.
6. Restore with the configured billing owner; do not equate a simulator without store purchases with a successful store restore.
7. Shutdown and configure again; ensure the UI sees the new session.

Real StoreKit / Play checkout needs the corresponding sandbox account and configured store products. Mocked channels prove wrapper behavior, not store purchase verification.

## Generated code

From `packages/nuxie_flutter_native`:

```sh
dart run pigeon --input pigeons/nuxie_bridge.dart
```

Commit Dart, Swift, and Kotlin outputs together. Do not hand-edit generated files. Check `git diff --check` before submitting changes.
