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
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);

      await tester.tap(find.text('WID: w_TEST_1'));
      await tester.pump();

      expect(copied, ['w_TEST_1']);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('can hide copy icon while keeping tap-to-copy behavior', (
    WidgetTester tester,
  ) async {
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
          body: CopyableIdLabel(
            label: 'UID',
            value: 'u_search_1',
            showCopyIcon: false,
          ),
        ),
      ),
    );

    expect(find.text('UID: u_search_1'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);

    await tester.tap(find.text('UID: u_search_1'));
    await tester.pump();

    expect(copied, ['u_search_1']);
    await tester.pump(const Duration(seconds: 2));
  });
}
