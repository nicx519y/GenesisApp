import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';

void main() {
  for (final unit in ['a', '中', '👨‍👩‍👧‍👦']) {
    testWidgets('composer limits typing and pasted $unit to 999 characters', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatComposer(
              controller: controller,
              inputEnabled: true,
              sendEnabled: true,
              sending: false,
              maxLength: 999,
              onSend: () async {},
            ),
          ),
        ),
      );
      final input = find.byType(TextField);
      final allowed = List.filled(999, unit).join();
      await tester.enterText(input, allowed);
      expect(controller.text, allowed);
      await tester.enterText(input, '$allowed$unit');
      expect(controller.text, allowed);
      await tester.enterText(input, List.filled(1200, unit).join());
      expect(controller.text, allowed);
      await tester.enterText(input, unit);
      expect(controller.text, unit);
    });
  }

  testWidgets('composer without a limit preserves long input', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            inputEnabled: true,
            sendEnabled: true,
            sending: false,
            onSend: () async {},
          ),
        ),
      ),
    );
    final text = List.filled(1200, 'a').join();
    await tester.enterText(find.byType(TextField), text);
    expect(controller.text, text);
  });
}
