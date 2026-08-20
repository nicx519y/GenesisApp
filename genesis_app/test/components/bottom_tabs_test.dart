import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/bottom_tabs.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  testWidgets('uses the Worldo redesign bottom navigation icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: Scaffold(
          bottomNavigationBar: BottomTabs(currentIndex: 3, onTap: (_) {}),
        ),
      ),
    );

    final icons = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(icons, hasLength(5));
    expect(icons.map(_assetName), <String>[
      bottomNavHomeIconAsset,
      bottomNavOriginIconAsset,
      bottomNavCreateIconAsset,
      bottomNavMessagesPressIconAsset,
      bottomNavMeIconAsset,
    ]);
    expect(icons.map((icon) => icon.width), <double>[22, 22, 16, 22, 22]);
    expect(icons.map((icon) => icon.height), <double>[22, 22, 16, 22, 22]);

    final navigationHeight = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(BottomTabs),
            matching: find.byType(SizedBox),
          ),
        )
        .where((box) => box.width == null && box.height == 54);
    expect(navigationHeight, hasLength(1));

    final navigationDecoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(BottomTabs),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .singleWhere((decoration) => decoration.border != null);
    final border = navigationDecoration.border! as Border;
    expect(border.top.width, 1);
    expect(border.top.color.a, closeTo(0.1, 0.0001));
    expect(border.top.color.r, 1);
    expect(border.top.color.g, 1);
    expect(border.top.color.b, 1);
  });
}

String _assetName(SvgPicture picture) {
  return (picture.bytesLoader as SvgAssetLoader).assetName;
}
