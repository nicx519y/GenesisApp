import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';

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

    final world = await api.launchWorld(
      originId: firstOrigin.id,
      worldviewId: firstOrigin.oid,
      worldName: firstOrigin.name,
    );
    expect(world.wid.isNotEmpty, true);

    final worldDetail = await api.getWorld(world.wid);
    expect(worldDetail.worldLocations.isNotEmpty, true);

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
    await api.v1.world.requestJoin(wid: world);
    await api.v1.world.auditRequest(
      requestId: 'request_mock_1',
      action: 'approve',
    );
    await api.v1.world.join(wid: world);
    await api.v1.world.progress(wid: world);
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
    await api.v1.follow.following(uid: 'u_mock_001', pn: 1, rn: 10);
    await api.v1.follow.followers(uid: 'u_mock_001', pn: 1, rn: 10);
    await api.v1.follow.relations(type: 'followers', pn: 1, rn: 10);
    await api.v1.follow.status(uids: const ['u_mock_peer']);

    final dm = await api.v1.dm.send(
      targetUid: 'u_mock_peer',
      content: 'hello v1 mock',
      clientMsgId: 'client_mock_1',
    );
    expect(((dm['message'] as Map)['content']), 'hello v1 mock');
    await api.v1.dm.chatList(pn: 1, rn: 10);
    await api.v1.dm.messageList(conversationId: 'dm_conv_001', rn: 20);
    await api.v1.dm.markRead(conversationId: 'dm_conv_001', lastReadSeq: 2);
    await api.v1.dm.inviteWorldCard(
      conversationId: 'dm_conv_001',
      worldInstanceId: world,
      originId: createdOrigin,
      clientMsgId: 'invite_mock_1',
    );
    await api.v1.dm.respondWorldCard(
      inviteId: 'invite_mock_1',
      action: 'accept',
    );

    final discussions = await api.v1.discuss.list(bizId: createdOrigin);
    final postId =
        ((discussions['list'] as List).first as Map)['post_id'] as String;
    await api.v1.discuss.detail(postId: postId, pn: 2, rn: 10);
    final newPost = await api.v1.discuss.post(
      bizId: createdOrigin,
      content: 'mock post',
    );
    await api.v1.discuss.reply(
      commentId: newPost['post_id'] as String,
      content: 'mock reply',
    );
    await api.v1.discuss.like(commentId: postId, action: 'like');

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
