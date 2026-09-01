import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_new_badge.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

void main() {
  testWidgets('WorldNewBadge uses the shared brand treatment', (tester) async {
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
    expect(
      tester.getSize(find.byKey(const ValueKey('regular-new-badge'))),
      const Size(WorldNewBadge.width, WorldNewBadge.height),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-new-badge'))),
      const Size(WorldNewBadge.compactWidth, WorldNewBadge.compactHeight),
    );

    final regularContainer = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('regular-new-badge')),
        matching: find.byType(Container),
      ),
    );
    final decoration = regularContainer.decoration! as BoxDecoration;
    expect(decoration.color, GenesisColors.brand);
    expect(
      tester.widget<Text>(find.text('New').first).style!.color,
      Colors.white,
    );
  });
}
