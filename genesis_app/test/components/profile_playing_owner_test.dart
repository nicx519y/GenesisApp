import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/me/user_profile_library.dart';

void main() {
  for (final isSelf in [true, false]) {
    testWidgets(
      '${isSelf ? 'Me' : 'Profile'} hides only its own Playing owner',
      (tester) async {
        tester.view.physicalSize = const Size(500, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserProfileContent(
                worldTabLabel: 'Playing',
                data: UserProfileData(
                  avatarUrl: '',
                  displayName: 'Same Name',
                  uid: 'u_profile',
                  followingCount: 0,
                  followerCount: 0,
                  isSelf: isSelf,
                  origins: const [],
                  worlds: [
                    _world('w_owned', 'u_profile', 'Same Name'),
                    _world('w_other', 'u_other', 'Same Name'),
                    _world('w_unknown', '', 'Unknown Owner'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Playing'));
        await tester.pumpAndSettle();
        final owned = find.text('WID: w_owned');
        final other = find.text('WID: w_other');
        expect(owned, findsOneWidget);
        expect(other, findsOneWidget);
        expect(find.text('Owner: Same Name'), findsOneWidget);
        expect(find.text('Owner: Unknown Owner'), findsOneWidget);
        final worldPage = find.byKey(
          const ValueKey<String>('profile-world-collection-page'),
        );
        final content = find.descendant(
          of: worldPage,
          matching: find.byType(Text),
        );
        final labels = tester
            .widgetList<Text>(content)
            .map((text) => text.data)
            .toList();
        expect(
          labels.indexOf('Owner: Same Name'),
          greaterThan(labels.indexOf('WID: w_other')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

UserProfileWorldItem _world(String wid, String ownerUid, String ownerName) {
  return UserProfileWorldItem(
    wid: wid,
    title: wid,
    subtitle: 'WID: $wid\nOwner: $ownerName',
    imageUrl: '',
    progressCount: 1,
    interactCount: 2,
    characterCount: 3,
    playerCount: 1,
    ownerName: ownerName,
    ownerUid: ownerUid,
  );
}
