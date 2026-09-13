# Release qualification

This branch is a source preview. `publish_to: none` remains intentional.

- Run `python3 scripts/check.py` on macOS: it verifies native pins and fixtures, checks every Dart package, verifies Pigeon regeneration, and builds both native examples.
- Run the real-device integration test with development app keys and a published Journey. Record backend, simulator/emulator versions, native commits, and exact results separately from mocked-channel coverage.
- Verify native and external billing with the configured store/provider sandbox before claiming purchase qualification. Preserve offer selection, Apple eligibility JWS, and all typed outcomes.
- Publish qualified native registry artifacts, update `NATIVE-PINS.json` and dependency declarations together, and verify a clean consumer can acquire them before enabling pub.dev publication.
- Review exported API docs and package README. Remove source-preview installation directions only when registry installation is proven.
- Open the native and wrapper PRs in their owning repositories. Record parent pointer updates separately.
