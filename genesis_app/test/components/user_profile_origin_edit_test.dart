import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/me/user_profile_content.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

UserProfileData _profile({required bool isSelf}) => UserProfileData(
  avatarUrl: '',
  displayName: 'Eve',
  uid: 'u_A7BN1K',
  followingCount: 1,
  followerCount: 2,
  isSelf: isSelf,
  isFollowed: false,
  origins: const [],
  worlds: const [],
);

ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>> _origins() {
  return ValueNotifier(
    const UserProfileCollectionState<UserProfileOriginItem>(
      isLoading: false,
      total: 1,
      items: [
        UserProfileOriginItem(
          originId: 7,
          oid: 'o_7F2KQ0',
          title: 'Old Money',
          subtitle: 'OID: o_7F2KQ0  Originator: Redstorm',
          imageUrl: '',
          copyCount: 12,
          interactCount: 34,
          characterCount: 5,
        ),
      ],
    ),
  );
}

Future<List<RouteSettings>> _pumpProfile(
  WidgetTester tester, {
  required bool isSelf,
}) async {
  final pushed = <RouteSettings>[];
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name != '/') pushed.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: settings.name == '/'
                ? UserProfileContent(
                    data: _profile(isSelf: isSelf),
                    originsListenable: _origins(),
                    worldsListenable: ValueNotifier(
                      const UserProfileCollectionState<UserProfileWorldItem>(
                        isLoading: false,
                        total: 0,
                        items: [],
                      ),
                    ),
                    appearance: UserProfileAppearance.worldoMe,
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}

void main() {
  testWidgets('edit entry opens the edit route with the oid', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final pushed = await _pumpProfile(tester, isSelf: true);
    final glyph = find.byKey(
      const ValueKey<String>('profile-origin-edit-entry'),
    );
    expect(glyph, findsOneWidget);
    expect(tester.getSize(glyph), const Size(12, 12));
    expect(
      tester.getRect(glyph).bottom,
      tester.getRect(find.text('Old Money')).bottom,
      reason: 'the glyph sits exactly on the title bottom edge',
    );

    final target = find.byKey(
      const ValueKey<String>('profile-collection-title-trailing-tap'),
    );
    expect(tester.getSize(target), const Size(44, 44));
    expect(
      tester.getRect(target).contains(tester.getRect(glyph).center),
      isTrue,
      reason: 'the touch square covers the glyph',
    );
    expect(
      tester
          .getSize(find.byType(GenesisProfileCollectionListItem).first)
          .height,
      78,
      reason: 'the touch square costs width, never row height',
    );

    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(pushed.map((s) => s.name), [RouteNames.edit]);
    expect(
      (pushed.single.arguments! as Map)['origin_id'],
      'o_7F2KQ0',
      reason: 'the edit page is addressed by oid',
    );
  });

  testWidgets('tapping the row still opens the Worldo', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final pushed = await _pumpProfile(tester, isSelf: true);
    await tester.tap(find.text('Old Money'));
    await tester.pumpAndSettle();

    expect(pushed.map((s) => s.name), [RouteNames.originWorld]);
  });

  testWidgets('another user profile has no edit entry', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpProfile(tester, isSelf: false);
    expect(
      find.byKey(const ValueKey<String>('profile-origin-edit-entry')),
      findsNothing,
    );
  });
}
