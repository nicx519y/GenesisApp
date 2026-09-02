import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_new_badge.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

void main() {
  testWidgets('WorldNewBadge renders lowercase red new text', (tester) async {
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

    expect(find.text('new'), findsNWidgets(2));
    expect(
      tester.getSize(find.byKey(const ValueKey('regular-new-badge'))),
      const Size(WorldNewBadge.width, WorldNewBadge.height),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-new-badge'))),
      const Size(WorldNewBadge.compactWidth, WorldNewBadge.compactHeight),
    );

    for (final text in tester.widgetList<Text>(find.text('new'))) {
      expect(text.style?.color, GenesisColors.brand);
    }
    expect(find.bySemanticsLabel('New'), findsNWidgets(2));
    semantics.dispose();
  });
}
