import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/mock_data/mock_v1_data.dart';

void main() {
  test('local mock supports origin world and chat flow', () async {
    final api = GenesisApi(useMock: true);

    await api.bindDevice(did: 'device_mock_1');

    final search = await api.search(query: 'steam', limit: 20);
    expect(search.origins.isNotEmpty, true);

    final origins = await api.getOrigins(limit: 20, offset: 0);
    expect(origins.data.isNotEmpty, true);

    final firstOrigin = origins.data.first;
    final detail = await api.getOrigin(firstOrigin.oid);
    expect(detail.name.isNotEmpty, true);
    expect(detail.worldMap, kMockV1SteamMapImage);
    expect(
      detail.locationTree.first.value.mapUrl,
      kMockV1LocationCentralHubMap,
    );
    expect(detail.locationTree.map((node) => node.id), [
      'loc_hub',
      'loc_gate',
      'loc_market',
      'loc_canal',
    ]);
    final originRootsById = {
      for (final node in detail.locationTree) node.id: node,
    };
    expect(originRootsById['loc_hub']!.children.map((node) => node.id), [
      'loc_clocktower',
      'loc_dispatch_hall',
      'loc_pressure_garden',
    ]);
    expect(originRootsById['loc_gate']!.children.map((node) => node.id), [
      'loc_airdock',
      'loc_switchyard',
      'loc_customs_house',
    ]);
    expect(originRootsById['loc_market']!.children.map((node) => node.id), [
      'loc_underworks',
      'loc_battery_exchange',
      'loc_parts_arcade',
    ]);
    expect(originRootsById['loc_canal']!.children.map((node) => node.id), [
      'loc_signal_workshop',
      'loc_pump_gallery',
      'loc_water_basin',
    ]);
    expect(
      detail.locationTree
          .expand((root) => root.children)
          .expand((node) => node.children)
          .map((node) => node.depth)
          .toSet(),
      {2},
    );
    for (final root in detail.locationTree) {
      expect(root.children.length, inInclusiveRange(2, 3));
    }

    final world = await api.launchWorld(
      originId: firstOrigin.id,
      worldviewId: firstOrigin.oid,
      worldName: firstOrigin.name,
    );
    expect(world.wid.isNotEmpty, true);

    final worldDetail = await api.getWorld(world.wid);
    expect(worldDetail.worldLocations.isNotEmpty, true);
    expect(worldDetail.origin.worldMap, kMockV1SteamMapImage);
    expect(
      worldDetail.worldLocationTree.first.value['map_url'],
      kMockV1LocationCentralHubMap,
    );
    expect(worldDetail.worldLocationTree.map((node) => node.id), [
      'loc_hub',
      'loc_gate',
      'loc_market',
      'loc_canal',
    ]);
    final worldRootsById = {
      for (final node in worldDetail.worldLocationTree) node.id: node,
    };
    expect(worldRootsById['loc_hub']!.children.map((node) => node.id), [
      'loc_clocktower',
      'loc_dispatch_hall',
      'loc_pressure_garden',
    ]);
    expect(worldRootsById['loc_gate']!.children.map((node) => node.id), [
      'loc_airdock',
      'loc_switchyard',
      'loc_customs_house',
    ]);
    expect(worldRootsById['loc_market']!.children.map((node) => node.id), [
      'loc_underworks',
      'loc_battery_exchange',
      'loc_parts_arcade',
    ]);
    expect(worldRootsById['loc_canal']!.children.map((node) => node.id), [
      'loc_signal_workshop',
      'loc_pump_gallery',
      'loc_water_basin',
    ]);
    expect(
      worldDetail.worldLocationTree
          .expand((root) => root.children)
          .expand((node) => node.children)
          .map((node) => node.depth)
          .toSet(),
      {2},
    );
    for (final root in worldDetail.worldLocationTree) {
      expect(root.children.length, inInclusiveRange(2, 3));
    }

    final before = await api.getLocationMessages(
      wid: world.wid,
      pointId: 'pt_hub',
      locationId: 'loc_hub',
      limit: 50,
      offset: 0,
    );

    await api.sendMessage(
      wid: world.wid,
      pointId: 'pt_hub',
      locationId: 'loc_hub',
      content: 'hello from mock',
    );

    final after = await api.getLocationMessages(
      wid: world.wid,
      pointId: 'pt_hub',
      locationId: 'loc_hub',
      limit: 50,
      offset: 0,
    );

    expect(after.data.length >= before.data.length, true);
    expect(after.data.first.content.isNotEmpty, true);
  });

  test('local mock supports v1 debug API surface', () async {
    final api = GenesisApi(useMock: true);

    final user = await api.v1.user.info();
    expect((user['user'] as Map)['uid'], 'u_mock_001');
    final peer = await api.v1.user.info(uid: 'u_mock_peer');
    expect((peer['user'] as Map)['uid'], 'u_mock_peer');
    final dmPeer = await api.v1.user.info(uid: 'u_mock_dm_002');
    expect((dmPeer['user'] as Map)['uid'], 'u_mock_dm_002');
    expect((dmPeer['user'] as Map)['name'], 'DM Contact 2');
    await api.v1.user.googleAuth(idToken: 'google-token');
    await api.v1.user.appleAuth(idToken: 'apple-token', fullName: 'Mock User');
    await api.v1.user.update(name: 'Mock User');
    await api.v1.user.profile(uid: 'u_mock_peer');
    await api.v1.user.origins(uid: 'u_mock_001');
    await api.v1.user.worlds(uid: 'u_mock_001');

    final home = await api.v1.home.home();
    expect(((home['my_world'] as Map)['list'] as List).isNotEmpty, true);
    await api.v1.home.following(pn: 2, rn: 10);

    final origins = await api.v1.origin.list(scene: 'foryou', pn: 1, rn: 10);
    expect(origins['total'], greaterThanOrEqualTo(100));
    expect((origins['list'] as List), hasLength(10));
    final firstOriginStats =
        (((origins['list'] as List).first as Map)['stats'] as Map);
    expect(firstOriginStats['copy_cnt'], greaterThanOrEqualTo(1000));
    expect(firstOriginStats['connect_cnt'], greaterThanOrEqualTo(1000000));
    final firstOriginName =
        ((((origins['list'] as List)[0] as Map)['info'] as Map)['origin_name']);
    final secondOriginName =
        ((((origins['list'] as List)[1] as Map)['info'] as Map)['origin_name']);
    expect(firstOriginName, isNot(secondOriginName));
    final laterOrigins = await api.v1.origin.list(pn: 2, rn: 10);
    final laterOrigin =
        (((laterOrigins['list'] as List).last as Map)['info'] as Map);
    final laterOriginId = laterOrigin['origin_id'] as String;
    final laterOriginDiscussions = await api.v1.discuss.list(
      bizId: laterOriginId,
      rn: 2,
    );
    final laterDiscussionItems = laterOriginDiscussions['list'] as List;
    expect(laterDiscussionItems, hasLength(2));
    expect(
      ((laterDiscussionItems.first as Map)['comment'] as Map)['biz_id'],
      laterOriginId,
    );
    expect(
      ((laterDiscussionItems.first as Map)['latest_replies'] as List),
      isNotEmpty,
    );

    final origin =
        (((origins['list'] as List).first as Map)['info'] as Map)['origin_id']
            as String;
    final detail = await api.v1.origin.detail(oid: origin);
    expect(((detail['stats'] as Map)['copy_cnt']), greaterThanOrEqualTo(1000));
    expect((detail['characters'] as List).isNotEmpty, true);
    final created = await api.v1.origin.create(
      name: 'Created Mock Origin',
      worldView: 'Created from a local mock test.',
      cover: '',
      characterList: const [],
    );
    final createdOrigin = (created['origin'] as Map)['oid'] as String;
    await api.v1.origin.update(oid: createdOrigin, name: 'Updated Mock Origin');
    await api.v1.origin.launch(oid: createdOrigin);
    await api.v1.origin.versionList(oid: createdOrigin);
    await api.v1.origin.publish(oid: createdOrigin, updateNotes: 'publish');

    final worlds = await api.v1.world.list(scene: 'popular', pn: 1, rn: 10);
    expect(worlds['total'], greaterThanOrEqualTo(100));
    expect((worlds['list'] as List), hasLength(10));
    final firstWorldStats =
        (((worlds['list'] as List).first as Map)['stats'] as Map);
    expect(firstWorldStats['tick_cnt'], greaterThanOrEqualTo(1000));
    expect(firstWorldStats['connect_cnt'], greaterThanOrEqualTo(1000));
    final myWorlds = await api.v1.world.list(uid: 'u_mock_001', pn: 1, rn: 10);
    expect(myWorlds['total'], greaterThan(0));
    for (final item in myWorlds['list'] as List) {
      expect(((item as Map)['info'] as Map)['owner_uid'], 'u_mock_001');
    }
    final firstWorldName =
        ((((worlds['list'] as List)[0] as Map)['info'] as Map)['world_name']);
    final secondWorldName =
        ((((worlds['list'] as List)[1] as Map)['info'] as Map)['world_name']);
    expect(firstWorldName, isNot(secondWorldName));
    final world =
        (((worlds['list'] as List).first as Map)['info'] as Map)['world_id']
            as String;
    final worldDetail = await api.v1.world.detail(wid: world);
    expect(
      ((worldDetail['stats'] as Map)['tick_cnt']),
      greaterThanOrEqualTo(1000),
    );
    final detailTicks = worldDetail['ticks'] as List;
    expect(detailTicks.length, greaterThanOrEqualTo(4));
    final detailLocations = worldDetail['locations'] as List;
    final firstDetailLocation = detailLocations.first as Map;
    expect(firstDetailLocation['map_url'], kMockV1LocationCentralHubMap);
    expect(firstDetailLocation.containsKey('map'), isFalse);
    expect([
      for (final tick in detailTicks)
        ((tick as Map)['tick_index'] as num).toInt(),
    ], List<int>.generate(detailTicks.length, (index) => index + 1));
    await api.v1.world.requestJoin(wid: world);
    await api.v1.world.auditRequest(
      requestId: 'request_mock_1',
      action: 'approve',
    );
    await api.v1.world.join(wid: world);
    await api.v1.world.tick(worldId: world);
    await api.v1.world.syncLatestOrigin(wid: world);

    var unreadSummary = await api.v1.messages.unreadSummary();
    expect(unreadSummary.systemUnread, 1);
    final systemMessages = await api.v1.messages.notifications(
      category: 'system',
      pn: 1,
      rn: 20,
    );
    expect(systemMessages['total'], 1);
    expect(
      ((systemMessages['list'] as List).single as Map)['category'],
      'system',
    );
    final followerMessages = await api.v1.messages.notifications(
      category: 'follower',
      pn: 1,
      rn: 20,
    );
    expect(
      ((followerMessages['list'] as List).single as Map)['category'],
      'follower',
    );
    final commentMessages = await api.v1.messages.notifications(
      category: 'comment',
      pn: 1,
      rn: 20,
    );
    expect(
      ((commentMessages['list'] as List).single as Map)['category'],
      'comment',
    );
    await api.v1.messages.markNotificationsRead(category: 'system');
    unreadSummary = await api.v1.messages.unreadSummary();
    expect(unreadSummary.systemUnread, 0);
    expect(unreadSummary.followerUnread, 1);
    expect(unreadSummary.commentUnread, 1);
    await api.v1.messages.followers(pn: 2, rn: 10);

    await api.v1.follow.follow(uid: 'u_mock_peer');
    await api.v1.follow.unfollow(uid: 'u_mock_peer');
    final following = await api.v1.follow.following(
      uid: 'u_mock_001',
      pn: 1,
      rn: 10,
    );
    final followingList = following['list'] as List;
    expect(following['total'], greaterThan(10));
    expect(followingList, hasLength(10));
    expect((followingList.first as Map)['user'], isA<Map>());

    final followers = await api.v1.follow.followers(
      uid: 'u_mock_001',
      pn: 1,
      rn: 10,
    );
    final followersList = followers['list'] as List;
    expect(followers['total'], greaterThan(10));
    expect(followersList, hasLength(10));
    expect((followersList.first as Map)['relation'], isA<Map>());
    await api.v1.follow.relations(type: 'followers', pn: 1, rn: 10);
    await api.v1.follow.status(uids: const ['u_mock_peer']);

    final dm = await api.v1.dm.send(
      peerUid: 'u_mock_peer',
      content: 'hello v1 mock',
    );
    expect(((dm['message'] as Map)['content']), 'hello v1 mock');
    final conversations = await api.v1.dm.conversations(pn: 1, rn: 10);
    expect(conversations['total'], greaterThan(20));
    final firstConversation = (conversations['list'] as List).first as Map;
    expect(firstConversation, contains('conv_id'));
    expect(firstConversation, contains('last_message_id'));
    expect(firstConversation['last_message_at'], isA<int>());
    final firstConversationPeer = firstConversation['peer'] as Map;
    expect(firstConversationPeer['last_login_at'], isA<int>());
    expect(firstConversationPeer['create_at'], isA<int>());
    expect(conversations['next_after_message_id'], isA<String>());
    final deltaConversations = await api.v1.dm.conversations(
      afterMessageId: '${conversations['next_after_message_id']}',
    );
    final deltaList = deltaConversations['list'] as List;
    expect(deltaList, isNotEmpty);
    expect(
      deltaConversations['next_after_message_id'],
      isNot(conversations['next_after_message_id']),
    );
    final defaultConversations = await api.v1.dm.conversations();
    expect(defaultConversations['rn'], 20);
    expect(defaultConversations['list'], hasLength(20));
    final cappedConversations = await api.v1.dm.conversations(pn: 1, rn: 500);
    expect(cappedConversations['rn'], 100);
    final secondPageConversations = await api.v1.dm.conversations(
      pn: 2,
      rn: 10,
    );
    expect(secondPageConversations['list'], isNotEmpty);
    final directMessages = await api.v1.dm.list(
      peerUid: 'u_mock_peer',
      pn: 1,
      rn: 20,
    );
    final firstMessage = (directMessages['list'] as List).first as Map;
    expect(firstMessage['created_at'], isA<int>());
    final otherPeerMessages = await api.v1.dm.list(
      peerUid: 'u_mock_dm_002',
      pn: 1,
      rn: 5,
    );
    expect(otherPeerMessages['list'], hasLength(1));
    expect(
      ((otherPeerMessages['list'] as List).first as Map)['sender_uid'],
      isNotEmpty,
    );
    final twoMessagePeerMessages = await api.v1.dm.list(
      peerUid: 'u_mock_dm_003',
      pn: 1,
      rn: 5,
    );
    expect(twoMessagePeerMessages['list'], hasLength(2));
    expect(
      ((twoMessagePeerMessages['list'] as List).first as Map)['content'],
      'Second short mock reply.',
    );
    final shortConversation = (defaultConversations['list'] as List)
        .cast<Map>()
        .firstWhere(
          (item) => ((item['peer'] as Map)['uid']) == 'u_mock_dm_002',
        );
    expect(
      shortConversation['last_message'],
      'One-message mock chat with DM Contact 2.',
    );
    var dmUnread = await api.v1.dm.unread();
    expect(dmUnread['unread_cnt'], greaterThanOrEqualTo(0));
    await api.v1.dm.markRead(peerUid: 'u_mock_peer');
    dmUnread = await api.v1.dm.unread();
    expect(dmUnread['unread_cnt'], 0);
    await api.v1.dm.block(targetUid: 'u_mock_peer');
    var blocks = await api.v1.dm.blocks(pn: 1, rn: 20);
    expect((blocks['list'] as List).single, containsPair('uid', 'u_mock_peer'));
    await api.v1.dm.unblock(targetUid: 'u_mock_peer');
    blocks = await api.v1.dm.blocks(pn: 1, rn: 20);
    expect(blocks['list'], isEmpty);

    final newPost = await api.v1.discuss.post(
      bizId: createdOrigin,
      content: 'mock post',
    );
    final postId = newPost['discuss_id'] as String;
    await api.v1.discuss.post(
      bizId: createdOrigin,
      content: 'mock reply',
      rootDiscussId: postId,
    );
    final discussions = await api.v1.discuss.list(bizId: createdOrigin);
    final discussionItems = discussions['list'] as List;
    expect(discussionItems.length, 1);
    final firstDiscussion = discussionItems.first as Map;
    expect((firstDiscussion['comment'] as Map)['discuss_id'], postId);
    expect((firstDiscussion['latest_replies'] as List).length, 1);
    expect(discussions['top_total'], 1);
    expect(discussions['total_all'], 2);
    await api.v1.discuss.like(discussId: postId);
    await api.v1.discuss.unlike(discussId: postId);
    await api.v1.discuss.delete(discussId: postId);

    final search = await api.v1.search.search(query: 'steam');
    expect((search['groups'] as List).isNotEmpty, true);
    await api.v1.search.suggest(query: 'steam', limit: 10);

    final rebornSearch = await api.v1.search.search(
      query: '重生',
      type: 'all',
      pn: 1,
      rn: 20,
    );
    final rebornGroups = (rebornSearch['groups'] as List).cast<Map>();
    final rebornOrigins = rebornGroups.firstWhere(
      (group) => group['type'] == 'origin',
    );
    final rebornWorlds = rebornGroups.firstWhere(
      (group) => group['type'] == 'world',
    );
    expect(rebornOrigins['total'], greaterThan(0));
    expect(rebornOrigins['list'] as List, isNotEmpty);
    expect(rebornWorlds['total'], greaterThan(0));
    expect(rebornWorlds['list'] as List, isNotEmpty);

    final userSearch = await api.v1.search.search(
      query: '老肖',
      type: 'user',
      pn: 1,
      rn: 20,
    );
    final userSearchGroup = (userSearch['groups'] as List)
        .cast<Map>()
        .firstWhere((group) => group['type'] == 'user');
    expect(userSearchGroup['total'], greaterThan(0));
    expect(userSearchGroup['list'] as List, isNotEmpty);

    final searchAllPage1 = await api.v1.search.search(
      query: '',
      type: 'all',
      pn: 1,
      rn: 20,
    );
    final searchAllGroups = searchAllPage1['groups'] as List;
    for (final rawGroup in searchAllGroups) {
      final group = rawGroup as Map;
      expect(group['total'], greaterThanOrEqualTo(50));
      expect(group['list'] as List, hasLength(20));
    }
    final searchUserPage2 = await api.v1.search.search(
      query: '',
      type: 'user',
      pn: 2,
      rn: 20,
    );
    final userGroup = (searchUserPage2['groups'] as List)
        .cast<Map>()
        .firstWhere((group) => group['type'] == 'user');
    final originGroup = (searchUserPage2['groups'] as List)
        .cast<Map>()
        .firstWhere((group) => group['type'] == 'origin');
    expect(userGroup['total'], greaterThanOrEqualTo(50));
    expect(userGroup['list'] as List, hasLength(20));
    expect(originGroup['total'], 0);
    expect(originGroup['list'] as List, isEmpty);

    final upload = await api.v1.common.uploadFile(
      bytes: const [1, 2, 3],
      bizType: 'avatar',
    );
    expect(upload['file_url'], isNotEmpty);
    final imageUpload = await api.v1.upload.image(
      bytes: const [255, 216, 255, 224],
      filename: 'avatar.jpg',
      contentType: 'image/jpeg',
    );
    expect(imageUpload['url'], startsWith('https://mock.local/uploads/'));
    expect(imageUpload['object_key'], startsWith('uploads/'));
    final draft = await api.v1.common.saveDraft(
      draftType: 'origin_create',
      draftData: const {'name': 'draft'},
    );
    await api.v1.common.readDraft(draftType: 'origin_create');
    await api.v1.common.deleteDraft(draftId: draft['draft_id'] as String);
    await api.v1.common.registerDevice(
      deviceId: 'device_mock_1',
      platform: 'android',
    );
  });
}
