import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/map_detail_sheet_surface.dart';
import 'package:genesis_flutter_android/ui/components/genesis_modal_border.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  testWidgets('map detail sheet uses the shared modal outline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapDetailSheetSurface(
            surfaceKey: const ValueKey<String>('sheet'),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final outlinedSurface = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('sheet')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .singleWhere(
          (box) =>
              box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).border != null,
        );
    final decoration = outlinedSurface.decoration as BoxDecoration;
    final border = decoration.border! as Border;

    expect(decoration.borderRadius, mapDetailSheetBorderRadius);
    expect(border.top.width, genesisModalBorderWidth);
    expect(
      border.top.color,
      GenesisSemanticColors.worldoLight().textPrimary.withValues(
        alpha: genesisModalBorderOpacity,
      ),
    );
  });

  testWidgets(
    'bottom-connected sheet keeps its divider without a shadow band',
    (tester) async {
      for (final theme in <ThemeData>[
        GenesisTheme.worldoLight(),
        GenesisTheme.worldoDark(),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: MapDetailSheetSurface(
                surfaceKey: ValueKey<String>('connected-sheet'),
                connectsToBottom: true,
                child: SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final colors = theme.extension<GenesisSemanticColors>()!;
        final surface = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey<String>('connected-sheet')),
        );
        final surfaceDecoration = surface.decoration as BoxDecoration;
        final outline = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byKey(const ValueKey<String>('connected-sheet')),
                matching: find.byType(DecoratedBox),
              ),
            )
            .singleWhere(
              (box) =>
                  box.decoration is BoxDecoration &&
                  (box.decoration as BoxDecoration).border != null,
            );
        final border = (outline.decoration as BoxDecoration).border! as Border;

        expect(surfaceDecoration.color, colors.pageBackground);
        expect(surfaceDecoration.boxShadow, isNull);
        expect(border.top.style, BorderStyle.solid);
        expect(border.left.style, BorderStyle.solid);
        expect(border.right.style, BorderStyle.solid);
        expect(border.bottom.style, BorderStyle.solid);
        expect(border.bottom.width, genesisModalBorderWidth);
        expect(
          border.bottom.color,
          colors.textPrimary.withValues(alpha: genesisModalBorderOpacity),
        );
      }
    },
  );
}
