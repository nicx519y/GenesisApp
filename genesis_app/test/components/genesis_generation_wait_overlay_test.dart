import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_generation_wait_overlay.dart';

void main() {
  testWidgets('generation wait overlay supports the world dark style', (
    WidgetTester tester,
  ) async {
    const title = 'Progressing the World';
    const message = 'Advancing the world timeline';

    await tester.pumpWidget(
      const MaterialApp(
        home: GenesisGenerationWaitOverlay(
          title: title,
          message: message,
          animateTitleDots: false,
          brightness: Brightness.dark,
        ),
      ),
    );

    final dialog = tester.widget<AlertDialog>(
      find.byKey(const ValueKey('world-tick1-wait-dialog')),
    );
    expect(dialog.backgroundColor, const Color(0xCC1F1D24));
    expect(dialog.surfaceTintColor, Colors.transparent);
    expect(
      tester.widget<Text>(find.text(title)).style?.color,
      const Color(0xF2FFFFFF),
    );
    expect(
      tester.widget<Text>(find.text(message)).style?.color,
      const Color(0xB8FFFFFF),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
