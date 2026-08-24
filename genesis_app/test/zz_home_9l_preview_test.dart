// TEMPORARY preview harness - renders the 9l Home list to a PNG so the row
// spec can be eyeballed. Delete once the design review is done.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/home/world_item_card.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/components/genesis_profile_collection_list_item.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';

WorldListItem _item({
  required String name,
  required String cover,
  required String summary,
  required String charName,
  required int tickNo,
  int subTickNo = 0,
}) {
  return WorldListItem.fromJson(<String, dynamic>{
    'info': {
      'world_id': 'w_$name',
      'world_name': name,
      'cover': cover,
      'owner_uid': 'u_owner',
      'owner_name': 'Owner',
      'updated_at': '2020-01-02T00:00:00Z',
    },
    'last_tick': {
      'tick_no': tickNo,
      'sub_tick_no': subTickNo,
      'created_at': '2020-01-02T00:00:00Z',
      'narrator': summary,
    },
    'my_character': {
      'char_id': 'c_$charName',
      'player_uid': 'u_mock',
      'name': charName,
      'avatar': {'sm_url': '', 'xl_url': '', 'object_key': ''},
    },
  });
}

void main() {
  // Loaded in setUpAll so the real file read happens outside the widget
  // test's fake-async zone, where a dart:io future would never complete.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manifest =
        json.decode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final family = entry['family'] as String;
      final loader = FontLoader(family);
      for (final font
          in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
      // ignore: avoid_print
      print('loaded font family: $family');
    }
  });

  testWidgets('preview: 9l Home list', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(390 * 3, 640 * 3);
    addTearDown(tester.view.reset);

    const covers = <String>[
      'assets/images/map_default/root_default.webp',
      'assets/images/map_default/l1_default.webp',
      'assets/images/map_default/l2_default.webp',
      'assets/images/map_default/location_default.webp',
    ];

    final items = <(WorldListItem, String)>[
      (
        _item(
          name: 'Old Money',
          cover: covers[0],
          summary:
              'Vivienne slipped the board table before the merger papers came out, and Dorian still holds the ledger he took from the library.',
          charName: 'Adrian Vale',
          tickNo: 2,
          subTickNo: 3,
        ),
        'Last Tick',
      ),
      (
        _item(
          name: 'Deep Cover',
          cover: covers[1],
          summary: 'You have picked your role, but nobody has spoken yet.',
          charName: 'Dorian Ash',
          tickNo: 0,
        ),
        '',
      ),
      (
        _item(
          name: 'The Last Word',
          cover: covers[2],
          summary:
              'The night deepens as three forces recalibrate after Hannah walks out of the reading of the will.',
          charName: 'Vivienne Ashford',
          tickNo: 3,
        ),
        '',
      ),
      (
        _item(
          name: 'The Final Rose',
          cover: covers[3],
          summary:
              'Two roses left and the producers have started rewriting the questions between takes.',
          charName: 'Sebastian Wilder',
          tickNo: 4,
          subTickNo: 1,
        ),
        'Last Tick',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: GenesisTheme.worldoDark(),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.genesisColors.pageBackground,
            body: RepaintBoundary(
              key: const ValueKey<String>('preview'),
              child: ColoredBox(
                color: context.genesisColors.pageBackground,
                child: ListView.separated(
                  // Mirrors the live list: 14px lead-in, 22px page margin,
                  // 24px between rows, no rule.
                  padding: const EdgeInsets.only(top: 14, bottom: 36),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 24),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: WorldItemCard(
                      item: items[index].$1,
                      recentActivityTagLabel: items[index].$2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Asset decoding needs a real async gap; fake-async pumps never finish it.
    await tester.runAsync(() async {
      for (final cover in covers) {
        await precacheImage(
          AssetImage(cover),
          tester.element(find.byType(ListView)),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byKey(const ValueKey<String>('preview')),
      matchesGoldenFile('preview/home_9l.png'),
    );
  });

  testWidgets('preview: Home row above the Me row', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(390 * 3, 430 * 3);
    addTearDown(tester.view.reset);

    const covers = <String>[
      'assets/images/map_default/root_default.webp',
      'assets/images/map_default/l1_default.webp',
    ];

    final homeItem = _item(
      name: 'Old Money',
      cover: covers[0],
      summary:
          'Vivienne slipped the board table before the merger papers came out, and Dorian still holds the ledger.',
      charName: 'Adrian Vale',
      tickNo: 2,
      subTickNo: 3,
    );

    Widget label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: context.genesisColors.primary,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: GenesisTheme.worldoDark(),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.genesisColors.pageBackground,
            body: RepaintBoundary(
              key: const ValueKey<String>('compare'),
              // The boundary captures only what it paints, so the page colour
              // has to live inside it - a Scaffold background would not.
              child: ColoredBox(
                color: context.genesisColors.pageBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label(context, 'HOME  (9l)'),
                    for (var i = 0; i < 2; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: WorldItemCard(
                          item: homeItem,
                          recentActivityTagLabel: i == 0 ? 'Last Tick' : '',
                        ),
                      ),
                      if (i == 0) const SizedBox(height: 13),
                    ],
                    label(context, 'ME  (9k)'),
                    for (var i = 0; i < 2; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: GenesisProfileCollectionListItem(
                          item: GenesisProfileCollectionItemData(
                            imageUrl: covers[i],
                            title: 'Old Money',
                            subtitle:
                                'OID: o_7F2KQ9\nLatest Version: V1 - 2026-07-02 21:40',
                            useRedesignedLayout: true,
                            stats: const [
                              GenesisProfileCollectionStat(
                                icon: Icons.copy_all_outlined,
                                value: 12,
                              ),
                              GenesisProfileCollectionStat(
                                icon: Icons.chat_bubble_outline,
                                value: 34,
                              ),
                              GenesisProfileCollectionStat(
                                icon: Icons.person_outline,
                                value: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i == 0) const SizedBox(height: 13),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      for (final cover in covers) {
        await precacheImage(
          AssetImage(cover),
          tester.element(find.byType(Column).first),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await expectLater(
      find.byKey(const ValueKey<String>('compare')),
      matchesGoldenFile('preview/home_vs_me.png'),
    );
  });
}
