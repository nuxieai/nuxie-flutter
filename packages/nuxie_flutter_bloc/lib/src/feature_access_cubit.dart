import 'package:bloc/bloc.dart';
import 'package:nuxie_flutter/nuxie_flutter.dart';

/// Mirrors the native snapshot; it never queries or reconstructs Feature state.
class NuxieFeaturesCubit extends Cubit<NuxieFeatureSnapshot> {
  NuxieFeaturesCubit(this.client) : super(client.features.value) {
    client.features.addListener(_changed);
  }
  final NuxieClient client;
  void _changed() => emit(client.features.value);
  @override
  Future<void> close() {
    client.features.removeListener(_changed);
    return super.close();
  }
}
