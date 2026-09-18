import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';

void main() {
  for (final variant in [(36.0, 1.0), (60.0, 1.0), (100.0, 1.0), (36.0, 1.8)]) {
    testWidgets('composer measures only focus expansion: $variant', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Draft');
      addTearDown(controller.dispose);
      Widget build(bool focused) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(variant.$2)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatComposer(
              controller: controller,
              inputEnabled: true,
              sendEnabled: true,
              sending: false,
              onSend: () async {},
              leadingShortcutLabel: focused ? '*' : null,
              secondaryLeadingShortcutLabel: focused ? '@' : null,
              pinActionsToBottom: true,
              style: ChatUiStyleConfig.standard.copyWith(
                composerSendButtonHeight: variant.$1,
              ),
            ),
          ),
        ),
      );
      final composer = find.byType(ChatComposer);
      await tester.pumpWidget(build(false));
      final closedHeight = tester.getSize(composer).height;
      expect(
        ChatComposer.keyboardExpansionOf(tester.renderObject(composer)),
        0,
      );
      await tester.pumpWidget(build(true));
      expect(
        ChatComposer.keyboardExpansionOf(tester.renderObject(composer)),
        closeTo(tester.getSize(composer).height - closedHeight, .001),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
