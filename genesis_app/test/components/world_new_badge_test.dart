import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_new_badge.dart';
import 'package:genesis_flutter_android/ui/components/genesis_soft_italic_text.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

void main() {
  testWidgets('WorldNewBadge renders solid labels in both variants', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              WorldNewBadge(key: ValueKey<String>('regular-new-badge')),
              WorldNewBadge(
                key: ValueKey<String>('compact-new-badge'),
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('New'), findsNWidgets(2));
    expect(find.byType(GenesisSoftItalicText), findsNWidgets(2));
    expect(
      tester.getSize(find.byKey(const ValueKey('regular-new-badge'))),
      const Size(WorldNewBadge.width, WorldNewBadge.height),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-new-badge'))),
      const Size(WorldNewBadge.compactWidth, WorldNewBadge.compactHeight),
    );

    final regularDecoration = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('regular-new-badge')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (regularDecoration.decoration as BoxDecoration).color,
      GenesisColors.brand,
    );
    final regularTransform = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('regular-new-badge')),
        matching: find.byType(Transform),
      ),
    );
    final compactTransform = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('compact-new-badge')),
        matching: find.byType(Transform),
      ),
    );
    expect(regularTransform.transform.getTranslation().y, 1);
    expect(compactTransform.transform.getTranslation().y, 0);
    for (final text in tester.widgetList<Text>(find.text('New'))) {
      expect(text.style?.color, const Color(0xF2FFFFFF));
      expect(text.style?.fontSize, 9.5);
      expect(text.style?.fontWeight, FontWeight.w800);
      expect(text.style?.fontStyle, FontStyle.italic);
      expect(text.style?.fontVariations?.single.axis, 'wght');
      expect(text.style?.fontVariations?.single.value, 800);
    }
    expect(find.bySemanticsLabel('New'), findsNWidgets(2));
    semantics.dispose();
  });
}
