# Testing

## Current native pins

iOS `95d76d41eb4cc945cb57e5c1bcd8333ed15d55cc` and Android `4d65783e2eec5b585673041146dff887258d3c93` include
published Apple runtime 0.10.8 and Android runtime 0.4.8, rendered-video visibility,
and interruption recovery fixes. Native source preparation resolved both exact
revisions. All six package analyses and 29 Dart tests passed at these pins.
The canonical check also passed fixture hashes, unchanged Pigeon generation,
the arm64 iOS simulator example build, and Android Debug assembly. Both SwiftPM
lockfiles now resolve the exact iOS pin. The initial readiness run correctly
rejected the changed lockfiles after all checks passed; final readiness and
refreshed device playback remain pending. Results below identify the earlier
revisions they qualified.

## Native pin refresh — September 18, 2026

The preceding qualification used iOS `858321e2e57cc62b6cb978a97834ad068f748c02` and Android
`1514b1cce3d64502b483c41fa551e7290caf10b0`, both pushed development commits.
They include shared decoder admission, hidden-screen media suspension, and the
iOS content-addressed-video format fix. `python3 scripts/check.py` passed all six
package analyses, 29 Dart tests, generated-bridge verification, the arm64 iOS
simulator example build, and the Android build using a task-local
`GRADLE_USER_HOME` configured with installed JDK 17 and 21. Native checkout SHAs
match the pins. The playback-only auto-connect addition subsequently passed
example analysis, its widget test, and the configured iOS build.

The actual Flutter apps acquired the signed development fixture through the
normal SDK profile and verification path on the iOS simulator and API 36 Android
emulator. Each rendered both red and blue phases across 12 screenshot samples.
The first Android probe ran before `screen_shown`; the probe after that event
passed. Each host's independently hashed cached scene and MP4 matched the signed
content-addressed identities. The delivery ledger recorded one MP4 request and
one scene request per host, without additional requests during looping.

Both apps also restarted and visibly played both phases with the fixture
server suspended, then the server was restored. This is origin-unavailability
coverage, not airplane-mode coverage. Android took about 32 seconds from
configuration to `screen_shown`; intermediate capture windows failed before
both phases became visible. Its foreground path waits for profile revalidation,
so prompt offline startup remains unqualified.

Audio, captions, and the remaining failure matrix are separate qualification
requirements. Final readiness/review remain outstanding.

## Fast package checks

In each directory under `packages/` (including `nuxie_flutter/example`), run:

```sh
flutter pub get
flutter analyze
flutter test
```

The core suite verifies startup callback ordering, configuration conflicts and retry, old-session/customer snapshot fencing, fractional last-unit usage semantics, and input validation. Adapter suites verify forwarding and listener disposal. Mapper tests verify the generated transport preserves native results and rejects incomplete required fields. The example widget test verifies its unconfigured starting state.

## Native integration

`python3 scripts/check.py` runs all package checks, verifies generated bridges,
and builds the example for Android and the local Mac's iOS simulator
architecture. It prepares Flutter configuration before invoking Xcode with an
explicit architecture; this avoids Xcode 27's failing multi-architecture
`lipo -verify_arch` invocation. An arm64 simulator build does not establish
x86_64 simulator or physical-device qualification.

For Android, the check restores missing wrapper files from the installed
Flutter SDK cache without replacing the checked-in Gradle distribution pin,
then runs Gradle directly with the host's Java configuration.

The Lab’s validation button runs `lib/validation.dart` against the real client. It uses a disposable customer and never retries an ambiguous usage command. To run the same checks under Flutter's integration runner:

```sh
cd packages/nuxie_flutter/example
flutter test integration_test/sdk_test.dart -d <device-id> \
  --dart-define-from-file=/absolute/path/development-public-keys.json
```

Provide NUXIE_IOS_API_KEY, NUXIE_ANDROID_API_KEY, NUXIE_EVENT, and NUXIE_FEATURE. For playback-only runs, `NUXIE_AUTOCONNECT=true` configures the Lab on startup without running Feature spending checks. The attended local launcher may additionally set `NUXIE_VALIDATE=true` to run the visible validation action on startup, together with the documented native debug-host loopback override.



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

## Attended local validation (September 2026)

Both the iPhone 17 Pro / iOS 26.5 simulator and Android API 36 emulator completed
strict SDK Lab validation against the local authoritative backend with separate
fresh customers. Each customer had 100 credits assigned to entity A, 100 to B,
and 100 unscoped credits. Both runs proved:

- Profile readiness, identify, locale override and clear.
- Consuming A's final 100 credits returns accepted with zero remaining.
- Reusing the operation ID replays the original receipt without another spend.
- An empty A and an unknown entity deny; B retains its 100 credits.
- Cumulative B reports 20 then 25 consume 25 total; a lower 10 report leaves 75.
- Identity reset, shutdown, and reconfiguration complete.

Use `NUXIE_CUSTOMER`, `NUXIE_ENTITY_A`, and `NUXIE_ENTITY_B` Dart defines with
fresh seeded customers to repeat these grant assertions. The validation has no
usage-skip switch. `NUXIE_EVENT` selects an authored event; event invocation alone
does not prove presentation or App Action delivery. Inspect those separately.

The prior attended presentation screenshots remain under `screenshots/`.
Real StoreKit / Play purchase and restore outcomes require their own provider
qualification; the local grant test does not claim that evidence.

## Earlier video delivery candidate — September 18, 2026

The earlier candidate pinned iOS `38428e8bb1c65605d6c982ff22b2a18d63229950` and Android
`e76714a76e14b8f293e782934c107a789d0a67f0`, both pushed development commits
pending final native SDK qualification and review under
[UNIV-3262](https://universe.basis.dev/issue/UNIV-3262).

With Flutter 3.41.4, `python3 scripts/check.py` passed analysis and all 29 tests
across six packages, fixture provenance validation, unchanged Pigeon generation,
the arm64 iOS simulator Debug build on Xcode 27, and the Android Debug APK build
from the pinned source composite. Both checked-in SwiftPM resolutions record
the exact iOS revision. The Android APK passed 16 KiB ZIP-alignment verification.

The initial iOS invocation failed in multi-architecture `lipo` verification;
the local check now explicitly selects the host simulator architecture as
described above. These results establish build integration, not signed-video
playback, cache behavior, captions, or lifecycle qualification through Flutter.
That device coverage remains outstanding, as do final readiness and PR review.
