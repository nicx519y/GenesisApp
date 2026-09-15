import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/json_utils.dart';
import 'package:genesis_flutter_android/network/models/user.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/network/models/search_v2.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/direct_message_conversation_store.dart';
import 'package:genesis_flutter_android/components/discuss/origin_discuss_library.dart';
import 'package:genesis_flutter_android/components/me/user_profile_library.dart';

void main() {
  const userJson = <String, dynamic>{
    'uid': 'u_1',
    'name': 'User',
    'user_id': 'u_1',
    'user_name': 'User',
    'gender': 'Non_binary',
    'age': '35-44',
    'membership_status': 1,
  };
  test(
    'all public user DTOs retain optional demographic and membership fields',
    () {
      final user = User.fromJson(userJson);
      final owner = OriginUserInfo.fromJson(userJson);
      final searchUser = SearchV2UserItem.fromJson(userJson);
      final searchOwner = SearchV2Owner.fromJson(userJson);
      final worldMember = WorldMember.fromJson(userJson);
      final locationUser = ChatroomLocationUser.fromJson(userJson);
      final onlineUser = ChatroomOnlineUser.fromPayload(userJson);
      for (final value in [
        (user.gender, user.age, user.membershipStatus),
        (owner.gender, owner.age, owner.membershipStatus),
        (searchUser.gender, searchUser.age, searchUser.membershipStatus),
        (searchOwner.gender, searchOwner.age, searchOwner.membershipStatus),
        (worldMember.gender, worldMember.age, worldMember.membershipStatus),
        (locationUser.gender, locationUser.age, locationUser.membershipStatus),
        (onlineUser.gender, onlineUser.age, onlineUser.membershipStatus),
      ]) {
        expect(value, ('Non_binary', '35-44', 1));
      }
    },
  );
  test('invalid or missing membership status cannot grant a badge', () {
    for (final raw in <Object?>[null, '1', true, 1.0, -1, 3, {}]) {
      expect(asUserMembershipStatus(raw), 0);
      expect(
        SearchV2UserItem.fromJson({
          'uid': 'u',
          'membership_status': raw,
        }).membershipStatus,
        0,
      );
    }
    expect(User.fromJson({}).gender, '');
    expect(OriginUserInfo.fromJson({}).age, '');
    expect(asUserMembershipStatus(2), 2);
  });
  test('world, comment and profile copies retain their user metadata', () {
    final world = WorldDetail.fromJson({
      'owner_user': userJson,
    }).copyWith(name: 'Updated');
    expect(world.ownerUser.membershipStatus, 1);
    expect(world.ownerUser.gender, 'Non_binary');
    expect(world.ownerUser.age, '35-44');
    final comment = OriginDiscussListItem.fromJson({
      'author': userJson,
    }).copyWith(likeCount: 2);
    expect(
      (comment.authorGender, comment.authorAge, comment.authorMembershipStatus),
      ('Non_binary', '35-44', 1),
    );
    final profile = UserProfileData(
      avatarUrl: '',
      displayName: 'User',
      uid: 'u_1',
      followingCount: 0,
      followerCount: 0,
      origins: [],
      worlds: [],
      gender: 'Non_binary',
      age: '35-44',
      membershipStatus: 1,
    ).copyWith(displayName: 'Updated');
    expect(
      (profile.gender, profile.age, profile.membershipStatus),
      ('Non_binary', '35-44', 1),
    );
    expect(profile.copyWith(membershipStatus: 0).membershipStatus, 0);
  });
  test('private conversation cache roundtrip retains peer metadata', () {
    final message = DirectMessageConversationRecord.fromJson({
      'conv_id': 'c_1',
      'peer': userJson,
    });
    final cached = DirectMessageConversationRecord.fromJson(
      asJsonMap(jsonDecode(message.rawJson)),
    );
    expect(
      (cached.peerGender, cached.peerAge, cached.peerMembershipStatus),
      ('Non_binary', '35-44', 1),
    );
  });
}
