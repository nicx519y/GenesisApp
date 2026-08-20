import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/map_detail_sheet_surface.dart';
import 'package:genesis_flutter_android/ui/components/genesis_modal_border.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';

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
      GenesisSemanticColors.light().textPrimary.withValues(
        alpha: genesisModalBorderOpacity,
      ),
    );
  });
}
