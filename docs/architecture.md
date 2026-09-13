# Architecture

The public package provides `NuxieClient`, lifecycle coordination, typed immutable models, and a pure Feature widget. The optional adapters only mirror its observable snapshot.

The platform interface is an implementation/testing seam. The native package translates it through generated Pigeon Dart, Swift, and Kotlin code. Native SDKs own identity, event persistence, Journeys, presentation, Feature authority, transaction verification, and durable command recovery. Dart never interprets Journey programs or implements an HTTP client for Nuxie.

## Coherent state

Native Feature publications carry the whole global access map and readiness from the same committed state, plus identity generation and publication revision. Dart accepts only the current engine session and increasing revisions/generations. This fences delayed customer and engine callbacks. No synthetic initial denial is emitted; the initial state is unknown.

## Startup and ownership

Dart attaches handlers before invoking native setup, including the configured external billing controller. A native process supports one owning Flutter engine. Equivalent setup can reconnect after an engine restart; conflicting setup is rejected. Explicit shutdown resets configuration; engine detachment releases bridge handlers without cancelling native durable work.

Activities and App Actions are live observation streams. They are not trigger handles or command-completion channels. The bridge keeps checkout correlation IDs private and resolves pending delegates with failure on teardown or timeout.

## Contract changes

`packages/nuxie_flutter_native/pigeons/nuxie_bridge.dart` is canonical. Regenerate all three outputs with Pigeon 26.3.4. Contract version 2 is checked during configuration. Native public API baselines are reviewed in each native repository; changing Dart DTOs cannot substitute for native semantic support.
