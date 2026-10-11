import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:nuxie_flutter/nuxie_flutter.dart';

/// Observes the actual Dart/native bridge; an independent log/server oracle owns verdicts.
Future<void> runV3Probe(NuxieClient client, String endpoint) async {
  final base = Uri.parse(endpoint);
  if (base.scheme != 'http' ||
      !['localhost', '127.0.0.1', '10.0.2.2'].contains(base.host) ||
      !base.hasPort || (base.path.isNotEmpty && base.path != '/')) {
    throw ArgumentError('Native v3 qualification requires a loopback fixture server');
  }
  final http = HttpClient();
  Future<Map<String, dynamic>> read(String path) async {
    final response = await (await http.getUrl(base.resolve(path))).close();
    if (response.statusCode != 200) throw StateError('Fixture request failed: $path');
    return jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
  }
  final config = await read('/probe');
  final activities = <Map<String, Object?>>[];
  final actions = <Map<String, Object?>>[];
  final errors = <String>[];
  final states = <String>[];
  final checkpoints = <String>[];
  final activitySubscription = client.activities.listen((value) {
    activities.add({'schemaVersion': value.schemaVersion, 'id': value.id,
      'timestampMs': value.timestampMs, 'receivedAtMs': value.receivedAtMs,
      'name': value.name, 'properties': value.properties});
  }, onError: (Object error) => errors.add(error.toString()));
  final actionSubscription = client.appActions.listen((value) {
    actions.add({'name': value.name, 'payload': value.payload,
      'experience': {'experienceId': value.experience.experienceId,
        'experienceVersion': value.experience.experienceVersion,
        'journeyId': value.experience.journeyId}});
  }, onError: (Object error) => errors.add(error.toString()));
  void captureState() => states.add(client.features.value.state.name);
  client.features.addListener(captureState);
  Future<void> wait(String name, FutureOr<bool> Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) { checkpoints.add(name); return; }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('Native v3 probe did not reach $name');
  }
  String? failure;
  String? nativeVersion;
  try {
    final keys = config['apiKeys'] as Map<String, dynamic>;
    await client.configure(NuxieConfiguration(apiKeys: NuxieApiKeys(
      ios: keys['ios'] as String, android: keys['android'] as String),
      environment: NuxieEnvironment.development, logLevel: NuxieLogLevel.debug));
    checkpoints.add('configured');
    nativeVersion = client.versions.native;
    await wait('initial-profile-delivered', () async => (await read('/status'))['profileCount'] >= 1);
    await client.identify(config['customerId'] as String);
    checkpoints.add('identified');
    if (await client.getDistinctId() != config['customerId']) throw StateError('Native identity differs from probe customer');
    await wait('identified-profile-delivered', () async => (await read('/status'))['identifiedProfileCount'] >= 1);
    if (config['accepted'] == true) {
      await wait('features-ready', () => client.features.value.state == FeatureState.ready);
    }
    await client.trigger(config['event'] as String,
      properties: (config['triggerProperties'] as Map).cast<String, Object?>());
    checkpoints.add('triggered');
    if (config['accepted'] == true) {
      await wait('journey-completed', () => activities.any((value) => value['name'] == 'journey_completed'));
    }
    for (var index = 0; index < 45; index++) {
      await client.trigger('wrapper_v3_transport_probe',
        properties: {'probeIndex': index, 'consumer': config['consumer']});
    }
    await wait('native-event-transport-completed',
      () async => ((await read('/status'))['controlIndexes'] as List).length == 45);
    // Native error logs supply rejection evidence; this settling period is not a verdict.
    await Future<void>.delayed(const Duration(seconds: 2));
    captureState();
  } catch (error) {
    failure = error.toString();
  } finally {
    final finalFeatureState = client.features.value.state.name;
    Future<void> teardown(String name, FutureOr<void> Function() action) async {
      try { await action(); }
      catch (error) {
        final message = 'Teardown $name failed: $error';
        failure = failure == null ? message : '$failure; $message';
      }
    }
    await teardown('feature-listener', () => client.features.removeListener(captureState));
    await teardown('activity-subscription', activitySubscription.cancel);
    await teardown('action-subscription', actionSubscription.cancel);
    await teardown('native-shutdown', () async {
      await client.shutdown();
      checkpoints.add('native-shutdown-completed');
    });
    try {
      final request = await http.postUrl(base.resolve('/observations'));
      request.headers.contentType = ContentType.json;
      final bytes = utf8.encode(jsonEncode({'caseName': config['caseName'], 'consumer': config['consumer'],
        'platform': config['platform'], 'customerId': config['customerId'],
        'nativeVersion': nativeVersion, 'checkpoints': checkpoints, 'activities': activities,
        'appActions': actions, 'errors': errors, 'states': states,
        'finalFeatureState': finalFeatureState, 'failure': failure}));
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != 200) throw StateError('Could not retain native v3 observations');
    } finally {
      http.close();
    }
  }
  final completedFailure = failure;
  if (completedFailure != null) throw StateError(completedFailure);
}
