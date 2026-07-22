import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_card.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';

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

    expect(_assetSvgFinder(copyStatIconAsset), findsOneWidget);
    expect(
      tester.getSize(find.byType(AspectRatio).first),
      const Size(180, 270),
    );
    final connectIcon = tester.widget<SvgPicture>(
      _assetSvgFinder(connectStatIconAsset),
    );
    expect(connectIcon.width, 13);
    expect(connectIcon.height, 13);
    expect(find.text('2.3K'), findsOneWidget);
    expect(find.text('4.4M'), findsOneWidget);
    expect(find.text('v3'), findsNothing);

    final subtitle = tester.widget<Text>(find.text('Tycoon idols'));
    expect(subtitle.style?.color, const Color(0xFF888888));
    expect(subtitle.style?.fontSize, 12);
    expect(subtitle.style?.height, 1.2);
    expect(subtitle.maxLines, 4);
  });

  testWidgets('shows all tags that fit within two rows', (
    WidgetTester tester,
  ) async {
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

    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsOneWidget);
    expect(find.text('four'), findsOneWidget);
    expect(find.text('five'), findsOneWidget);
  });

  testWidgets('wraps and fully displays a long title', (
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
    expect(title.maxLines, isNull);
    expect(title.overflow, isNull);
    expect(tester.getSize(titleFinder).height, greaterThan(14 * 1.3));
  });

  testWidgets('hides tags that would overflow past two rows', (
    WidgetTester tester,
  ) async {
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
      tags: <String>[
        'alphaalphaalphaalphaalpha',
        'betabetabetabetabeta',
        'gammagammagammagamma',
        'deltadeltadeltadelta',
      ],
      copyCnt: 2300,
      connectCnt: 4400000,
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

    expect(find.text('alphaalphaalphaalphaalpha'), findsOneWidget);
    expect(find.text('betabetabetabetabeta'), findsOneWidget);
    expect(find.text('gammagammagammagamma'), findsNothing);
    expect(find.text('deltadeltadeltadelta'), findsNothing);

    final alpha = tester.widget<Text>(find.text('alphaalphaalphaalphaalpha'));
    expect(alpha.overflow, TextOverflow.visible);
    expect(alpha.softWrap, isFalse);
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
