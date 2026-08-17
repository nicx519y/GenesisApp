import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_soft_italic_text.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';

void main() {
  testWidgets('soft italic uses a normal font plus light skew on iOS', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const GenesisSoftItalicText(
          'Readable emphasis',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Readable emphasis')).style?.fontStyle,
      FontStyle.normal,
    );
    final transform = tester.widget<Transform>(find.byType(Transform));
    expect(_matchesIosInlineEmphasisSkew(transform.transform), isTrue);
  });

  testWidgets('soft italic uses standard italic away from iOS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const GenesisSoftItalicText(
          'Readable emphasis',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Readable emphasis')).style?.fontStyle,
      FontStyle.italic,
    );
    expect(find.byType(Transform), findsNothing);
  });
}

bool _matchesIosInlineEmphasisSkew(Matrix4 transform) {
  final expected = Matrix4.skewX(GenesisTypography.iosInlineEmphasisSkew);
  for (var index = 0; index < transform.storage.length; index += 1) {
    if ((transform.storage[index] - expected.storage[index]).abs() > 0.0001) {
      return false;
    }
  }
  return true;
}
