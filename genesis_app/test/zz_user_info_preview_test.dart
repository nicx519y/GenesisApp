// TEMPORARY preview harness - renders the Me profile next to another user's
// profile (user info page) so the worldoMe alignment can be eyeballed.
// Delete once the design review is done.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/me/user_profile_content.dart';
import 'package:genesis_flutter_android/ui/components/genesis_page_header.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

const _covers = <String>[
  'assets/images/map_default/root_default.webp',
  'assets/images/map_default/l1_default.webp',
];

UserProfileData _profile({required bool isSelf}) {
  return UserProfileData(
    avatarUrl: '',
    displayName: isSelf ? 'Eve' : 'Redstorm',
    uid: isSelf ? 'u_A7BN1K' : 'u_B2XK9Q',
    followingCount: isSelf ? 1 : 8,
    followerCount: isSelf ? 2 : 126,
    isSelf: isSelf,
    isFollowed: false,
    origins: const [],
    worlds: const [],
  );
}

ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>> _origins() {
  return ValueNotifier(
    UserProfileCollectionState<UserProfileOriginItem>(
      isLoading: false,
      total: 2,
      items: [
        for (var i = 0; i < 2; i++)
          UserProfileOriginItem(
            originId: i,
            oid: 'o_7F2KQ$i',
            title: i == 0 ? 'Old Money' : 'Clout House',
            subtitle:
                'OID: o_7F2KQ$i  Originator: Redstorm\nLatest Version: V1',
            imageUrl: _covers[i],
            copyCount: 12,
            interactCount: 34,
            characterCount: 5,
          ),
      ],
    ),
  );
}

ValueNotifier<UserProfileCollectionState<UserProfileWorldItem>> _worlds() {
  return ValueNotifier(
    UserProfileCollectionState<UserProfileWorldItem>(
      isLoading: false,
      total: 1,
      items: [
        UserProfileWorldItem(
          wid: 'w_9KX2',
          title: 'Old Money',
          subtitle: 'WID: w_9KX2  Owner: Redstorm',
          imageUrl: _covers[0],
          progressCount: 3,
          interactCount: 62,
          characterCount: 5,
          playerCount: 4,
          ownerName: 'Redstorm',
        ),
      ],
    ),
  );
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
    }
  });

  testWidgets('preview: user info page next to Me profile', (tester) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(792 * 2, 740 * 2);
    addTearDown(tester.view.reset);

    Widget label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
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

    Widget panel(
      BuildContext context,
      String caption, {
      required bool isSelf,
      required bool withBackBar,
    }) {
      return SizedBox(
        width: 390,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label(context, caption),
            if (withBackBar)
              GenesisBackAppBar(pageName: '', onBack: () {})
            else
              const SizedBox(height: 64),
            Expanded(
              child: UserProfileContent(
                data: _profile(isSelf: isSelf),
                originsListenable: _origins(),
                worldsListenable: _worlds(),
                appearance: UserProfileAppearance.worldoMe,
              ),
            ),
          ],
        ),
      );
    }

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    panel(context, 'ME  (9k)', isSelf: true, withBackBar: false),
                    Container(
                      width: 12,
                      color: context.genesisColors.surfaceSoft,
                    ),
                    panel(
                      context,
                      'USER INFO  (other user)',
                      isSelf: false,
                      withBackBar: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Asset decoding needs a real async gap; fake-async pumps never finish it.
    await tester.runAsync(() async {
      for (final cover in _covers) {
        await precacheImage(
          AssetImage(cover),
          tester.element(find.byType(Row).first),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await expectLater(
      find.byKey(const ValueKey<String>('compare')),
      matchesGoldenFile('preview/user_info_vs_me.png'),
    );
  });
}
