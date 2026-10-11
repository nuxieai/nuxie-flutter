import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nuxie_flutter/nuxie_flutter.dart';
import 'main.dart';
import 'v3_probe.dart';

/// Explicit qualification target; ordinary example and release entrypoints are unchanged.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const endpoint = String.fromEnvironment('NUXIE_V3_PROBE_URL');
  if (!kDebugMode || endpoint.isEmpty) {
    throw StateError('Use a Debug build with NUXIE_V3_PROBE_URL for native v3 qualification');
  }
  runApp(NuxieExample(client: Nuxie.instance));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(runV3Probe(Nuxie.instance, endpoint).catchError((Object error) {
      debugPrint('V3_PROBE_FAILURE: $error');
    }));
  });
}
