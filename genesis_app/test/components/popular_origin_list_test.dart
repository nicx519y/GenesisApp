import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/discuss/origin_discuss_preview_list.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/components/home/popular_origin_list.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_card.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_image_radii.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('renders popular origin feed fields and handles taps', (
    WidgetTester tester,
  ) async {
    const item = OriginListItem(
      oid: 'o_alpha',
      wid: 'w_alpha',
      status: 1,
      versionNum: 3,
      tickCount: 8,
      name: 'Alpha Empire',
      cover: 'https://cdn.example.com/covers/alpha.png',
      displaySubtitle: 'Tycoon idols compete for the crown.',
      worldView: 'A city powered by celebrity markets.',
      createdUid: 'u_1',
      createdUserName: 'Shawn',
      ownerName: 'Origin Owner',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>['romance', 'tycoon'],
      copyCnt: 2300,
      connectCnt: 4400000,
      discussCnt: 128,
      characterCnt: 6,
      locationCnt: 3,
    );
    var tappedOid = '';
    var requestedDiscussOid = '';
    var requestedSummaryOid = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: PopularOriginList(
              items: const <OriginListItem>[item],
              onItemTap: (item) => tappedOid = item.oid,
              discussLoader: (oid) async {
                requestedDiscussOid = oid;
                return <OriginDiscussPreviewItem>[
                  OriginDiscussPreviewItem(
                    discussId: 'dis_1',
                    authorUid: 'u_shawn',
                    authorName: 'Shawn',
                    avatar: '',
                    content: '24 replies pushed the story into a new branch.',
                    replyCount: 36,
                    createdAt: DateTime(2026, 2, 9),
                    seed: 'u_shawn',
                    imageUrls: const <String>[
                      'https://cdn.example.com/discuss/a.png',
                    ],
                    latestReplies: const <Map<String, dynamic>>[
                      {
                        'author': {'name': 'Reply User'},
                        'content': 'Hidden reply',
                      },
                    ],
                  ),
                  OriginDiscussPreviewItem(
                    discussId: 'dis_2',
                    authorName: 'kmev',
                    avatar: '',
                    content: 'The new sibling route is working nicely.',
                    replyCount: 87,
                    createdAt: DateTime(2026, 3, 10),
                    seed: 'u_kmev',
                    latestReplies: const <Map<String, dynamic>>[],
                  ),
                ];
              },
              summaryLoader: (oid) async {
                requestedSummaryOid = oid;
                return const <WorldSummaryLatestItem>[
                  WorldSummaryLatestItem(
                    worldId: 'w_summary_alpha',
                    originId: 'o_alpha',
                    tickNo: 12,
                    summary: 'Latest copied world progress for Alpha.',
                    tickTime: 1771420800000,
                    createdAt: 1771420800000,
                  ),
                ];
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('#Alpha Empire'), findsWidgets);
    expect(find.text('World View'), findsOneWidget);
    expect(find.text('Copy World Progress'), findsOneWidget);
    expect(find.text('OID: o_alpha'), findsOneWidget);
    expect(requestedSummaryOid, 'o_alpha');
    expect(
      find.text('Latest copied world progress for Alpha.'),
      findsOneWidget,
    );
    expect(find.text('A city powered by celebrity markets.'), findsNothing);
    expect(find.text('WID: w_summary_alpha'), findsOneWidget);
    final progressWid = tester.widget<Text>(find.text('WID: w_summary_alpha'));
    final progressTime = tester.widget<Text>(find.text('2-18 21:20'));
    expect(progressWid.style?.color, const Color(0xFF666666));
    expect(progressTime.style?.color, const Color(0xFF888888));
    expect(find.text('Originator: Origin Owner'), findsOneWidget);
    expect(find.text('v3'), findsNothing);
    expect(find.text('12'), findsOneWidget);
    final versionChip = find.byKey(
      const ValueKey('popular-origin-tick-chip-12'),
    );
    final versionChipContainer = tester.widget<Container>(versionChip);
    final versionChipDecoration =
        versionChipContainer.decoration! as BoxDecoration;
    final versionChipRadius =
        versionChipDecoration.borderRadius! as BorderRadius;
    final versionIcon = tester.widget<Icon>(
      find.descendant(of: versionChip, matching: find.byType(Icon)),
    );
    final versionText = tester.widget<Text>(find.text('12'));
    expect(versionChipDecoration.color, const Color(0xFFFEF3C7));
    expect(versionChipRadius.topLeft.x, 5);
    expect(versionIcon.icon, MyFlutterApp.pregress);
    expect(versionIcon.size, 9);
    expect(versionIcon.color, const Color(0xFF92400E));
    expect(versionText.style?.fontSize, 11);
    expect(versionText.style?.fontWeight, FontWeight.w600);
    expect(versionText.style?.color, const Color(0xFF92400E));
    final worldViewIcon = tester.widget<Icon>(find.byIcon(MyFlutterApp.eye));
    expect(worldViewIcon.color, const Color(0xFFFF2344));
    expect(worldViewIcon.size, 14);
    final worldViewTitle = tester.widget<Text>(find.text('World View'));
    final progressTitle = tester.widget<Text>(find.text('Copy World Progress'));
    final discussTitle = tester.widget<Text>(find.text('Discuss (128)'));
    final worldViewBody = tester.widget<Text>(
      find.text('Tycoon idols compete for the crown.'),
    );
    final progressBody = tester.widget<Text>(
      find.text('Latest copied world progress for Alpha.'),
    );
    final discussBody = tester.widget<Text>(
      find.text('24 replies pushed the story into a new branch.'),
    );
    expect(worldViewTitle.style?.fontSize, 13);
    expect(progressTitle.style?.fontSize, 13);
    expect(discussTitle.style?.fontSize, 13);
    expect(worldViewBody.style?.fontSize, 13);
    expect(progressBody.style?.fontSize, 13);
    expect(discussBody.style?.fontSize, 13);
    expect(worldViewBody.style?.color, const Color(0xFF111111));
    expect(progressBody.style?.color, const Color(0xFF111111));
    expect(worldViewBody.maxLines, 5);
    expect(progressBody.maxLines, 5);
    expect(
      _horizontalGap(
        tester,
        find.byIcon(MyFlutterApp.eye),
        find.text('World View'),
      ),
      8,
    );
    expect(
      _horizontalGap(
        tester,
        find.byIcon(MyFlutterApp.lastProgress),
        find.text('Copy World Progress'),
      ),
      8,
    );
    expect(
      _horizontalGap(
        tester,
        find.image(const AssetImage(discussIconAsset)),
        find.text('Discuss (128)'),
      ),
      8,
    );
    expect(_gapHeight(tester, 'popular-origin-gap-meta-world-view'), 16);
    expect(_gapHeight(tester, 'popular-origin-gap-world-view-title-body'), 8);
    expect(_gapHeight(tester, 'popular-origin-gap-world-view-progress'), 16);
    expect(_gapHeight(tester, 'popular-origin-gap-progress-title-body'), 8);
    expect(_gapHeight(tester, 'popular-origin-gap-progress-discuss'), 16);
    expect(_gapHeight(tester, 'popular-origin-gap-world-view-image'), 8);
    expect(
      tester
          .widget<SizedBox>(
            find.byKey(const ValueKey('popular-origin-progress-body')),
          )
          .height,
      closeTo(98.3, 0.01),
    );
    expect(_gapHeight(tester, 'popular-origin-gap-progress-meta'), 0);
    expect(_gapHeight(tester, 'popular-origin-gap-discuss-list'), 8);
    expect(find.byIcon(Icons.skip_next), findsNothing);
    expect(find.text('Discuss (128)'), findsOneWidget);
    expect(find.image(const AssetImage(discussIconAsset)), findsOneWidget);
    expect(requestedDiscussOid, 'o_alpha');
    expect(find.text('Shawn'), findsOneWidget);
    final thumbnails = tester.widgetList<GenesisListImage>(
      find.byType(GenesisListImage),
    );
    expect(
      thumbnails.any(
        (image) =>
            image.width == 60 &&
            image.height == 60 &&
            image.borderRadius ==
                BorderRadius.circular(GenesisImageRadii.contentValue),
      ),
      isTrue,
    );
    expect(
      thumbnails.any((image) => image.width == 107 && image.height == 160.5),
      isTrue,
    );
    final titleLeft = tester.getTopLeft(find.text('#Alpha Empire').first).dx;
    final subtitleLeft = tester
        .getTopLeft(find.text('Tycoon idols compete for the crown.'))
        .dx;
    expect(subtitleLeft, lessThan(titleLeft));
    expect(find.text('36'), findsNothing);
    expect(find.text('2-9 00:00'), findsOneWidget);
    expect(
      find.text('24 replies pushed the story into a new branch.'),
      findsOneWidget,
    );
    expect(find.text('kmev'), findsOneWidget);
    expect(find.text('87'), findsNothing);
    expect(find.text('3-10 00:00'), findsOneWidget);
    expect(
      find.text('The new sibling route is working nicely.'),
      findsOneWidget,
    );
    expect(_assetSvgFinder(copyStatIconAsset), findsOneWidget);
    final connectIcon = tester.widget<SvgPicture>(
      _assetSvgFinder(connectStatIconAsset),
    );
    expect(connectIcon.width, 13);
    expect(connectIcon.height, 13);
    expect(find.text('2.3K'), findsOneWidget);
    expect(find.text('4.4M'), findsOneWidget);
    final enterTitle = tester.widget<Text>(find.text('#Alpha Empire').last);
    final enterText = tester.widget<Text>(find.text('Enter'));
    expect(enterTitle.style?.fontSize, 13);
    expect(enterTitle.style?.color, const Color(0xFF4B6192));
    expect(enterText.style?.fontSize, 13);
    expect(enterText.style?.color, const Color(0xFF4B6192));
    expect(
      find.byKey(const ValueKey('origin-discuss-like-dis_1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('origin-discuss-reply-dis_1')),
      findsNothing,
    );
    expect(find.text('Reply User: Hidden reply'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('popular-origin-thumbnail-o_alpha')),
    );
    expect(tappedOid, 'o_alpha');
    tappedOid = '';

    final cover = find.byKey(const ValueKey('popular-origin-cover-o_alpha'));
    final coverRect = tester.getRect(cover);
    await tester.tap(
      find.byKey(const ValueKey('popular-origin-cover-image-o_alpha')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GenesisImageViewerOverlay), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('genesis-image-viewer-close-background')),
    );
    await tester.pumpAndSettle();
    expect(tappedOid, '');

    await tester.tapAt(Offset(coverRect.right - 8, coverRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(GenesisImageViewerOverlay), findsNothing);
    expect(tappedOid, 'o_alpha');
    tappedOid = '';

    final discussHeader = find.text('Discuss (128)');
    await tester.ensureVisible(discussHeader);
    await tester.tap(discussHeader);
    expect(tappedOid, 'o_alpha');
    tappedOid = '';

    final discussImage = find.byKey(
      const ValueKey(
        'origin-discuss-image-https://cdn.example.com/discuss/a.png',
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(discussImage);
    expect(tappedOid, 'o_alpha');
    tappedOid = '';

    final discussContent = find.text(
      '24 replies pushed the story into a new branch.',
    );
    await tester.ensureVisible(discussContent);
    await tester.tap(discussContent);
    expect(tappedOid, 'o_alpha');
    tappedOid = '';

    final discussContentRect = tester.getRect(discussContent);
    await tester.tapAt(Offset(360, discussContentRect.center.dy));
    expect(tappedOid, 'o_alpha');
    tappedOid = '';

    final discussAvatar = find.byKey(
      const ValueKey('origin-discuss-avatar-u_shawn'),
    );
    await tester.ensureVisible(discussAvatar);
    await tester.tap(discussAvatar);
    expect(tappedOid, 'o_alpha');
    tappedOid = '';

    final discussName = find.text('Shawn');
    await tester.ensureVisible(discussName);
    await tester.tap(discussName);
    expect(tappedOid, 'o_alpha');
    tappedOid = '';

    await tester.tap(find.text('Copy World Progress'));
    expect(tappedOid, 'o_alpha');
  });

  testWidgets('shows natural empty copy world progress when no world summary', (
    WidgetTester tester,
  ) async {
    const item = OriginListItem(
      oid: 'o_empty',
      wid: 'w_empty',
      status: 1,
      versionNum: 1,
      tickCount: 7,
      name: 'Empty Copy World',
      cover: '',
      displaySubtitle: 'A world waiting for its first copy.',
      worldView: 'A quiet setup.',
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
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: PopularOriginList(
              items: const <OriginListItem>[item],
              onItemTap: (_) {},
              discussLoader: (_) async => const <OriginDiscussPreviewItem>[],
              summaryLoader: (_) async => const <WorldSummaryLatestItem>[],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No launched world'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('popular-origin-progress-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('popular-origin-progress-body')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('popular-origin-gap-progress-meta')),
      findsNothing,
    );
    expect(find.text('WID: w_empty'), findsNothing);
    expect(
      find.byKey(const ValueKey('popular-origin-tick-chip-7')),
      findsNothing,
    );
  });

  test('OriginListItem parses world id aliases for popular progress meta', () {
    final fromWid = OriginListItem.fromJson(const <String, Object?>{
      'oid': 'o_alpha',
      'wid': 'w_alpha',
      'name': 'Alpha',
    });
    final fromWorldId = OriginListItem.fromJson(const <String, Object?>{
      'oid': 'o_beta',
      'world_id': 'w_beta',
      'name': 'Beta',
    });

    expect(fromWid.wid, 'w_alpha');
    expect(fromWorldId.wid, 'w_beta');
  });

  testWidgets('uses my worlds divider spacing between popular origins', (
    WidgetTester tester,
  ) async {
    const first = OriginListItem(
      oid: 'o_alpha',
      status: 1,
      versionNum: 1,
      tickCount: 1,
      name: 'Alpha',
      cover: '',
      displaySubtitle: 'Alpha brief.',
      worldView: 'Alpha world view.',
      createdUid: 'u_1',
      createdUserName: 'A',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>[],
      copyCnt: 1,
      connectCnt: 1,
      discussCnt: 0,
      characterCnt: 1,
      locationCnt: 1,
    );
    const second = OriginListItem(
      oid: 'o_beta',
      status: 1,
      versionNum: 1,
      tickCount: 1,
      name: 'Beta',
      cover: '',
      displaySubtitle: 'Beta brief.',
      worldView: 'Beta world view.',
      createdUid: 'u_2',
      createdUserName: 'B',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>[],
      copyCnt: 1,
      connectCnt: 1,
      discussCnt: 0,
      characterCnt: 1,
      locationCnt: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 1600,
            child: PopularOriginList(
              storageKey: const PageStorageKey<String>('list'),
              items: const <OriginListItem>[first, second],
              onItemTap: (_) {},
              discussLoader: (_) async => const <OriginDiscussPreviewItem>[],
              summaryLoader: (_) async => const <WorldSummaryLatestItem>[],
            ),
          ),
        ),
      ),
    );

    final divider = tester.widget<Divider>(find.byType(Divider));
    final padding = tester.widget<Padding>(
      find.ancestor(of: find.byType(Divider), matching: find.byType(Padding)),
    );
    expect(divider.height, 1);
    expect(divider.thickness, 1);
    expect(divider.color, const Color(0xFFEFEFEF));
    expect(
      tester
          .widget<ListView>(find.byKey(const PageStorageKey<String>('list')))
          .padding,
      const EdgeInsets.only(top: 10, bottom: 24),
    );
    expect(padding.padding, const EdgeInsets.only(top: 24, bottom: 16));
  });

  testWidgets('renders preloaded discuss previews without item loader', (
    WidgetTester tester,
  ) async {
    const item = OriginListItem(
      oid: 'o_alpha',
      status: 1,
      versionNum: 3,
      tickCount: 8,
      name: 'Alpha Empire',
      cover: '',
      displaySubtitle: 'Tycoon idols compete for the crown.',
      worldView: 'A city powered by celebrity markets.',
      createdUid: 'u_1',
      createdUserName: 'Shawn',
      ownerName: 'Origin Owner',
      createdAt: '2026-05-01T00:00:00Z',
      updatedAt: '2026-05-02T00:00:00Z',
      tags: <String>['romance', 'tycoon'],
      copyCnt: 2300,
      connectCnt: 4400000,
      discussCnt: 128,
      characterCnt: 6,
      locationCnt: 3,
    );
    var loaderCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: PopularOriginList(
              items: const <OriginListItem>[item],
              preloadedDiscussItems: <String, List<OriginDiscussPreviewItem>>{
                'o_alpha': [
                  OriginDiscussPreviewItem(
                    discussId: 'dis_preloaded',
                    authorName: 'Preloaded User',
                    avatar: '',
                    content: 'This preview arrived before the list rendered.',
                    replyCount: 4,
                    createdAt: DateTime(2026, 4, 8),
                    seed: 'u_preloaded',
                    latestReplies: const <Map<String, dynamic>>[],
                  ),
                ],
              },
              onItemTap: (_) {},
              discussLoader: (_) async {
                loaderCalls += 1;
                return const <OriginDiscussPreviewItem>[];
              },
            ),
          ),
        ),
      ),
    );

    expect(loaderCalls, 0);
    expect(find.text('Preloaded User'), findsOneWidget);
    expect(
      find.text('This preview arrived before the list rendered.'),
      findsOneWidget,
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

double? _gapHeight(WidgetTester tester, String key) {
  return tester.widget<SizedBox>(find.byKey(ValueKey<String>(key))).height;
}

double _horizontalGap(WidgetTester tester, Finder left, Finder right) {
  final leftRect = tester.getRect(left);
  final rightRect = tester.getRect(right);
  return rightRect.left - leftRect.right;
}
