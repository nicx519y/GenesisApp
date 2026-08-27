import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_event_count_badge.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';

void main() {
  testWidgets('event badge is a rounded square, not a pill', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [WorldEventCountBadge(count: 1)],
            ),
          ),
        ),
      ),
    );

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(WorldEventCountBadge),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;

    expect(decoration.color, const Color(0xFFF82B3C));
    expect(
      decoration.borderRadius,
      BorderRadius.circular(WorldEventCountBadge.borderRadius),
    );
    expect(
      WorldEventCountBadge.borderRadius,
      lessThan(WorldEventCountBadge.height / 2),
    );

    final size = tester.getSize(find.byType(WorldEventCountBadge));
    expect(size.height, WorldEventCountBadge.height);
    expect(size.width, WorldEventCountBadge.minWidth);
    final textStyle = tester.widget<Text>(find.text('1')).style;
    expect(textStyle?.fontFamily, GenesisTypography.fontFamily);
    expect(textStyle?.fontFamilyFallback, GenesisTypography.fontFamilyFallback);
    expect(textStyle?.fontWeight, FontWeight.w600);
  });

  testWidgets('event badge clamps past 99', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [WorldEventCountBadge(count: 120)],
            ),
          ),
        ),
      ),
    );

    expect(find.text('99+'), findsOneWidget);
  });
}
