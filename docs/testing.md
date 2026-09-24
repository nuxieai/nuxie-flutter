# Testing

## Experience goal and eligibility pins

iOS `170f8cbac97d70034a838d72a79b05e46369d3c9` and Android
`af804278a226282e8e3abdea7c48385901b79638` implement the Experience policy
hard cut: one optional goal, retained conversion measurement, presentation-safe
exits, and offer-specific access checks. Milestone and old policy payloads are
rejected. These commits passed their native SDK gates.

`python3 scripts/check.py` passed at these pins: native source preparation,
six package analyses, 29 Dart tests, fixture hashes, unchanged Pigeon generation,
arm64 iOS simulator host build, and Android Debug assembly. The first attempt
reached Android packaging but exhausted disk space; the complete sequential
retry passed. Log: `/tmp/nuxie-goal-flutter-wrapper-space-retry.txt` in the parent
qualification workspace. `git diff --check` passed. Rendered goal/eligibility
acceptance remains part of the parent implementation qualification; these build
checks alone do not prove that device behavior. No deployment was performed.

## Previous video SDK pin qualification

iOS `1e6970f306a9dac2ed567a239bf0e64a83e2d7cc` and Android
`20f9d42f7d5fe1cba6e2426d63c24499eb966ce7` add obsolete profile-acquisition
cancellation and active system-caption preference refresh. Both accept
distinct video bindings that share immutable media. These native changes have
focused native regressions and device qualification. The PR records wrapper
preparation, resolution, and committed-tree readiness at these exact pins.

The prior wrapper playback and signed-download evidence below remains tied to
its recorded revisions; this pin refresh does not repeat the full device matrix.
Native media-clock timing qualification is separate from wrapper playback and
does not measure external speaker latency.

## Previous native pin qualification

iOS `48fa51d6591f61d437620abfa06eb7fcb1a64564` and Android
`4d65783e2eec5b585673041146dff887258d3c93` include published Apple runtime
0.10.8 and Android runtime 0.4.8, rendered-video visibility, interruption
recovery, and preservation of leased iOS files when signed metadata conflicts
with their verified size. Native preparation resolves both exact revisions.
Both SwiftPM lockfiles resolve the iOS pin. The PR records final committed-tree
readiness for these revisions.

The preceding iOS `95d76d41` / Android `4d65783e` passed the canonical check:
six package analyses, 29 Dart tests, fixture hashes, unchanged Pigeon generation,
arm64 iOS simulator build, and Android Debug assembly. Actual cold apps on the
iOS 26.5 simulator and approved API 36 Android emulator showed repeated red/blue
video phases. Independently hashed cached scene and MP4 bytes matched the signed
inventory. Both restarted and played with the fixture origin suspended. The
Android check waited for the new process's `screen_shown` event before sampling
16 frames with repeated transitions; startup took 71.57 seconds. Earlier
snapshot-based observations were excluded, and an empty adb screenshot caused
one harness failure. The iOS cache-only guard added afterward has its independent
native regression; it does not change playback.

Origin suspension is not airplane-mode qualification. These wrapper checks do
not measure audio synchronization or establish the entire failure/resource
matrix. Evidence is retained in the parent worktree's
`.nuxie/task3b-flutter-final-*` logs, screenshots, sample JSON, and cache hashes.

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
