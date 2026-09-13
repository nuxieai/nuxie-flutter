# Bloc and Riverpod

Adapters mirror `NuxieClient.features`. They do not perform remote queries, maintain customer identity, or decide Feature access. Pass commands to the same client.

## Bloc

```dart
final cubit = NuxieFeaturesCubit(nuxie);
// cubit.state is the current NuxieFeatureSnapshot.
// Use BlocBuilder<NuxieFeaturesCubit, NuxieFeatureSnapshot> in your UI.
await cubit.close();
```

The Cubit starts with the current snapshot and removes its listener on close. Closing it does not shut down Nuxie.

## Riverpod

Override `nuxieProvider` with your configured `NuxieClient` when you use dependency injection. Observe `nuxieFeaturesProvider` for `AsyncValue<NuxieFeatureSnapshot>`. Its initial value comes from the current listenable; subsequent publications are forwarded and listeners are removed when the provider is disposed.

```dart
ProviderScope(
  overrides: [nuxieProvider.overrideWithValue(nuxie)],
  child: const MyApp(),
)
```

In tests, override with a fake `NuxieClient` that owns a `ValueNotifier<NuxieFeatureSnapshot>`. Changing its value tests your access UI without loading a native engine. Never use a global snapshot as the result of an entity-scoped query.
