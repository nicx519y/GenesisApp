import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_event_count_badge.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';

void main() {
  testWidgets('single-digit event badge is circular', (tester) async {
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

    expect(decoration.color, GenesisColors.brand);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(WorldEventCountBadge.borderRadius),
    );
    expect(WorldEventCountBadge.borderRadius, WorldEventCountBadge.height / 2);

    final size = tester.getSize(find.byType(WorldEventCountBadge));
    expect(size.height, WorldEventCountBadge.height);
    expect(size.width, WorldEventCountBadge.minWidth);
    final textStyle = tester.widget<Text>(find.text('1')).style;
    expect(textStyle?.fontFamily, GenesisTypography.fontFamily);
    expect(textStyle?.fontFamilyFallback, GenesisTypography.fontFamilyFallback);
    expect(textStyle?.fontSize, 9.5);
    expect(textStyle?.fontWeight, FontWeight.w800);
    expect(textStyle?.fontVariations, isNull);
    expect(textStyle?.color, Colors.white);
    expect(
      find.descendant(
        of: find.byType(WorldEventCountBadge),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
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
    final size = tester.getSize(find.byType(WorldEventCountBadge));
    expect(size.height, WorldEventCountBadge.height);
    expect(size.width, greaterThan(WorldEventCountBadge.height));
  });
}
