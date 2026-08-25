import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_event_count_badge.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  testWidgets('event badge is a rounded square, not a pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        // 两处真实调用点都在 Row / Positioned 里(宽度无界),
        // 徽标靠 minWidth 定宽,这里照搬同样的约束。
        home: const Scaffold(
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
    final colors = GenesisTheme.worldoDark()
        .extension<GenesisSemanticColors>()!;

    expect(decoration.color, colors.danger);
    // 半径小于高度的一半 —— 方形圆角,不是胶囊/圆形。
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
