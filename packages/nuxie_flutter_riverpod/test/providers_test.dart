import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuxie_flutter/nuxie_flutter.dart';
import 'package:nuxie_flutter_riverpod/nuxie_flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';

class Client implements NuxieClient {
  @override
  final SnapshotNotifier features = SnapshotNotifier(
    NuxieFeatureSnapshot.unknown(),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test(
    'provider receives initial readiness and owns its subscription',
    () async {
      final client = Client();
      final container = ProviderContainer(
        overrides: [nuxieProvider.overrideWithValue(client)],
      );
      final subscription = container.listen(nuxieFeaturesProvider, (_, _) {});
      expect(
        (await container.read(nuxieFeaturesProvider.future)).state,
        FeatureState.unknown,
      );
      client.features.value = NuxieFeatureSnapshot(
        state: FeatureState.ready,
        all: {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(nuxieFeaturesProvider).value?.state,
        FeatureState.ready,
      );
      subscription.close();
      container.dispose();
      expect(client.features.isObserved, false);
      client.features.dispose();
    },
  );
}

class SnapshotNotifier extends ValueNotifier<NuxieFeatureSnapshot> {
  SnapshotNotifier(super.value);
  bool get isObserved => hasListeners;
}
