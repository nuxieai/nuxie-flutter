# API reference

Import `package:nuxie_flutter/nuxie_flutter.dart`. Depend on `NuxieClient` in your application; use `Nuxie.instance` as its production implementation.

## Lifecycle and configuration

| Member | Contract |
| --- | --- |
| `configure(NuxieConfiguration)` | Configures the native SDK. Equivalent concurrent calls share setup. A different configuration fails until shutdown. |
| `isConfigured` | True only after setup and contract validation succeed. |
| `versions` | Wrapper version plus native version and bridge contract after setup. |
| `shutdown()` | Tears down the connection, settles pending native controller requests, and returns Features to unknown. Await before configuring again. |

Configuration contains platform public keys, environment (`production` by default), log level (`warning`), optional locale, and billing (`NuxieBilling.native()` by default). External billing accepts one `NuxiePurchaseController`. Observer handling is a native billing option.

## Customer and locale

| Method | Parameters / behavior |
| --- | --- |
| `identify(distinctId)` | Optional JSON `userProperties` and `userPropertiesSetOnce`. |
| `reset(keepAnonymousId: false)` | Clears identified customer state; rotates anonymous identity by default. |
| `getDistinctId()` / `getAnonymousId()` | Current native identity strings. |
| `getIsIdentified()` | Whether the native customer is identified. |
| `setLocaleIdentifier(String?)` | Locale override; null restores native default behavior. |

## Journeys and observation

`trigger(event, properties: ...)` returns `Future<void>` after invoking native capture. It is not a presentation or access result. Event names must be nonempty and cannot start with `$`, which is reserved for internal events. Properties must be finite JSON values; cyclic objects are rejected.

`dismiss()` requests native dismissal.

`activities` is a live broadcast `Stream<NuxieActivityInfo>`: schema version, event ID, UTC `timestamp` and `receivedAt`, name, and immutable properties. `appActions` is a live broadcast `Stream<NuxieAppAction>`: name, optional payload, and Experience reference. Neither replays old events. Own and cancel your subscriptions.

## Features

`features` is a stable `ValueListenable<NuxieFeatureSnapshot>`. Its immutable `all` map contains global `FeatureAccess` values; `state` is unknown, reconciling, or ready. Each publication is a coherent native snapshot. Empty ready is meaningful. Missing access and unknown readiness must not become a fabricated denial.

`FeatureAccess` preserves allowed, unlimited, nullable double balance, and Feature type.

| Method | Defaults and result |
| --- | --- |
| `hasFeature(id, requiredBalance: 1, entityId, policy: FeatureCheckPolicy.cacheFirst)` | Returns access for the exact query. `remote` requires the native authoritative query; failures throw. |
| `useFeature(id, amount: 1, entityId, metadata)` | Enqueues native usage without waiting for server confirmation. |
| `useFeatureAndWait(id, amount: 1, entityId, setUsage: false, metadata)` | Returns `FeatureUsageResult`: success, featureId, amountUsed, message, optional usage and authoritativeAccess. |

Usage commands require positive whole units up to `Number.MAX_SAFE_INTEGER` (9,007,199,254,740,991). Invalid quantities fail before delivery. Entity IDs select explicitly assigned grants; unknown entities deny access and cannot spend aggregate grants. Unscoped checks retain the customer aggregate. A successful final-unit spend remains successful even when post-spend access is inactive.

`consumeFeature(featureId, quantity: 1, operationId: 'stable-action-id', entityId: 'project-a')` returns `FeatureConsumptionResult`: `operationId`, `customerId`, `featureId`, `occurredAtMs`, `accepted`, `code`, `quantity`, `balance`, `unlimited`, `active`, and `idempotentReplay`. The timestamp is epoch milliseconds and may be null for a receipt recovered from an older native journal. Persist the operation ID with the action and reuse it for a retry. Changing the command while reusing its ID is an error.

`setUsage: true` reports a cumulative total. Reporting 20 then 25 charges 20 then 5; reporting 10 afterward restores no credits. Credit restoration requires an explicit server adjustment. Native journals persist pending commands across restarts and retry their original IDs. Use one usage method per action; do not replace an ambiguous command with a new ID.

`NuxieFeatureBuilder(client:, featureId:, builder:)` rebuilds from the global snapshot. Its builder receives `(context, access, state)`. It does not fetch, consume, or reinterpret access.

## Commerce

`restorePurchases()` returns `RestoreResult` with `restored`, `noPurchases`, or `failed` type and optional failure message. It routes through the configured native or external billing owner.

An external controller implements `purchase(NuxieStoreProduct)` and `restorePurchases()`. Purchase outcomes are `PurchaseResult.purchased()`, `.cancelled()`, `.pending()`, or `.failed(message)`. Native request IDs are implementation details. Requests expire after 120 seconds; late completions cannot fulfill another request.

The product includes Nuxie and store identifiers, platform, optional base plan / purchase option / offer / Placement, available display name and price, Apple billing plan, and Apple introductory eligibility JWS. Available description, product type, period/count, and introductory terms are preserved; Android may omit terms that its public native model does not expose. Preserve the exact selected commercial context. If your provider cannot honor an eligibility override or billing plan, fail explicitly. Do not log eligibility tokens. Android display price can be absent; resolve the selected offer through your billing provider.

## Errors

Commands throw `NuxieException` for invalid configuration, unavailable lifecycle, unsupported platforms, incompatible native contract, and native failures. Invalid Dart arguments throw `ArgumentError`. A thrown transport error is not proof that durable usage was cancelled. Restore and purchase business outcomes use their typed results.
