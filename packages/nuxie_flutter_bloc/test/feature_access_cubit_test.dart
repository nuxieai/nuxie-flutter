import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuxie_flutter/nuxie_flutter.dart';
import 'package:nuxie_flutter_bloc/nuxie_flutter_bloc.dart';

class Client implements NuxieClient {
  @override
  final SnapshotNotifier features = SnapshotNotifier(
    NuxieFeatureSnapshot.unknown(),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('Cubit mirrors empty readiness and detaches on close', () async {
    final client = Client();
    final cubit = NuxieFeaturesCubit(client);
    client.features.value = NuxieFeatureSnapshot(
      state: FeatureState.ready,
      all: {},
    );
    expect(cubit.state.state, FeatureState.ready);
    await cubit.close();
    expect(client.features.isObserved, false);
    client.features.dispose();
  });
}

class SnapshotNotifier extends ValueNotifier<NuxieFeatureSnapshot> {
  SnapshotNotifier(super.value);
  bool get isObserved => hasListeners;
}
