import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/components/me/user_profile_content.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/pages/me/me_page.dart';
import 'package:genesis_flutter_android/ui/components/genesis_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_fixed_underline_indicator.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/utils/entity_deleted.dart';

void main() {
  test('empty backend name and avatar render uid and default avatar', () {
    const current = UserProfileData(
      avatarUrl: 'https://cdn.example.com/old_avatar.webp',
      displayName: 'Cached User',
      uid: 'u_cached',
      followingCount: 7,
      followerCount: 11,
      origins: <UserProfileOriginItem>[],
      worlds: <UserProfileWorldItem>[],
    );

    final next = mergeRemoteUserInfoForRenderForTest(current, {
      'uid': 'u_backend',
      'name': '',
      'avatar': {'sm_url': '', 'xl_url': '', 'object_key': ''},
      'following_cnt': 7,
      'follower_cnt': 11,
    });

    expect(next.displayName, 'u_backend');
    expect(next.avatarUrl, '');
  });

  test('deleted backend user renders deleted for name and uid', () {
    const current = UserProfileData(
      avatarUrl: 'https://cdn.example.com/old_avatar.webp',
      displayName: 'Cached User',
      uid: 'u_cached',
      followingCount: 7,
      followerCount: 11,
      origins: <UserProfileOriginItem>[],
      worlds: <UserProfileWorldItem>[],
    );

    final next = mergeRemoteUserInfoForRenderForTest(current, {
      'uid': 'u_backend',
      'name': '',
      'avatar': {'sm_url': '', 'xl_url': '', 'object_key': ''},
      'deleted': true,
      'following_cnt': 7,
      'follower_cnt': 11,
    });

    expect(next.deleted, isTrue);
    expect(next.displayName, deletedEntityDisplayText);
    expect(next.uid, deletedEntityDisplayText);
  });

  testWidgets('profile collection tabs report selected tab index', (
    tester,
  ) async {
    final selectedIndexes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserProfileContent(
            data: const UserProfileData(
              avatarUrl: '',
              displayName: 'User',
              uid: 'u_user',
              followingCount: 0,
              followerCount: 0,
              origins: <UserProfileOriginItem>[],
              worlds: <UserProfileWorldItem>[],
            ),
            onCollectionTabChanged: selectedIndexes.add,
          ),
        ),
      ),
    );

    expect(find.text('No Worldo you created yet.'), findsOneWidget);
    expect(find.text('No Worldos you created yet.'), findsNothing);
    final gemBalance = tester.widget<Text>(
      find.byKey(const ValueKey('user-profile-gems-balance')),
    );
    expect(gemBalance.data, '0');
    expect(gemBalance.style?.fontWeight, FontWeight.w600);
    expect(find.text('--'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('user-profile-gem-icon'))),
      const Size.square(24),
    );

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#Worldo'));
    await tester.pumpAndSettle();

    expect(selectedIndexes, <int>[1, 0]);
  });

  testWidgets('self profile shows Gems balance entry and opens wallet', (
    tester,
  ) async {
    String? openedRoute;
    final walletState = ValueNotifier<GemWalletState>(
      const GemWalletState(ownerUid: 'u_user', balance: 430),
    );
    addTearDown(walletState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          openedRoute = settings.name;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          body: UserProfileContent(
            data: const UserProfileData(
              avatarUrl: '',
              displayName: 'User',
              uid: 'u_user',
              followingCount: 12,
              followerCount: 34,
              origins: <UserProfileOriginItem>[],
              worlds: <UserProfileWorldItem>[],
            ),
            gemWalletStateListenable: walletState,
          ),
        ),
      ),
    );

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('user-profile-gems-entry')),
      findsOneWidget,
    );
    expect(find.text('430'), findsOneWidget);
    expect(find.text('Gems'), findsOneWidget);

    walletState.value = const GemWalletState(ownerUid: 'u_user', balance: 520);
    await tester.pump();

    expect(find.text('520'), findsOneWidget);
    expect(find.text('430'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('user-profile-gems-entry')));
    await tester.pumpAndSettle();

    expect(openedRoute, '/gems');
  });

  testWidgets('Worldo Me appearance matches the redesigned profile layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selectedIndexes = <int>[];
    final walletState = ValueNotifier<GemWalletState>(
      const GemWalletState(ownerUid: 'u_eve', balance: 483),
    );
    const originItem = UserProfileOriginItem(
      originId: 1,
      oid: 'o_7F2KQ9',
      title: 'Old Money',
      subtitle: 'OID: o_7F2KQ9\nLatest Version: V1',
      imageUrl: '',
      copyCount: 1200,
      interactCount: 86000,
      characterCount: 5,
    );
    final originsState = ValueNotifier(
      const UserProfileCollectionState<UserProfileOriginItem>(
        items: <UserProfileOriginItem>[originItem],
        isLoading: false,
        total: 8,
      ),
    );
    final worldsState = ValueNotifier(
      const UserProfileCollectionState<UserProfileWorldItem>(
        items: <UserProfileWorldItem>[
          UserProfileWorldItem(
            wid: 'w_0VXGEE',
            title: 'Test World',
            subtitle: 'WID: w_0VXGEE  Owner: Eve',
            imageUrl: '',
            progressCount: 1,
            interactCount: 2,
            characterCount: 3,
            playerCount: 4,
            ownerName: 'Eve',
          ),
        ],
        isLoading: false,
        total: 3,
      ),
    );
    addTearDown(walletState.dispose);
    addTearDown(originsState.dispose);
    addTearDown(worldsState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: UserProfileContent(
            appearance: UserProfileAppearance.worldoMe,
            data: const UserProfileData(
              avatarUrl: '',
              displayName: 'Eve',
              uid: 'u_A7BN1K',
              followingCount: 1,
              followerCount: 2,
              origins: <UserProfileOriginItem>[originItem],
              worlds: <UserProfileWorldItem>[
                UserProfileWorldItem(
                  wid: 'w_0VXGEE',
                  title: 'Test World',
                  subtitle: 'WID: w_0VXGEE  Owner: Eve',
                  imageUrl: '',
                  progressCount: 1,
                  interactCount: 2,
                  characterCount: 3,
                  playerCount: 4,
                  ownerName: 'Eve',
                ),
              ],
            ),
            originsListenable: originsState,
            worldsListenable: worldsState,
            gemWalletStateListenable: walletState,
            onCollectionTabChanged: selectedIndexes.add,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Creation 8'), findsOneWidget);
    expect(find.text('Playing 3'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Top up'), findsOneWidget);
    expect(
      tester.getSize(find.byType(GenesisAvatarFallback)),
      const Size.square(72),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('worldo-me-profile-identity')),
          )
          .dy,
      12,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('user-profile-gem-icon'))),
      const Size(15, 23),
    );
    expect(tester.getSize(find.byType(GenesisListImage)), const Size(60, 78));
    final title = tester.widget<Text>(find.text('Old Money'));
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(_assetSvgFinder(originFeedPlayIconAsset), findsOneWidget);
    expect(_assetSvgFinder(originFeedCommentIconAsset), findsOneWidget);
    expect(_assetSvgFinder(originFeedRoleIconAsset), findsOneWidget);
    expect(_assetSvgFinder(copyStatIconAsset), findsNothing);
    expect(_assetSvgFinder(connectStatIconAsset), findsNothing);
    expect(_assetSvgFinder(characterStatIconAsset), findsNothing);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final indicator = tabBar.indicator! as GenesisFixedUnderlineIndicator;
    expect(indicator.width, isNull);
    expect(indicator.bottomPadding, 0);

    await tester.tap(find.text('Playing 3'));
    await tester.pumpAndSettle();
    expect(find.text('Test World'), findsOneWidget);
    expect(find.text('WID: w_0VXGEE'), findsOneWidget);
    expect(find.text('Owner: Eve'), findsOneWidget);
    expect(find.text('WID: w_0VXGEE  Owner: Eve'), findsNothing);
    expect(_assetSvgFinder(originFeedPlayIconAsset), findsOneWidget);
    expect(_assetSvgFinder(originFeedCommentIconAsset), findsOneWidget);
    expect(_assetSvgFinder(originFeedRoleIconAsset), findsOneWidget);
    expect(_assetSvgFinder(tickStatIconAsset), findsNothing);
    expect(_assetSvgFinder(connectStatIconAsset), findsNothing);
    expect(_assetSvgFinder(characterStatIconAsset), findsNothing);
    expect(_assetSvgFinder(userStatIconAsset), findsNothing);
    expect(find.text('4'), findsNothing);
    await tester.tap(find.text('Creation 8'));
    await tester.pumpAndSettle();

    expect(selectedIndexes, <int>[1, 0]);
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
