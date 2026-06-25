import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genesis_flutter_android/components/me/user_profile_content.dart';
import 'package:genesis_flutter_android/pages/me/me_page.dart';
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

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worldo'));
    await tester.pumpAndSettle();

    expect(selectedIndexes, <int>[1, 0]);
  });
}
