import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_card.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';

void main() {
  test('preserves returned UGC backslashes for origin cards', () {
    final item = OriginListItem.fromJson({
      'info': {
        'oid': 'o_alpha',
        'name': r'Name\nvalue',
        'display_subtitle': r'Subtitle\nvalue',
        'world_view': r'View\nvalue',
      },
    });

    expect(item.name, r'Name\nvalue');
    expect(item.displaySubtitle, r'Subtitle\nvalue');
    expect(item.worldView, r'View\nvalue');
  });

  test('parses tick count for shared origin tick chip', () {
    final item = OriginListItem.fromJson({
      'info': {'oid': 'o_alpha', 'name': 'Alpha', 'version_num': 3},
      'stats': {'tick_cnt': 8, 'max_tick_cnt': 11},
    });

    expect(item.versionNum, 3);
    expect(item.tickCount, 8);
  });

  test('falls back to max tick count when tick count is absent', () {
    final item = OriginListItem.fromJson({
      'info': {'oid': 'o_alpha', 'name': 'Alpha', 'version_num': 3},
      'stats': {'max_tick_cnt': 11},
    });

    expect(item.tickCount, 11);
  });

  testWidgets('renders image stats on the cover overlay', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    const item = OriginListItem(
      oid: 'o_alpha',
      status: 1,
      versionNum: 3,
      name: 'Alpha Empire',
      cover: '',
      displaySubtitle: 'Tycoon idols',
      worldView: '',
      createdUid: 'u_1',
      createdUserName: 'Shawn',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>[],
      copyCnt: 2300,
      connectCnt: 4400000,
      discussCnt: 0,
      characterCnt: 8700,
      locationCnt: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 180, child: OriginItemCard(item: item)),
        ),
      ),
    );

    expect(_assetSvgFinder(copyStatIconAsset), findsOneWidget);
    expect(_assetSvgFinder(characterStatIconAsset), findsOneWidget);
    final characterIcon = tester.widget<SvgPicture>(
      _assetSvgFinder(characterStatIconAsset),
    );
    final characterColorMapper =
        (characterIcon.bytesLoader as SvgAssetLoader).colorMapper;
    expect(characterColorMapper, isNotNull);
    expect(
      characterColorMapper!.substitute(
        null,
        'path',
        'fill',
        const Color(0xFF111111),
      ),
      Colors.white,
    );
    expect(
      characterColorMapper.substitute(
        null,
        'path',
        'fill',
        const Color(0xFFFF2442),
      ),
      const Color(0xFFFF2442),
    );
    expect(
      tester.getSize(find.byType(AspectRatio).first),
      const Size(180, 270),
    );
    final connectIcon = tester.widget<SvgPicture>(
      _assetSvgFinder(connectStatIconAsset),
    );
    expect(connectIcon.width, 12);
    expect(connectIcon.height, 12);
    final copyIcon = tester.widget<SvgPicture>(
      _assetSvgFinder(copyStatIconAsset),
    );
    expect(copyIcon.width, 10);
    expect(copyIcon.height, 10);
    expect(find.text('2.3K'), findsOneWidget);
    expect(find.text('4.4M'), findsOneWidget);
    expect(find.text('8.7K'), findsOneWidget);
    expect(tester.widget<Text>(find.text('2.3K')).style?.fontSize, 11);
    expect(find.text('v3'), findsNothing);

    final subtitle = tester.widget<Text>(find.text('Tycoon idols'));
    expect(subtitle.style?.color, Colors.white.withValues(alpha: 0.75));
    expect(subtitle.style?.fontSize, 11);
    expect(subtitle.style?.height, 1.2);
    expect(subtitle.maxLines, 3);
    expect(
      tester
          .widget<GenesisListImage>(find.byType(GenesisListImage))
          .maxDevicePixelRatio,
      3,
    );
  });

  testWidgets('does not render origin tags', (WidgetTester tester) async {
    const item = OriginListItem(
      oid: 'o_alpha',
      status: 1,
      versionNum: 3,
      name: 'Alpha Empire',
      cover: '',
      displaySubtitle: 'Tycoon idols',
      worldView: '',
      createdUid: 'u_1',
      createdUserName: 'Shawn',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>['one', 'two', 'three', 'four', 'five'],
      copyCnt: 2300,
      connectCnt: 4400000,
      discussCnt: 0,
      characterCnt: 0,
      locationCnt: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, child: OriginItemCard(item: item)),
        ),
      ),
    );

    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsNothing);
    expect(find.text('three'), findsNothing);
    expect(find.text('four'), findsNothing);
    expect(find.text('five'), findsNothing);
  });

  testWidgets('limits a long cover title to two lines', (
    WidgetTester tester,
  ) async {
    const longTitle =
        'The Floating City Where Every District Changes at Sunrise';
    const item = OriginListItem(
      oid: 'o_alpha',
      status: 1,
      versionNum: 3,
      name: longTitle,
      cover: '',
      displaySubtitle: 'Tycoon idols',
      worldView: '',
      createdUid: 'u_1',
      createdUserName: 'Shawn',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>[],
      copyCnt: 0,
      connectCnt: 0,
      discussCnt: 0,
      characterCnt: 0,
      locationCnt: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 180, child: OriginItemCard(item: item)),
        ),
      ),
    );

    final titleFinder = find.text('#$longTitle');
    final title = tester.widget<Text>(titleFinder);
    expect(title.style?.color, Colors.white);
    expect(title.style?.fontSize, 13);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(titleFinder).height,
      lessThanOrEqualTo((13 * 1.3 * 2).ceilToDouble()),
    );
  });
}

Finder _assetSvgFinder(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is SvgPicture &&
        widget.bytesLoader is SvgAssetLoader &&
        (widget.bytesLoader as SvgAssetLoader).assetName == assetName,
  );
}
