# Quickstart

Start with the [README](../README.md#your-first-integration). It walks through configuration, events, reactive Features, usage, and billing.

For this source preview, first follow [native setup](native-setup.md). Use matching native sources; the old 0.1 artifacts do not implement this contract.

1. Create an iOS App Platform and an Android App Platform in Nuxie. Copy each public key.
2. Inject `NuxieClient` into your app. Subscribe to activities and App Actions before calling `configure`.
3. Configure once with `NuxieConfiguration(apiKeys: NuxieApiKeys(...))`.
4. Publish a Journey for the same app/environment with an event entry condition.
5. Call `trigger` with that event. Observe native presentation and activity independently.
6. Render access from `features`; use explicit queries for entity scope or remote authority.

The [SDK Lab](../packages/nuxie_flutter/example) lets you exercise this sequence without writing a host app first.
