import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A3417f59013825e9dfa12/hook.dart';

void main() {
  testWidgets(
    'restores owned draft after editor becomes read-only and unfocused',
    (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      final key = GlobalKey<EditableTextState>();
      Widget subject(bool readOnly) => MaterialApp(
        home: Scaffold(
          body: EditableText(
            key: key,
            controller: controller,
            focusNode: focus,
            readOnly: readOnly,
            style: const TextStyle(),
            cursorColor: Colors.red,
            backgroundCursorColor: Colors.grey,
          ),
        ),
      );
      try {
        await tester.pumpWidget(subject(false));
        await tester.showKeyboard(find.byType(EditableText));
        final before = controller.value;
        final lease = DraftLease(key.currentState!, before);
        tester.testTextInput.enterText(draftText);
        await tester.pump();
        expect(controller.text, draftText);
        focus.unfocus();
        await tester.pumpWidget(subject(true));
        expect(key.currentState!.widget.readOnly, isTrue);
        expect(focus.hasFocus, isFalse);
        // Reproduce the rejected platform update used by the old cleanup.
        key.currentState!.updateEditingValue(before);
        expect(controller.text, draftText);
        expect(await lease.clear(), '');
        expect(controller.value, before);
        expect(lease.cleared, isTrue);
        expect(focus.hasFocus, isFalse);
        expect(await lease.clear(), '');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        focus.dispose();
      }
    },
  );

  testWidgets('preserves foreign edits and reports rejected restoration', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    final key = GlobalKey<EditableTextState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: EditableText(
            key: key,
            controller: controller,
            focusNode: focus,
            style: const TextStyle(),
            cursorColor: Colors.red,
            backgroundCursorColor: Colors.grey,
          ),
        ),
      );
      final lease = DraftLease(key.currentState!, controller.value);
      controller.text = 'foreign edit';
      await expectLater(
        lease.clear(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('outside owned'),
          ),
        ),
      );
      expect(controller.text, 'foreign edit');
      expect(lease.cleared, isFalse);
      controller.text = draftText;
      void rejectRestore() {
        if (controller.text.isEmpty) controller.text = draftText;
      }

      controller.addListener(rejectRestore);
      try {
        await expectLater(
          lease.clear(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('restoration mismatch'),
            ),
          ),
        );
        expect(lease.cleared, isFalse);
      } finally {
        controller.removeListener(rejectRestore);
      }
      expect(await lease.clear(), '');
      expect(lease.cleared, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    }
  });
}
