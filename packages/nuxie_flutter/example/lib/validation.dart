import 'dart:async';
import 'package:nuxie_flutter/nuxie_flutter.dart';

/// Runs against the real native SDK and the app/environment configured by the Lab.
/// Use a disposable development customer: this changes identity and reports usage.
Future<void> validateSdk(
  NuxieClient client,
  NuxieConfiguration configuration,
  void Function(String) report, {
  required String event,
  required String featureId,
  String? customerId,
  String? entityA,
  String? entityB,
  String? expectedAppAction,
}) async {
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
    report('PASS: $message');
  }

  await client.configure(configuration);
  check(
    client.isConfigured && client.versions.contract == 2,
    'Native setup negotiated contract 2',
  );
  check(client.versions.native?.isNotEmpty == true, 'Native version available');
  final anonymous = await client.getAnonymousId();
  check(anonymous.isNotEmpty, 'Anonymous identity available');
  Future<void> waitForReady() async {
    final ready = Completer<void>();
    void changed() {
      if (client.features.value.state == FeatureState.ready &&
          !ready.isCompleted) {
        ready.complete();
      }
    }

    client.features.addListener(changed);
    try {
      changed();
      await ready.future.timeout(const Duration(seconds: 60));
    } finally {
      client.features.removeListener(changed);
    }
  }

  await waitForReady();
  report("PASS: Native profile admitted");
  await client.setLocaleIdentifier('en-GB');
  await client.setLocaleIdentifier(null);
  report('PASS: Locale override and clear');
  final customer =
      customerId ?? 'flutter-lab-${DateTime.now().microsecondsSinceEpoch}';
  await client.identify(customer, userProperties: {'validation': true});
  check(
    await client.getDistinctId() == customer && await client.getIsIdentified(),
    'Identify updates native customer',
  );
  await waitForReady();
  report("PASS: Identified profile is ready");

  final access = await client.hasFeature(
    featureId,
    requiredBalance: 1,
    policy: FeatureCheckPolicy.remote,
  );
  report(
    'PASS: Remote Feature query returned ${access.allowed}, balance ${access.balance}',
  );
  if (entityA != null && entityB != null) {
    final a = await client.hasFeature(featureId, entityId: entityA);
    final b = await client.hasFeature(featureId, entityId: entityB);
    check(
      a.allowed && a.balance == 100 && b.balance == 100,
      'Both assigned entities have 100 credits',
    );
    final operationId =
        'flutter-final-${DateTime.now().microsecondsSinceEpoch}';
    final finalUnit = await client.consumeFeature(
      featureId,
      quantity: 100,
      operationId: operationId,
      entityId: entityA,
    );
    check(
      finalUnit.accepted && !finalUnit.active && finalUnit.balance == 0,
      'Final credit consumption accepted with zero remaining',
    );
    final replay = await client.consumeFeature(
      featureId,
      quantity: 100,
      operationId: operationId,
      entityId: entityA,
    );
    check(
      replay.accepted && replay.idempotentReplay && replay.balance == 0,
      'Same operation replays without another spend',
    );
    final denied = await client.consumeFeature(
      featureId,
      operationId: '$operationId-empty',
      entityId: entityA,
    );
    check(!denied.accepted, 'Empty entity cannot spend another credit');
    final untouched = await client.hasFeature(
      featureId,
      entityId: entityB,
      policy: FeatureCheckPolicy.remote,
    );
    check(untouched.balance == 100, 'Entity B retains its assigned credits');
    final unknown = await client.hasFeature(
      featureId,
      entityId: 'unknown-entity',
      policy: FeatureCheckPolicy.remote,
    );
    check(!unknown.allowed, 'Unknown entity is denied');
    await client.useFeatureAndWait(featureId, amount: 20, entityId: entityB);
    final increased = await client.useFeatureAndWait(
      featureId,
      amount: 25,
      entityId: entityB,
      setUsage: true,
    );
    check(
      increased.success && increased.usage?.remaining == 75,
      'Cumulative report charges only the increase',
    );
    final lower = await client.useFeatureAndWait(
      featureId,
      amount: 10,
      entityId: entityB,
      setUsage: true,
    );
    check(
      lower.success && lower.usage?.remaining == 75,
      'Lower cumulative report restores no credits',
    );
  } else {
    final usage = await client.useFeatureAndWait(
      featureId,
      amount: 1,
      metadata: {'source': 'flutter_sdk_lab_validation'},
    );
    check(
      usage.featureId == featureId,
      'Usage receipt preserves Feature identity',
    );
    report('Usage committed=${usage.success}, amount=${usage.amountUsed}');
  }
  final appAction = expectedAppAction == null
      ? null
      : client.appActions
            .firstWhere((action) => action.name == expectedAppAction)
            .timeout(const Duration(minutes: 2));
  await client.trigger(event, properties: {'source': 'sdk_lab_validation'});
  report(
    'PASS: Authored event invoked; inspect presentation and activity separately',
  );
  if (appAction != null) {
    await appAction;
    report('PASS: Authored App Action delivered: $expectedAppAction');
  } else {
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  await client.dismiss();
  await client.reset(keepAnonymousId: true);
  check(!await client.getIsIdentified(), 'Reset clears identified state');
  check(
    await client.getAnonymousId() == anonymous,
    'Reset retains requested anonymous identity',
  );
  await waitForReady();
  await client.identify(customer);
  await waitForReady();
  report("PASS: Reset and reidentify restore profile readiness");
  await client.shutdown();
  check(
    !client.isConfigured && client.features.value.state == FeatureState.unknown,
    'Shutdown clears connection and Feature state',
  );
  await client.configure(configuration);
  check(client.isConfigured, 'Reconfiguration after shutdown succeeds');
  report('VALIDATION COMPLETE');
}
