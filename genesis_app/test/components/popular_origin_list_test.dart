import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/discuss/origin_discuss_preview_list.dart';
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
                    authorName: 'Shawn',
                    avatar: '',
                    content: '24 replies pushed the story into a new branch.',
                    replyCount: 36,
                    createdAt: DateTime(2026, 2, 9),
                    seed: 'u_shawn',
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
    expect(find.text('Copy World Progress'), findsOneWidget);
    expect(find.text('OID: o_alpha'), findsOneWidget);
    expect(requestedSummaryOid, 'o_alpha');
    expect(
      find.text('Latest copied world progress for Alpha.'),
      findsOneWidget,
    );
    expect(find.text('A city powered by celebrity markets.'), findsNothing);
    expect(find.text('WID: w_summary_alpha'), findsOneWidget);
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
    expect(versionText.style?.fontWeight, FontWeight.w500);
    expect(versionText.style?.color, const Color(0xFF92400E));
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
      thumbnails.any((image) => image.width == null && image.height == 160.5),
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
    expect(
      find.byKey(const ValueKey('origin-discuss-like-dis_1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('origin-discuss-reply-dis_1')),
      findsNothing,
    );
    expect(find.text('Reply User: Hidden reply'), findsNothing);

    await tester.tap(find.text('Copy World Progress'));
    expect(tappedOid, 'o_alpha');
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
