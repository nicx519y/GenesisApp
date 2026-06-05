import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/copyable_id_label.dart';

void main() {
  testWidgets(
    'renders lowercase-leading value and copies the whole label area',
    (WidgetTester tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final arguments = call.arguments as Map<dynamic, dynamic>;
              copied.add('${arguments['text']}');
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CopyableIdLabel(label: 'WID', value: 'W_TEST_1'),
          ),
        ),
      );

      expect(find.text('WID: w_TEST_1'), findsOneWidget);

      await tester.tap(find.text('WID: w_TEST_1'));
      await tester.pump();

      expect(copied, ['w_TEST_1']);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
