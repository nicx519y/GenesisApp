import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/components/recent_chat_marker.dart';

void main() {
  testWidgets('recent chat markers use the world connect stat icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RecentChatTag(),
              RecentChatIcon(key: ValueKey<String>('location-marker')),
              RecentChatIcon(key: ValueKey<String>('map-marker')),
            ],
          ),
        ),
      ),
    );

    final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
    expect(pictures, hasLength(3));
    for (final picture in pictures) {
      final loader = picture.bytesLoader as SvgAssetLoader;
      expect(loader.assetName, connectStatIconAsset);
    }
    for (final marker in tester.widgetList<RecentChatIcon>(
      find.byType(RecentChatIcon),
    )) {
      expect(marker.color, kRecentChatMarkerColor);
    }
    expect(kRecentChatMarkerColor, const Color(0xFF338960));
  });
}
