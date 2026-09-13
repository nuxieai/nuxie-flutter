import 'package:flutter_test/flutter_test.dart';
import 'package:nuxie_flutter_platform_interface/nuxie_flutter_platform_interface.dart';

void main() {
  test(
    'Feature snapshots are immutable and preserve readiness with no features',
    () {
      final values = <String, FeatureAccess>{};
      final snapshot = NuxieFeatureSnapshot(
        state: FeatureState.ready,
        all: values,
      );
      values['later'] = const FeatureAccess(
        allowed: true,
        unlimited: true,
        type: FeatureType.boolean,
      );
      expect(snapshot.all, isEmpty);
      expect(snapshot.state, FeatureState.ready);
      expect(() => snapshot.all.clear(), throwsUnsupportedError);
    },
  );
  test('configuration compares native ownership and controller identity', () {
    const keys = NuxieApiKeys(ios: 'ios', android: 'android');
    const native = NuxieConfiguration(apiKeys: keys);
    const observer = NuxieConfiguration(
      apiKeys: keys,
      billing: NuxieBilling.native(handling: PurchaseHandlingMode.observer),
    );
    expect(native.equivalentTo(const NuxieConfiguration(apiKeys: keys)), true);
    expect(native.equivalentTo(observer), false);
  });
}
