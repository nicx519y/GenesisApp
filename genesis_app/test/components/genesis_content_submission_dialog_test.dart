import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_content_submission_dialog.dart';

void main() {
  testWidgets('content submission dialog supports the unified border', (
    tester,
  ) async {
    const borderColor = Color(0x24FFFFFF);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showGenesisContentSubmissionDialog(
                  context: context,
                  title: 'Feedback',
                  contentInputKey: const ValueKey<String>('feedback-input'),
                  onSubmit: (_) async {},
                  successMessage: 'Submitted',
                  failureMessage: 'Failed',
                  borderColor: borderColor,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final borderContainer = tester.widget<Container>(
      find.byKey(const ValueKey<String>('genesis-action-box-attached-border')),
    );
    final decoration = borderContainer.foregroundDecoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, borderColor);
    expect(border.top.width, 1);
  });
}
