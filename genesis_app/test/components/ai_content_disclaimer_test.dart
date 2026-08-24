import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/ai_content_disclaimer.dart';

void main() {
  testWidgets('AI content disclaimer renders the shared fictional notice', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiContentDisclaimer())),
    );

    final text = tester.widget<Text>(
      find.textContaining(kAiContentDisclaimerText),
    );
    expect(text.style?.color, const Color(0x80131215));
    expect(text.style?.fontSize, 11);
    expect(text.textAlign, TextAlign.center);
    // The hint glyph rides inline at the head of the paragraph, so it centres
    // with the text instead of hanging off the block's left edge.
    final icon = find.byKey(
      const ValueKey<String>('ai-content-disclaimer-hint-icon'),
    );
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon), const Size.square(12));
  });
}
