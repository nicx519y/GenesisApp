import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_bottom_sheet.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  testWidgets('world bottom tab animates selected visual state', (
    tester,
  ) async {
    var selectedKind = WorldBottomSheetKind.detail;
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: WorldBottomTags(
                  tabKeyPrefix: 'animated-tab',
                  selectedKind: selectedKind,
                  onTap: (kind) {
                    tapCount += 1;
                    setState(() => selectedKind = kind);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final eventsTab = find.byKey(
      const ValueKey<String>('animated-tab-WorldBottomSheetKind.events'),
    );
    final initialContainer = tester.widget<AnimatedContainer>(eventsTab);
    final initialTextStyle = tester.widget<AnimatedDefaultTextStyle>(
      find.descendant(
        of: eventsTab,
        matching: find.byType(AnimatedDefaultTextStyle),
      ),
    );
    expect(initialContainer.duration, worldBottomTabSelectionDuration);
    expect(initialContainer.curve, worldBottomTabSelectionCurve);
    expect(initialTextStyle.duration, worldBottomTabSelectionDuration);
    expect(initialTextStyle.curve, worldBottomTabSelectionCurve);
    expect(
      find.byKey(const ValueKey<String>('animated-tab-indicator')),
      findsOneWidget,
    );
    final indicatorPaint = tester.renderObject(
      find.byKey(const ValueKey<String>('animated-tab-indicator')),
    );
    final colors = GenesisSemanticColors.worldoDark();
    expect(
      indicatorPaint,
      paints
        ..rrect(color: colors.surfaceTag)
        ..rrect(color: colors.surfaceTag)
        ..rrect(color: colors.surfaceTag)
        ..rrect(color: colors.surfaceTag)
        ..rrect(color: colors.foregroundStrong),
    );

    await tester.tap(eventsTab);
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tapCount, 1);
    expect(selectedKind, WorldBottomSheetKind.events);
  });
}
