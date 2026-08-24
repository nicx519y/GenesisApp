import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_constants.dart';
import 'package:genesis_flutter_android/pages/world/world_sections_library.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

WorldDetail _world() => WorldDetail.fromJson(const {
  'world_id': 'w_7RX81H',
  'name': 'The Last Waltz of the Ashfords',
  'brief': 'Four men, one fortune, one heart to give.',
  'owner_uid': 'u_eve',
  'owner_username': 'EVE',
  'origin_id': 12,
  'characters': [
    {
      'name': 'Adrian',
      'avatar': '',
      'player_uid': 'user-me',
      'identity': 'Heir',
      'brief': 'Cold.',
      'goal': 'Secure the merger.',
    },
    {
      'name': 'Vivienne',
      'avatar': '',
      'player_uid': '',
      'identity': 'Heiress',
      'brief': 'Clever.',
      'goal': 'Find love.',
    },
  ],
});

Future<void> _pumpDetail(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: GenesisTheme.worldoDark(),
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 844,
          child: WorldDetailSectionListView(
            storageKey: 'world-detail-section-test',
            world: _world(),
            currentUid: 'user-me',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('world title is 16px on the shared 1.3 line height', (
    tester,
  ) async {
    await _pumpDetail(tester);

    final title = tester.widget<Text>(
      find.text('The Last Waltz of the Ashfords'),
    );
    expect(title.style!.fontSize, 16);
    expect(title.style!.height, worldDetailLineHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meta rows are 11px w400 and read as "Label: value"', (
    tester,
  ) async {
    await _pumpDetail(tester);

    for (final finder in [
      find.textContaining('WID:'),
      find.textContaining('Owner:'),
      find.textContaining('Source:'),
    ]) {
      final row = tester.widget<Text>(finder);
      expect(row.style!.fontSize, worldDetailMetaFontSize);
      expect(row.style!.fontWeight, FontWeight.w400);
      expect(row.style!.height, worldDetailLineHeight);
    }
    // Owner 用 @handle 写法。
    expect(find.textContaining('Owner: @'), findsOneWidget);

    final glyph = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).where((
      picture,
    ) {
      final loader = picture.bytesLoader;
      return loader is SvgAssetLoader && loader.assetName == copyIdIconAsset;
    });
    expect(glyph, hasLength(1));
    expect(glyph.single.width, worldDetailMetaIconSize);
  });

  testWidgets('brief and cast sit the same distance under their titles', (
    tester,
  ) async {
    await _pumpDetail(tester);

    final briefTitle = tester.getRect(find.text('World Brief'));
    final briefBody = tester.getRect(find.textContaining('Four men'));
    expect(
      briefBody.top - briefTitle.bottom,
      closeTo(worldDetailSectionTitleContentGap, 0.01),
    );

    final castTitle = tester.getRect(find.text('Cast'));
    final firstRow = tester.getRect(find.byType(WorldCharacterRow).first);
    // 角色行自带上内边距,要加回来才是视觉上的净距。
    expect(
      firstRow.top + worldCharacterRowVerticalPadding - castTitle.bottom,
      closeTo(worldDetailSectionTitleContentGap, 0.01),
    );
  });

  testWidgets('Player / Character label sits on the 45% tier', (tester) async {
    await _pumpDetail(tester);

    final label = tester.widget<Text>(find.text('Character'));
    final colors = GenesisTheme.worldoDark()
        .extension<GenesisSemanticColors>()!;
    expect(label.style!.color, colors.textMetadata);
  });

  testWidgets('detail page no longer shows the new-player join notice', (
    tester,
  ) async {
    await _pumpDetail(tester);

    expect(find.textContaining('launched as'), findsNothing);
  });

  testWidgets('cast avatars match the shared display-and-fetch size', (tester) async {
    await _pumpDetail(tester);

    final avatars = tester.widgetList<GenesisCharacterAvatar>(
      find.byType(GenesisCharacterAvatar),
    );
    expect(avatars, isNotEmpty);
    for (final avatar in avatars) {
      expect(avatar.size, worldCharacterAvatarLogicalSize);
      expect(avatar.borderRadius, worldCharacterAvatarRadius);
    }
  });

  testWidgets('cast rows sit $worldDetailCastRowGap apart', (tester) async {
    await _pumpDetail(tester);

    final rows = find.byType(WorldCharacterRow);
    expect(rows, findsNWidgets(2));
    final first = tester.getRect(rows.at(0));
    final second = tester.getRect(rows.at(1));
    // 行自身上下各 worldCharacterRowVerticalPadding,列表只补差额。
    expect(
      second.top - first.bottom + worldCharacterRowVerticalPadding * 2,
      closeTo(worldDetailCastRowGap, 0.01),
    );
  });
}
