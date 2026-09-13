import 'dart:async';
import 'package:nuxie_flutter/nuxie_flutter.dart';
import 'package:riverpod/riverpod.dart';

final nuxieProvider = Provider<NuxieClient>((_) => Nuxie.instance);

final nuxieFeaturesProvider = StreamProvider.autoDispose<NuxieFeatureSnapshot>((
  ref,
) {
  final features = ref.watch(nuxieProvider).features;
  final controller = StreamController<NuxieFeatureSnapshot>();
  void changed() => controller.add(features.value);
  features.addListener(changed);
  changed();
  ref.onDispose(() {
    features.removeListener(changed);
    unawaited(controller.close());
  });
  return controller.stream;
});
