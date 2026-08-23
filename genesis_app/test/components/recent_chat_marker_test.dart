import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_palette.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/components/recent_chat_marker.dart';

void main() {
  testWidgets('activity tags use distinct icons and colors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RecentChatTag(label: 'Last Message'),
              RecentChatTag(label: 'Last Tick'),
              RecentChatTag(label: 'Last Launch'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Recent'), findsNWidgets(3));
    expect(find.text('Last Message'), findsNothing);
    expect(find.text('Last Tick'), findsNothing);
    expect(find.text('Last Launch'), findsNothing);
    expect(find.byType(RecentChatIcon), findsOneWidget);
    // The canvas has no blue, orange or green: every recency variant sits on
    // the one action colour, pink on a red-tinted surface.
    expect(_tagColor(tester, 'last-message'), GenesisPalette.redesignAccent14);
    expect(_tagColor(tester, 'last-tick'), GenesisPalette.redesignAccent14);
    expect(_tagColor(tester, 'last-launch'), GenesisPalette.redesignAccent14);

    final recentIcon = tester.widget<RecentChatIcon>(
      find.byType(RecentChatIcon),
    );
    expect(recentIcon.color, kRecentChatMarkerColor);
    expect(kRecentChatMarkerColor, GenesisPalette.redesignAccentSoft);
    final svg = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byType(RecentChatIcon),
        matching: find.byType(SvgPicture),
      ),
    );
    expect((svg.bytesLoader as SvgAssetLoader).assetName, connectStatIconAsset);
    final svgAssets = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
        .toList(growable: false);
    expect(svgAssets, contains(tickStatIconAsset));
    expect(svgAssets, contains(launchIconAsset));
    final tickSvg = tester.widget<SvgPicture>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader is SvgAssetLoader &&
            (widget.bytesLoader as SvgAssetLoader).assetName ==
                tickStatIconAsset,
      ),
    );
    expect(tickSvg.width, 8);
    expect(tickSvg.height, 8);
  });
}

Color? _tagColor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey<String>('recent-activity-tag-$key')),
  );
  return (container.decoration as BoxDecoration?)?.color;
}
