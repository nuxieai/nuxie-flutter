# Nuxie for Flutter

Native Experiences, typed App Actions, and reactive Feature access for Flutter.

This package contains the **breaking 0.2 source preview**. Start with the
[full integration guide](../../README.md), including configuration, events,
reactive access, billing ownership, and the iOS/Android SDK Lab.

- [Public API reference](../../docs/api-reference.md)
- [Native dependencies and source setup](../../docs/native-setup.md)
- [Run and validate the example](../../docs/testing.md)
- [Release qualification](../../RELEASE_CHECKLIST.md)

Use `Nuxie.instance` as your production client and depend on `NuxieClient` in
application code. Native SDKs own Journeys, presentation, and billing. Optional
Bloc and Riverpod adapters mirror the same immutable Feature snapshot.

This preview is not published. Metered usage and entity-scoped queries need the
coordinated backend fix documented in the integration guide before release.
