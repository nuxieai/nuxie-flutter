import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nuxie_flutter/nuxie_flutter.dart';
import 'package:nuxie_flutter_example/main.dart';
import 'package:nuxie_flutter_example/validation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real native SDK lifecycle and development API', (tester) async {
    final client = Nuxie.instance;
    await tester.pumpWidget(NuxieExample(client: client));
    final reports = <String>[];
    await validateSdk(client, const NuxieConfiguration(
      apiKeys: NuxieApiKeys(
        ios: String.fromEnvironment('NUXIE_IOS_API_KEY'),
        android: String.fromEnvironment('NUXIE_ANDROID_API_KEY'),
      ),
      environment: NuxieEnvironment.development,
    ), reports.add,
      event: const String.fromEnvironment('NUXIE_EVENT', defaultValue: 'sdk_lab_opened'),
      featureId: const String.fromEnvironment('NUXIE_FEATURE', defaultValue: 'exports'),
    );
    expect(reports.last, 'VALIDATION COMPLETE');
    await client.shutdown();
  });
}
