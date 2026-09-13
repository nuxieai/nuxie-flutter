import 'package:flutter_test/flutter_test.dart';
import 'package:nuxie_flutter/nuxie_flutter.dart';
import 'package:nuxie_flutter_example/main.dart';

void main() {
  testWidgets(
    'starts unconfigured and shows the same native lab on both platforms',
    (tester) async {
      await tester.pumpWidget(NuxieExample(client: Nuxie.instance));
      expect(find.text('Configure'), findsOneWidget);
      expect(find.text('iOS public API key'), findsOneWidget);
      expect(find.text('Android public API key'), findsOneWidget);
      await tester.tap(find.text('Features'));
      await tester.pumpAndSettle();
      expect(find.text('Native state: unknown'), findsOneWidget);
      expect(find.text('Consume & wait'), findsOneWidget);
    },
  );
}
