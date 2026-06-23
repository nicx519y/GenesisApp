import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/mock_data/mock_v1_data.dart';

void main() {
  test('local mock app version check defaults to no upgrade', () async {
    final api = GenesisApi(useMock: true);

    final response = await api.v1.app.versionCheck(
      appId: 'aitown',
      platform: 'android',
      channel: 'default',
      versionCode: 1,
    );

    expect(response.needUpgrade, false);
    expect(response.forceUpgrade, false);
    expect(response.shouldForceUpgrade, false);
  });

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
    expect(detail.locationTree.map((node) => node.id), [
      'loc_hub',
      'loc_gate',
      'loc_market',
      'loc_canal',
    ]);
    expect(
      detail.processedLocationTree.renderRoots.first.value.mapUrl,
      kMockV1LocationCentralHubMap,
    );
    expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
      'loc_hub',
      'loc_gate',
      'loc_market',
      'loc_canal',
    ]);
    final originRootsById = {
      for (final node in detail.processedLocationTree.renderRoots)
        node.id: node,
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
          .expand((node) => node.children)
          .expand((node) => node.children)
          .map((node) => node.depth)
          .toSet(),
      {2},
    );
    for (final root in detail.processedLocationTree.renderRoots) {
      expect(root.children.length, inInclusiveRange(2, 3));
    }

    final world = await api.launchWorld(
      originId: firstOrigin.id,
      worldviewId: firstOrigin.oid,
      worldName: firstOrigin.name,
    );
    expect(world.wid.isNotEmpty, true);

    final worldDetail = await api.getWorld(world.wid);
    expect(worldDetail.locations.isNotEmpty, true);
    expect(worldDetail.origin.worldMap, kMockV1SteamMapImage);
    expect(worldDetail.locationTree.map((node) => node.id), [
      'loc_hub',
      'loc_gate',
      'loc_market',
      'loc_canal',
    ]);
    expect(
      worldDetail.processedLocationTree.renderRoots.first.value['map_url'],
      kMockV1LocationCentralHubMap,
    );
    expect(
      worldDetail.processedLocationTree.renderRoots.map((node) => node.id),
      ['loc_hub', 'loc_gate', 'loc_market', 'loc_canal'],
    );
    final worldRootsById = {
      for (final node in worldDetail.processedLocationTree.renderRoots)
        node.id: node,
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
      worldDetail.locationTree
          .expand((node) => node.children)
          .expand((node) => node.children)
          .map((node) => node.depth)
          .toSet(),
      {2},
    );
    for (final root in worldDetail.processedLocationTree.renderRoots) {
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
    await api.v1.user.deleteAccount();

    final hotTags = await api.v1.origin.hotTags();
    expect(hotTags, containsAll(<String>['校园', '恋爱', '玄幻', '都市', '冒险']));

    final popularOrigins = await api.v1.origin.list(pn: 1, rn: 10);
    final firstPopularOrigin = (popularOrigins['list'] as List).first as Map;
    expect(firstPopularOrigin['discusses'], isA<List>());
    expect(firstPopularOrigin['discusses'], hasLength(2));

    final uidOrigins = await api.v1.origin.list(
      scene: 'uid',
      uid: 'u_mock_001',
      pn: 1,
      rn: 10,
    );
    final firstUidOrigin = (uidOrigins['list'] as List).first as Map;
    expect(firstUidOrigin.containsKey('discusses'), isFalse);

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
      ((laterDiscussionItems.first as Map)['comment'] as Map)['world_id'],
      isNotEmpty,
    );
    expect(
      ((laterDiscussionItems.first as Map)['latest_replies'] as List),
      isNotEmpty,
    );

    final origin =
        (((origins['list'] as List).first as Map)['info'] as Map)['origin_id']
            as String;
    final detail = await api.v1.origin.detail(oid: origin);
    final detailInfo = detail['info'] as Map;
    expect(detailInfo['origin_id'], origin);
    expect(detailInfo['metric'], isA<Map>());
    expect(detailInfo['created_at'], isA<int>());
    expect(((detail['stats'] as Map)['copy_cnt']), greaterThanOrEqualTo(1000));
    expect((detail['characters'] as List).isNotEmpty, true);
    expect(
      ((detail['locations'] as List).first as Map),
      contains('location_description'),
    );
    expect(((detail['ticks'] as List).first as Map), contains('tick_result'));
    final edit = await api.v1.origin.forEdit(originId: origin);
    expect(edit['origin_id'], origin);
    expect(edit, contains('characters'));
    expect(edit, isNot(contains('stats')));
    expect(((edit['characters'] as List).first as Map), contains('bio'));
    final created = await api.v1.origin.create(
      originName: 'Created Mock Origin',
      brief: 'Created from a local mock test.',
      setting: 'Created from a local mock test.',
      cover: '',
      characters: const [],
    );
    final createdOrigin = (created['info'] as Map)['origin_id'] as String;
    await api.v1.origin.update(
      originId: createdOrigin,
      originName: 'Updated Mock Origin',
      cover: '',
      characters: const [],
    );
    await api.v1.origin.launch(
      oid: createdOrigin,
      presetCharacterId: 'char_mock_001',
    );
    await api.v1.origin.versionList(oid: createdOrigin);
    await api.v1.origin.publish(oid: createdOrigin, updateNotes: 'publish');

    final worlds = await api.v1.world.list(scene: 'popular', pn: 1, rn: 10);
    expect(worlds['total'], greaterThanOrEqualTo(100));
    expect((worlds['list'] as List), hasLength(10));
    final firstWorldStats =
        (((worlds['list'] as List).first as Map)['stats'] as Map);
    expect(firstWorldStats['tick_cnt'], greaterThanOrEqualTo(1000));
    expect(firstWorldStats['connect_cnt'], greaterThanOrEqualTo(1000));
    final myWorlds = await api.v1.world.list(
      scene: 'uid',
      uid: 'u_mock_001',
      pn: 1,
      rn: 10,
    );
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
    final worldDetail = await api.v1.world.detail(worldId: world);
    expect(
      ((worldDetail['stats'] as Map)['tick_cnt']),
      greaterThanOrEqualTo(1000),
    );
    final worldOrigin = ((worldDetail['info'] as Map)['origin_id']) as String;
    final summaryByOrigin = await api.v1.world.summaryLatest(
      originId: worldOrigin,
    );
    final summaryItems = summaryByOrigin['list'] as List;
    expect(summaryItems, isNotEmpty);
    expect(summaryItems.length, lessThanOrEqualTo(5));
    final summaryItem = summaryItems.first as Map;
    expect(summaryItem['origin_id'], worldOrigin);
    expect(summaryItem['world_id'], isNotEmpty);
    expect(summaryItem['summary'], isNotEmpty);
    expect(summaryItem['tick_no'], isA<int>());
    expect(summaryItem['tick_time'], isA<int>());
    expect(summaryItem['created_at'], isA<int>());
    final summaryByWorld = await api.v1.world.summaryLatest(worldId: world);
    for (final item in summaryByWorld['list'] as List) {
      expect((item as Map)['world_id'], isNot(world));
    }
    final facadeSummaries = await api.getLatestWorldSummaries(
      originId: worldOrigin,
    );
    expect(facadeSummaries.first.originId, worldOrigin);
    expect(facadeSummaries.first.summary, isNotEmpty);
    final originProgress = await api.v1.world.originProgress(
      uid: 'u_mock_001',
      originId: worldOrigin,
    );
    expect(originProgress['world_id'], isNotEmpty);
    expect(originProgress['tick_cnt'], greaterThanOrEqualTo(1000));
    final missingOriginProgress = await api.v1.world.originProgress(
      uid: 'u_missing',
      originId: worldOrigin,
    );
    expect(missingOriginProgress, {'world_id': '', 'tick_cnt': 0});
    final detailTicks = worldDetail['ticks'] as List;
    expect(detailTicks.length, greaterThanOrEqualTo(4));
    final detailLocations = worldDetail['locations'] as List;
    final firstDetailLocation = detailLocations.first as Map;
    expect(firstDetailLocation['map_url'], kMockV1LocationCentralHubMap);
    expect(firstDetailLocation.containsKey('map'), isFalse);
    expect([
      for (final tick in detailTicks) ((tick as Map)['tick_no'] as num).toInt(),
    ], List<int>.generate(detailTicks.length, (index) => index + 1));
    final tickList = await api.v1.world.tickList(worldId: world, pn: 1, rn: 2);
    expect(tickList['total'], detailTicks.length);
    expect(tickList['pn'], 1);
    expect(tickList['rn'], 2);
    final tickListItems = tickList['list'] as List;
    expect(tickListItems, hasLength(2));
    expect(
      [
        for (final tick in tickListItems)
          ((tick as Map)['tick_no'] as num).toInt(),
      ],
      [4, 3],
    );
    expect(
      ((tickListItems.first as Map)['tick_result'] as Map)['narrator'],
      isNotEmpty,
    );
    final apply = await api.v1.world.apply(worldId: world, message: '想加入这个世界');
    expect(apply['status'], 10);
    final applyId = apply['apply_id'] as String;
    final applyList = await api.v1.world.applyList(
      worldId: world,
      status: 10,
      pn: 1,
      rn: 20,
    );
    expect(applyList['total'], 1);
    expect(((applyList['list'] as List).single as Map)['apply_id'], applyId);
    final review = await api.v1.world.reviewApply(
      applyId: applyId,
      action: 'approve',
      reviewMsg: 'Welcome',
    );
    expect(review['status'], 20);
    final join = await api.v1.world.join(
      worldId: world,
      presetCharacterId: 'char_1',
    );
    expect(join, containsPair('world_id', world));
    expect(join, containsPair('char_id', 'char_1'));
    await api.v1.world.tick(worldId: world);
    await api.v1.world.syncLatestOrigin(wid: world);

    final worldMessages = await api.chatroomHttp.getWorldMessages(
      worldId: world,
    );
    expect(worldMessages.locations, isNotEmpty);
    final userLocations = await api.chatroomHttp.getUserLocations(
      worldId: world,
    );
    expect(userLocations.worldId, world);
    expect(userLocations.locations, isNotEmpty);
    final firstLocationCharacter =
        userLocations.locations.first.characters.first;
    expect(firstLocationCharacter.charId, isNotEmpty);
    expect(firstLocationCharacter.name, isNotEmpty);
    expect(firstLocationCharacter.locationId, isNotEmpty);
    final history = await api.chatroomHttp.getMessages(
      worldId: world,
      locationId: worldMessages.locations.first.locationId,
      since: 0,
      limit: 20,
    );
    expect(history.messages, isNotEmpty);
    expect(await api.chatroomHttp.lockWorld(worldId: world), true);
    var tickProgress = await api.chatroomHttp.tickProgress(worldId: world);
    expect(tickProgress.progress, 0);
    expect(await api.chatroomHttp.unlockWorld(worldId: world), true);
    tickProgress = await api.chatroomHttp.tickProgress(worldId: world);
    expect(tickProgress.progress, 1);
    final narratorMessageId = await api.chatroomHttp.writeNarrator(
      worldId: world,
      tickId: 'tick_mock_001',
      locationGroups: const [
        ChatroomNarratorLocationGroup(
          locationId: 'loc_hub',
          locationName: 'Central Hub',
          locationSummary: 'The hub quiets down.',
          characters: [
            ChatroomNarratorCharacter(charId: 'c_mock_iris', name: 'Iris Vale'),
          ],
          initialDialogue: [
            ChatroomNarratorDialogueLine(
              charId: 'c_mock_iris',
              charName: 'Iris Vale',
              content: 'The gears settle into a slower rhythm.',
            ),
          ],
        ),
      ],
    );
    expect(narratorMessageId, greaterThan(0));

    var unreadSummary = await api.v1.messages.unreadSummary();
    expect(unreadSummary.systemUnread, greaterThanOrEqualTo(1));
    final systemMessages = await api.v1.messages.notifications(
      block: 'world_apply',
      pn: 1,
      rn: 20,
    );
    final systemItems = systemMessages['list'] as List;
    expect(systemMessages['total'], systemItems.length);
    expect(systemItems, isNotEmpty);
    expect(
      systemItems.every(
        (item) => (item as Map)['notice_block'] == 'world_apply',
      ),
      isTrue,
    );
    final followerMessages = await api.v1.messages.notifications(
      block: 'follow',
      pn: 1,
      rn: 20,
    );
    expect(
      ((followerMessages['list'] as List).single as Map)['notice_block'],
      'follow',
    );
    final commentMessages = await api.v1.messages.notifications(
      block: 'interaction',
      pn: 1,
      rn: 20,
    );
    expect(
      ((commentMessages['list'] as List).single as Map)['notice_block'],
      'interaction',
    );
    expect(
      ((commentMessages['list'] as List).single as Map)['origin_name'],
      'Steam Kingdom',
    );
    await api.v1.messages.markNotificationsRead(block: 'world_apply');
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
    final replies = await api.v1.discuss.replies(
      rootDiscussId: postId,
      pn: 1,
      rn: 20,
    );
    final replyItems = replies['list'] as List;
    expect(replyItems.length, 1);
    expect((replyItems.first as Map)['root_discuss_id'], postId);
    expect(replies['total'], 1);
    expect(replies['pn'], 1);
    expect(replies['rn'], 20);
    await api.v1.discuss.like(discussId: postId);
    await api.v1.discuss.unlike(discussId: postId);
    await api.v1.discuss.delete(discussId: postId);
    final report = await api.v1.report.create(
      targetType: 'origin',
      targetId: createdOrigin,
      content: '内容疑似违规',
    );
    expect(report['report_id'], startsWith('rpt_mock_'));

    final search = await api.v1.search.search(query: 'steam');
    expect((search['origins'] as Map)['list'] as List, isNotEmpty);
    await api.v1.search.suggest(query: 'steam', limit: 10);

    final rebornSearch = await api.v1.search.search(query: '重生', pn: 1, rn: 20);
    final rebornOrigins = rebornSearch['origins'] as Map;
    final rebornWorlds = rebornSearch['worlds'] as Map;
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
    final userSearchGroup = userSearch['users'] as Map;
    expect(userSearchGroup['total'], greaterThan(0));
    expect(userSearchGroup['list'] as List, isNotEmpty);

    final searchAllPage1 = await api.v1.search.search(query: '', pn: 1, rn: 20);
    for (final group in [
      searchAllPage1['origins'] as Map,
      searchAllPage1['worlds'] as Map,
      searchAllPage1['users'] as Map,
    ]) {
      expect(group['total'], greaterThanOrEqualTo(50));
      expect(group['list'] as List, hasLength(20));
    }
    final searchUserPage2 = await api.v1.search.search(
      query: '',
      type: 'user',
      pn: 2,
      rn: 20,
    );
    final userGroup = searchUserPage2['users'] as Map;
    final originGroup = searchUserPage2['origins'] as Map;
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
    expect(imageUpload['sm_url'], startsWith('https://mock.local/uploads/'));
    expect(imageUpload['xl_url'], startsWith('https://mock.local/uploads/'));
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
