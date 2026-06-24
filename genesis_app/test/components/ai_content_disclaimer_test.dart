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

    final text = tester.widget<Text>(find.text(kAiContentDisclaimerText));
    expect(text.style?.color, const Color(0xFF888888));
  });
}
