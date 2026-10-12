# Bazel SDK builds

Use `python3 scripts/bazel/sdk.py build|test|analyze|check` for the Dart package
graph. All six package/test workspaces use Flutter3.41.4, checksum-pinned by
`rules_flutter` at the commit in `MODULE.bazel`. Hosted dependency versions come from each package's `pub_deps.json`; archive
checksums are recorded in `scripts/bazel/pub-archives.json` from the owning
Flutter lockfiles. A small patch to the pinned rules verifies those checksums
on download, handles inline comments in hosted package versions, and relocates
declared sibling package paths inside private build/test workspaces. Dart
builds and tests do not require an Android SDK. Path dependencies remain direct
Bazel edges. To refresh dependencies
intentionally, run Flutter3.41.4's `pub get` and `pub deps --json` in the affected
package, regenerate its report, then run `python3 scripts/bazel/update-pub-archives.py`.
Review the archive lock, BUILD dependency edges and MODULE imports together.

`python3 scripts/bazel/sdk.py build-native` prepares the exact NATIVE-PINS.json
revisions through their native Bazel producers, then compiles the generated
Pigeon/owned Swift and Kotlin plugin sources. They import the prepared native
SDK products and the same Flutter SDK's engine interfaces. Prepared products
stay under this checkout's `.native/artifacts/`. Set absolute
`NUXIE_IOS_ARTIFACTS`/`NUXIE_ANDROID_ARTIFACTS` to reuse already-prepared products;
their revision, inventory, hashes and platform are verified before compilation.

`python3 scripts/check.py` retains fixture hashes, Pigeon regeneration checks,
and real iOS/Android example application builds as independent consumer
compatibility checks. Buildkite invokes the same Bazel package and native bridge
frontends used locally. Bazel9.3.0 is pinned by `.bazelversion`; the launcher has
a checksummed standalone Bazelisk fallback.

The SDK, nuxie-runtime and the other SDKs share reusable action, download and
repository-content caches under `~/.cache/nuxie/bazel`. An absolute
`NUXIE_BAZEL_CACHE_DIR` relocates these three caches. Buildkite sources
`ci-cache.sh` to use the root/runtime per-agent cache under
`~/.nuxie-ci/editor-cargo-target/<agent>/bazel-shared-cache`.

Each checkout gets its own Bazel output base. A shared
`NUXIE_BAZEL_OUTPUT_USER_ROOT` contains separate bases; do not set the same
`--output_base` for different worktrees. Generated Dart workspaces, native
products and test scratch files stay isolated. Set `NUXIE_BAZEL_JOBS=2` to bound
local compiler concurrency.

Run the receipt, source-preservation and cache frontend oracles with:

```sh
python3 -B -m unittest discover -s scripts/bazel -p 'test_*.py'
```

When reusing separate iOS preparations, set absolute
`NUXIE_IOS_DEBUG_ARTIFACTS` and `NUXIE_IOS_RELEASE_ARTIFACTS` paths to their
original producer manifests or directories. Preparation selects the requested
configuration and falls back to `NUXIE_IOS_ARTIFACTS` when its specific override
is unset. Each selected receipt must match the native pin, configuration and
verified artifact inventory. An invalid explicit override fails without
falling back to a different preparation.

Readiness defaults to both native platforms. Select `--platform portable`,
`--platform android` or `--platform ios` with the owning check command or
`scripts/bazel/sdk.py build-native` to run an explicit seam. Apple selection
requires macOS and a Debug simulator receipt for the host architecture; Android
and portable selections never prepare Apple products. The CI graph, admitted
resource boundary, exact receipts and separate cache-read activation gates are
documented in [SDK confidence lanes](../../docs/ci-runner-lanes.md).
