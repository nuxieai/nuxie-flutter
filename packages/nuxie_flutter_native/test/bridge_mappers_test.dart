import 'package:flutter_test/flutter_test.dart';
import 'package:nuxie_flutter_native/src/bridge_mappers.dart';
import 'package:nuxie_flutter_native/src/generated/nuxie_bridge.g.dart';
import 'package:nuxie_flutter_platform_interface/nuxie_flutter_platform_interface.dart';

void main() {
  group('bridge mappers', () {
    test('configure request contains only customer-owned options', () {
      final request = toConfigureRequest(
        apiKey: 'NX_TEST',
        session: 'test',
        wrapperVersion: '1.2.3',
        usingPurchaseController: true,
        options: const NuxieConfiguration(
          apiKeys: NuxieApiKeys(ios: "ios", android: "android"),
          environment: NuxieEnvironment.development,
          logLevel: NuxieLogLevel.info,
          billing: NuxieBilling.native(handling: PurchaseHandlingMode.observer),
          localeIdentifier: 'en-GB',
        ),
      );

      expect(request.apiKey, 'NX_TEST');
      expect(request.wrapperVersion, '1.2.3');
      expect(request.usingPurchaseController, isTrue);
      expect(request.environment, 'development');
      expect(request.purchaseHandlingMode, 'observer');
      expect(request.localeIdentifier, 'en-GB');
    });

    test('Feature mapping preserves fractions and authoritative access', () {
      final result = fromFeatureUsageResult(
        PFeatureUsageResult(
          success: true,
          featureId: 'credits',
          amountUsed: 1.5,
          usageCurrent: 2.5,
          usageLimit: 10.5,
          usageRemaining: 8,
          authoritativeAccess: PFeatureAccess(
            allowed: true,
            unlimited: false,
            balance: 8,
            type: 'creditSystem',
          ),
        ),
      );

      expect(result.amountUsed, 1.5);
      expect(result.usage?.limit, 10.5);
      expect(result.authoritativeAccess?.balance, 8);
    });

    test('typed activity and App Action mapping is lossless', () {
      final activity = fromActivityInfo(
        PActivityInfo(
          schemaVersion: 1,
          id: 'event-1',
          timestampMs: 10,
          receivedAtMs: 11,
          name: r'$journey_leg_started',
          properties: <String?, Object?>{'journey_id': 'journey-1'},
        ),
      );
      final action = fromAppAction(
        PAppAction(
          name: 'open_settings',
          payload: <String?, Object?>{'tab': 'billing'},
          experience: PExperienceRef(
            experienceId: 'experience-1',
            experienceVersion: 'version-1',
            journeyId: 'journey-1',
          ),
        ),
      );

      expect(activity.properties['journey_id'], 'journey-1');
      expect(action.payload?['tab'], 'billing');
      expect(action.experience.journeyId, 'journey-1');
    });

    test('commerce results use canonical variants', () {
      expect(toPurchaseResult(const PurchaseResult.pending()).type, 'pending');
      expect(
        toRestoreResult(const RestoreResult.noPurchases()).type,
        'no_purchases',
      );
    });
  });
}
