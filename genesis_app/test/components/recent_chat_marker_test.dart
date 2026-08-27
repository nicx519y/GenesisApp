import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/components/recent_chat_marker.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

void main() {
  testWidgets('recent chat tag keeps its profile-list styling', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RecentChatTag())),
    );

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Last Message'), findsNothing);
    expect(find.text('Last Tick'), findsNothing);
    expect(find.text('Last Launch'), findsNothing);
    expect(find.byType(RecentChatIcon), findsOneWidget);
    expect(_tagColor(tester, 'last-message'), const Color(0xFFFFF0F2));
    expect(
      _tagDecoration(tester, 'last-message').borderRadius,
      BorderRadius.circular(4),
    );

    final recentIcon = tester.widget<RecentChatIcon>(
      find.byType(RecentChatIcon),
    );
    expect(recentIcon.color, kRecentChatMarkerColor);
    expect(kRecentChatMarkerColor, GenesisColors.brand);
    final svg = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byType(RecentChatIcon),
        matching: find.byType(SvgPicture),
      ),
    );
    expect((svg.bytesLoader as SvgAssetLoader).assetName, connectStatIconAsset);
  });
}

Color? _tagColor(WidgetTester tester, String key) {
  return _tagDecoration(tester, key).color;
}

BoxDecoration _tagDecoration(WidgetTester tester, String key) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey<String>('recent-activity-tag-$key')),
  );
  return container.decoration! as BoxDecoration;
}
