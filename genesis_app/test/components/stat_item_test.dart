import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/stat_item.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('scales and offsets character icon relative to stat base size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StatItem(
          iconAsset: characterStatIconAsset,
          preserveIconAssetColor: true,
          iconSize: 14,
          text: '6',
        ),
      ),
    );

    final translated = tester.widget<Transform>(find.byType(Transform));
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

    expect(svg.width, moreOrLessEquals(17.5));
    expect(svg.height, moreOrLessEquals(17.5));
    expect(
      translated.transform.getTranslation().y,
      moreOrLessEquals(-1.018181818181818),
    );
  });

  testWidgets('renders stat icon assets with svg pictures', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StatItem(iconAsset: userStatIconAsset, iconSize: 14, text: '6'),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, 14);
    expect(svg.height, 14);
  });

  testWidgets('uses character sizing for the home character icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StatItem(
          iconAsset: homeCharacterStatIconAsset,
          preserveIconAssetColor: true,
          iconSize: 14,
          text: '6',
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, moreOrLessEquals(17.5));
    expect(svg.height, moreOrLessEquals(17.5));
  });

  testWidgets('uses light and dark multicolor character icon variants', (
    WidgetTester tester,
  ) async {
    Future<void> pump(Brightness brightness) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          themeAnimationDuration: Duration.zero,
          home: const Scaffold(
            body: StatItem(
              iconAsset: characterStatIconAsset,
              preserveIconAssetColor: true,
              text: '1',
            ),
          ),
        ),
      );
    }

    await pump(Brightness.light);
    expect(
      _assetName(tester.widget<SvgPicture>(find.byType(SvgPicture))),
      characterStatIconAsset,
    );

    await pump(Brightness.dark);
    expect(
      _assetName(tester.widget<SvgPicture>(find.byType(SvgPicture))),
      homeCharacterStatIconAsset,
    );
  });
}

String _assetName(SvgPicture picture) {
  return (picture.bytesLoader as SvgAssetLoader).assetName;
}
