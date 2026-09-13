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
  bool validateUsage = true,
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
    report(
      'PASS: Native profile admitted (${client.features.value.all.length} Features)',
    );
  } finally {
    client.features.removeListener(changed);
  }
  final customer = 'flutter-lab-${DateTime.now().microsecondsSinceEpoch}';
  await client.identify(customer, userProperties: {'validation': true});
  check(
    await client.getDistinctId() == customer && await client.getIsIdentified(),
    'Identify updates native customer',
  );
  await client.setLocaleIdentifier('en-GB');
  await client.setLocaleIdentifier(null);
  report('PASS: Locale override and clear');

  final access = await client.hasFeature(
    featureId,
    requiredBalance: 1,
    policy: FeatureCheckPolicy.remote,
  );
  report(
    'PASS: Remote Feature query returned ${access.allowed}, balance ${access.balance}',
  );
  if (validateUsage) {
    final usage = await client.useFeatureAndWait(
      featureId,
      amount: 1,
      metadata: {'source': 'flutter_sdk_lab_validation'},
    );
    check(
      usage.featureId == featureId,
      'Usage result preserves Feature identity',
    );
    report('Usage committed=${usage.success}, amount=${usage.amountUsed}');
    // A rejected command is a valid outcome for a development customer without grants.
    // Do not issue a second command to retry this usage.
  } else {
    report('SKIP: Metered usage unavailable on this backend');
  }
  await client.trigger(event, properties: {'source': 'sdk_lab_validation'});
  report(
    'PASS: Authored event invoked; inspect presentation and activity separately',
  );
  await Future<void>.delayed(const Duration(seconds: 3));
  await client.dismiss();
  await client.reset(keepAnonymousId: true);
  check(!await client.getIsIdentified(), 'Reset clears identified state');
  check(
    await client.getAnonymousId() == anonymous,
    'Reset retains requested anonymous identity',
  );
  await client.shutdown();
  check(
    !client.isConfigured && client.features.value.state == FeatureState.unknown,
    'Shutdown clears connection and Feature state',
  );
  await client.configure(configuration);
  check(client.isConfigured, 'Reconfiguration after shutdown succeeds');
  report(
    validateUsage
        ? 'VALIDATION COMPLETE'
        : 'VALIDATION COMPLETE — usage skipped',
  );
}
