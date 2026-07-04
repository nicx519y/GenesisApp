import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_connection_controller.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_socket_transport.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('setInputBlocked publishes shared composer block state', () async {
    final service = await _service(
      socketTransport: _FakeChatroomTransport(_FakeChatroomSocket()),
    );
    final states = <WorldChatroomState>[];
    final sub = service.states.listen(states.add);

    service.setInputBlocked(true);
    service.setInputBlocked(true);
    service.setInputBlocked(false);
    await Future<void>.delayed(Duration.zero);

    expect(states.map((state) => state.inputBlocked).toList(), [true, false]);
    expect(service.state.inputBlocked, isFalse);

    await sub.cancel();
    await service.dispose();
  });

  test('tick notifications update shared composer block state', () async {
    final socket = _FakeChatroomSocket();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
    );

    await service.connect(worldId: 'world-1', identity: _identity());

    socket.serverFrame('world_change', {
      'world_id': 'world-1',
      'payload': {'event_type': 'tick_start'},
    });
    await _waitFor(() => service.state.inputBlocked);

    socket.serverFrame('world_change', {
      'world_id': 'world-1',
      'payload': {'event_type': 'tick_done'},
    });
    await _waitFor(() => !service.state.inputBlocked);

    await service.dispose();
  });

  test('connect hydrates world detail and user locations', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());

    expect(service.identity?.senderId, 'user-1');
    expect(service.identity?.senderName, 'Player One');
    expect(service.state.world?.worldId, 'world-1');
    expect(service.state.world?.name, 'World One');
    expect(service.state.locationTree, hasLength(1));
    expect(service.state.entitiesById['char-1']?.locationId, 'loc-1');
    expect(service.state.entitiesById['user-1']?.locationId, 'loc-2');
    expect(service.state.entitiesById['user-1']?.name, 'Role One');
    expect(
      service.state.entitiesByLocation['loc-1']!.map((entity) => entity.id),
      contains('char-1'),
    );
    expect(
      service.state.entitiesByLocation['loc-2']!.map((entity) => entity.id),
      contains('user-1'),
    );
    expect(
      service.state.messagesByLocation.keys,
      containsAll(['loc-1', 'loc-2']),
    );
    expect(service.state.messagesByLocation['loc-1'], isEmpty);
    expect(service.state.messagesByLocation['loc-2'], isEmpty);
    expect(http.detailRequests, 1);
    expect(http.userLocationRequests, 1);
    expect(http.messagesRequestsByLocation, isEmpty);

    await service.dispose();
  });

  test(
    'connect does not warm message caches before opening a location',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport();
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          _httpMessageJson(
            messageId: 1,
            locationId: 'loc-1',
            content: 'cached',
          ),
        ],
      );
      http.messagesByLocation['loc-1'] = [
        _httpMessageJson(messageId: 2, locationId: 'loc-1', content: 'remote'),
      ];
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
      );

      await service.connect(worldId: 'world-1', identity: _identity());

      expect(service.state.messagesByLocation['loc-1'], isEmpty);
      expect(http.messagesRequestsByLocation, isEmpty);
      final cached = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 20,
      );
      expect(cached.map((message) => message['content']).toList(), ['cached']);
      await service.dispose();
    },
  );

  test(
    'join loads cached location messages before websocket connects',
    () async {
      final socket = _FakeChatroomSocket();
      final connectCompleter = Completer<void>();
      final socketTransport = _BlockingChatroomTransport(
        socket,
        connectCompleter,
      );
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          _httpMessageJson(
            messageId: 1,
            locationId: 'loc-1',
            content: 'cached before socket',
          ),
        ],
      );
      final service = await _service(
        socketTransport: socketTransport,
        messageStorage: storage,
      );

      final connectFuture = service.connect(
        worldId: 'world-1',
        identity: _identity(),
      );
      await _waitFor(() => socketTransport.connectStarted);

      final joinFuture = service.join(locationId: 'loc-1');
      await _waitFor(
        () =>
            service.state.messagesByLocation['loc-1']?.any(
              (message) => message.content == 'cached before socket',
            ) ??
            false,
      );

      expect(socket.sentTypes, isNot(contains('join')));

      connectCompleter.complete();
      await _waitFor(() => socket.sentTypes.contains('join'));
      socket.serverJoinAck();
      await joinFuture;
      await connectFuture;
      await service.dispose();
    },
  );

  test('join fetches latest history for the joined location', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = [
        _httpMessageJson(
          messageId: 10,
          locationId: 'loc-1',
          content: 'joined history 1',
        ),
        _httpMessageJson(
          messageId: 11,
          locationId: 'loc-1',
          content: 'joined history 2',
        ),
        _httpMessageJson(
          messageId: 12,
          locationId: 'loc-1',
          content: 'joined history 3',
        ),
      ];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    final historyStateLengths = <int>[];
    final stateSub = service.states.listen((state) {
      final length = state.messagesByLocation['loc-1']?.length;
      if (length != null) historyStateLengths.add(length);
    });
    final joinFuture = service.join(locationId: 'loc-1');
    await _waitFor(() => socket.sentTypes.contains('join'));
    socket.serverJoinAck();
    await joinFuture;

    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.content == 'joined history 3',
          ) ??
          false,
    );

    expect(http.worldMessagesRequests, 0);
    expect(http.messageSinceByLocation['loc-1'], [0]);
    expect(historyStateLengths.where((length) => length > 0), contains(3));
    expect(historyStateLengths.where((length) => length > 0).last, 3);
    await stateSub.cancel();
    await service.dispose();
  });

  test(
    'hydrateLocalMessages maps cached location aliases into target queue',
    () async {
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'point-loc-1',
        messages: [
          _httpMessageJson(
            messageId: 1,
            locationId: 'point-loc-1',
            content: 'cached alias message',
          ),
        ],
      );
      final socket = _FakeChatroomSocket();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        messageStorage: storage,
      );

      await service.hydrateLocalMessages(
        worldId: 'world-1',
        locationId: 'scene-loc-1',
        ownerUid: 'user-1',
        locationAliases: const ['point-loc-1'],
      );

      expect(
        service.state.messagesByLocation['scene-loc-1']!
            .map((message) => '${message.locationId}:${message.content}')
            .toList(),
        ['scene-loc-1:cached alias message'],
      );
      expect(service.state.messagesByLocation['point-loc-1'], isNull);
      expect(socket.sentTypes, isEmpty);
      await service.dispose();
    },
  );

  test(
    'hydrateLocalMessages publishes an alias before a slower empty alias',
    () async {
      final storage = _BlockingChatroomMessageStorage('scene-loc-1');
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'point-loc-1',
        messages: [
          _httpMessageJson(
            messageId: 1,
            locationId: 'point-loc-1',
            content: 'cached fast alias message',
          ),
        ],
      );
      final socket = _FakeChatroomSocket();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        messageStorage: storage,
      );

      var hydrateCompleted = false;
      final hydrate = service
          .hydrateLocalMessages(
            worldId: 'world-1',
            locationId: 'scene-loc-1',
            ownerUid: 'user-1',
            locationAliases: const ['point-loc-1'],
          )
          .then((_) => hydrateCompleted = true);

      await _waitFor(
        () =>
            service.state.messagesByLocation['scene-loc-1']?.any(
              (message) => message.content == 'cached fast alias message',
            ) ??
            false,
      );

      expect(hydrateCompleted, false);
      expect(storage.blockingLoadStarted, true);
      expect(socket.sentTypes, isEmpty);

      storage.completeBlockingLoad();
      await hydrate;
      expect(hydrateCompleted, true);
      await service.dispose();
    },
  );

  test('hydrateLocalMessages waits for an in-flight cache load', () async {
    final storage = _BlockingChatroomMessageStorage('point-loc-1');
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'point-loc-1',
      messages: [
        _httpMessageJson(
          messageId: 1,
          locationId: 'point-loc-1',
          content: 'cached after blocking load',
        ),
      ],
    );
    final socket = _FakeChatroomSocket();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      messageStorage: storage,
    );

    final firstHydrate = service.hydrateLocalMessages(
      worldId: 'world-1',
      locationId: 'scene-loc-1',
      ownerUid: 'user-1',
      locationAliases: const ['point-loc-1'],
    );
    await _waitFor(() => storage.blockingLoadStarted);

    var secondCompleted = false;
    final secondHydrate = service
        .hydrateLocalMessages(
          worldId: 'world-1',
          locationId: 'scene-loc-1',
          ownerUid: 'user-1',
          locationAliases: const ['point-loc-1'],
        )
        .then((_) => secondCompleted = true);
    await Future<void>.delayed(Duration.zero);

    expect(secondCompleted, false);

    storage.completeBlockingLoad();
    await firstHydrate;
    await secondHydrate;

    expect(
      service.state.messagesByLocation['scene-loc-1']!
          .map((message) => message.content)
          .toList(),
      ['cached after blocking load'],
    );
    expect(secondCompleted, true);
    expect(socket.sentTypes, isEmpty);
    await service.dispose();
  });

  test('hydrateLocalMessages loads cache before connect starts', () async {
    final storage = MemoryChatroomMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      messages: [
        _httpMessageJson(
          messageId: 1,
          locationId: 'loc-1',
          content: 'cached before connect',
        ),
      ],
    );
    final socket = _FakeChatroomSocket();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      messageStorage: storage,
    );

    await service.hydrateLocalMessages(
      worldId: 'world-1',
      locationId: 'loc-1',
      ownerUid: 'user-1',
    );

    expect(
      service.state.messagesByLocation['loc-1']!
          .map((message) => message.content)
          .toList(),
      ['cached before connect'],
    );
    expect(socket.sentTypes, isEmpty);
    await service.dispose();
  });

  test('connect skips location history warmup', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..failedMessageLocationIds.add('loc-1');
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );
    final failures = <ChatroomFailureEvent>[];
    final failureSub = service.failures.listen(failures.add);

    await service.connect(worldId: 'world-1', identity: _identity());

    expect(http.messagesRequestsByLocation, isEmpty);
    expect(http.userLocationRequests, 1);
    expect(
      failures.where((failure) => failure.code == 'snapshot_failed'),
      isEmpty,
    );
    await failureSub.cancel();
    await service.dispose();
  });

  test(
    'history messages use requested location when response omits location id',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..messagesByLocation['loc-1'] = [
          _httpMessageJson(
            messageId: 11,
            locationId: '',
            content: 'without location',
          ),
        ]
        ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
      final storage = MemoryChatroomMessageStorage();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
      );

      await service.connect(worldId: 'world-1', identity: _identity());
      final page = await service.loadOlderMessages(
        locationId: 'loc-1',
        beforeMessageId: 100,
        limit: 20,
      );

      final message = service.state.messagesByLocation['loc-1']!.singleWhere(
        (message) => message.messageId == 11,
      );
      expect(page.loadedCount, 1);
      expect(message.globalMessageId, 90011);
      expect(message.locationMessageId, 11);
      expect(message.locationId, 'loc-1');
      final cached = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 20,
      );
      expect(cached.single['location_id'], 'loc-1');
      expect(cached.single['global_msg_id'], 90011);
      expect(cached.single['location_msg_id'], 11);
      await service.dispose();
    },
  );

  test(
    'chatroom message storage prunes each location to 200 messages',
    () async {
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          for (var id = 1; id <= 205; id += 1)
            _storageMessageJson(
              messageId: id,
              locationId: 'loc-1',
              content: 'message-$id',
            ),
        ],
      );

      final records = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 250,
      );

      expect(records, hasLength(200));
      expect(records.first['msg_id'], 6);
      expect(records.first['global_msg_id'], 90006);
      expect(records.first['location_msg_id'], 6);
      expect(records.last['msg_id'], 205);
      expect(records.last['global_msg_id'], 90205);
      expect(records.last['location_msg_id'], 205);
    },
  );

  test('chatroom message storage loads messages before cursor', () async {
    final storage = MemoryChatroomMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      messages: [
        for (var id = 1; id <= 5; id += 1)
          _storageMessageJson(
            messageId: id,
            locationId: 'loc-1',
            content: 'message-$id',
          ),
      ],
    );

    final records = await storage.loadMessagesBefore(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      beforeMessageId: 4,
      limit: 2,
    );

    expect(records.map((message) => message['msg_id']).toList(), [2, 3]);
  });

  test(
    'chatroom message storage deletes messages at or before cursor',
    () async {
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          for (var id = 1; id <= 5; id += 1)
            _storageMessageJson(
              messageId: id,
              locationId: 'loc-1',
              content: 'message-$id',
            ),
        ],
      );

      await storage.deleteMessagesAtOrBefore(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        maxLocationMessageId: 2,
      );

      final records = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 20,
      );
      expect(records.map((message) => message['location_msg_id']).toList(), [
        3,
        4,
        5,
      ]);
    },
  );

  test(
    'chatroom message storage orders and pages by location message id',
    () async {
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          _storageMessageJson(
            messageId: 100,
            locationMessageId: 1,
            locationId: 'loc-1',
            content: 'first in location',
          ),
          _storageMessageJson(
            messageId: 20,
            locationMessageId: 2,
            locationId: 'loc-1',
            content: 'second in location',
          ),
          _storageMessageJson(
            messageId: 30,
            locationMessageId: 3,
            locationId: 'loc-1',
            content: 'third in location',
          ),
        ],
      );

      final latest = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 2,
      );
      expect(latest.map((message) => message['location_msg_id']).toList(), [
        2,
        3,
      ]);
      expect(latest.map((message) => message['msg_id']).toList(), [20, 30]);

      final older = await storage.loadMessagesBefore(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        beforeMessageId: 3,
        limit: 2,
      );
      expect(older.map((message) => message['location_msg_id']).toList(), [
        1,
        2,
      ]);
      expect(older.map((message) => message['msg_id']).toList(), [100, 20]);
    },
  );

  test('chatroom message storage does not fallback to message id', () async {
    final storage = MemoryChatroomMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      messages: [
        _storageMessageJson(
          messageId: 100,
          locationMessageId: 0,
          locationId: 'loc-1',
          content: 'missing location queue id',
        ),
        _storageMessageJson(
          messageId: 101,
          locationMessageId: 1,
          locationId: 'loc-1',
          content: 'first location queue message',
        ),
      ],
    );

    final records = await storage.loadLatestMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      limit: 20,
    );

    expect(records.map((message) => message['msg_id']).toList(), [101]);
    expect(records.map((message) => message['location_msg_id']).toList(), [1]);
  });

  test('clearCachedMessages clears persisted and in-memory history', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final storage = MemoryChatroomMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      messages: [
        _storageMessageJson(
          messageId: 1,
          locationId: 'loc-1',
          content: 'old-1',
        ),
      ],
    );
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-2',
      messages: [
        _storageMessageJson(
          messageId: 7,
          locationId: 'loc-2',
          content: 'other-location',
        ),
      ],
    );
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
      messageStorage: storage,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    await service.hydrateLocalMessages(
      worldId: 'world-1',
      locationId: 'loc-1',
      locationAliases: const ['loc-1'],
    );
    expect(service.state.messagesByLocation['loc-1'], isNotEmpty);

    await service.clearCachedMessages();

    final loc1 = await storage.loadLatestMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      limit: 20,
    );
    final loc2 = await storage.loadLatestMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-2',
      limit: 20,
    );

    expect(loc1, isEmpty);
    expect(loc2, isEmpty);
    expect(service.state.messagesByLocation['loc-1'], isEmpty);
    expect(service.state.messagesByLocation['loc-2'], isEmpty);
    expect(service.state.worldMessages, isEmpty);
    await service.dispose();
  });

  test('loadOlderMessages requests remote history before cursor', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = [
        _httpMessageJson(
          messageId: 1,
          locationId: 'loc-1',
          content: 'remote-old',
        ),
        _httpMessageJson(
          messageId: 2,
          locationId: 'loc-1',
          content: 'remote-new',
        ),
      ]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    final page = await service.loadOlderMessages(
      locationId: 'loc-1',
      beforeMessageId: 3,
      limit: 20,
    );

    expect(page.loadedCount, 2);
    expect(page.hasMore, isFalse);
    expect(http.messageSinceByLocation['loc-1']?.last, 3);
    expect(
      service.state.messagesByLocation['loc-1']!
          .map((message) => message.content)
          .toList(),
      ['remote-old', 'remote-new'],
    );
    await service.dispose();
  });

  test(
    'initializeLeafLocationQueues fetches latest history for leaf locations',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..messagesByLocation['loc-1'] = [
          _httpMessageJson(messageId: 1, locationId: 'loc-1', content: 'one'),
        ]
        ..messagesByLocation['loc-2'] = [
          _httpMessageJson(messageId: 2, locationId: 'loc-2', content: 'two'),
        ];
      final storage = MemoryChatroomMessageStorage();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
      );

      service.applyWorldSnapshot(_worldSnapshot());
      await service.connect(worldId: 'world-1', identity: _identity());
      await service.initializeLeafLocationQueues();

      expect(http.worldMessagesRequests, 0);
      expect(http.messageSinceByLocation['loc-1'], [0]);
      expect(http.messageSinceByLocation['loc-2'], [0]);
      expect(
        service.state.messagesByLocation['loc-1']!
            .map((message) => message.content)
            .toList(),
        ['one'],
      );
      final cached = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-2',
        limit: 20,
      );
      expect(cached.single['location_msg_id'], 2);
      await service.dispose();
    },
  );

  test(
    'initializeLeafLocationQueues fills recoverable location id gaps',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..messagesByLocation['loc-1'] = [
          for (var id = 1; id <= 5; id += 1)
            _httpMessageJson(
              messageId: id,
              locationId: 'loc-1',
              content: 'remote-$id',
            ),
        ]
        ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          _storageMessageJson(
            messageId: 1,
            locationId: 'loc-1',
            content: 'old-1',
          ),
          _storageMessageJson(
            messageId: 2,
            locationId: 'loc-1',
            content: 'old-2',
          ),
        ],
      );
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
      );

      await service.connect(worldId: 'world-1', identity: _identity());
      await service.hydrateLocalMessages(
        worldId: 'world-1',
        locationId: 'loc-1',
      );
      await service.initializeLeafLocationQueues(
        locationIds: const ['loc-1'],
        latestLimit: 2,
      );

      expect(http.messageSinceByLocation['loc-1'], [0, 4]);
      expect(
        service.state.messagesByLocation['loc-1']!
            .map((message) => message.locationMessageId)
            .toList(),
        [1, 2, 3, 4, 5],
      );
      await service.dispose();
    },
  );

  test(
    'initializeLeafLocationQueues discards old messages before large gaps',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..messagesByLocation['loc-1'] = [
          _httpMessageJson(
            messageId: 80,
            locationId: 'loc-1',
            content: 'eighty',
          ),
          _httpMessageJson(
            messageId: 81,
            locationId: 'loc-1',
            content: 'newest',
          ),
        ]
        ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          _storageMessageJson(
            messageId: 1,
            locationId: 'loc-1',
            content: 'old-1',
          ),
          _storageMessageJson(
            messageId: 2,
            locationId: 'loc-1',
            content: 'old-2',
          ),
        ],
      );
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
      );

      await service.connect(worldId: 'world-1', identity: _identity());
      await service.hydrateLocalMessages(
        worldId: 'world-1',
        locationId: 'loc-1',
      );
      await service.initializeLeafLocationQueues(
        locationIds: const ['loc-1'],
        latestLimit: 2,
      );

      expect(http.messageSinceByLocation['loc-1'], [0]);
      expect(
        service.state.messagesByLocation['loc-1']!
            .map((message) => message.locationMessageId)
            .toList(),
        [80, 81],
      );
      final cached = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 20,
      );
      expect(cached.map((message) => message['location_msg_id']).toList(), [
        80,
        81,
      ]);
      await service.dispose();
    },
  );

  test('initializeLeafLocationQueues retries unrecovered gaps twice', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = [
        _httpMessageJson(messageId: 1, locationId: 'loc-1', content: 'one'),
        _httpMessageJson(messageId: 2, locationId: 'loc-1', content: 'two'),
        _httpMessageJson(messageId: 4, locationId: 'loc-1', content: 'four'),
        _httpMessageJson(messageId: 5, locationId: 'loc-1', content: 'five'),
      ]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final storage = MemoryChatroomMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      messages: [
        _storageMessageJson(
          messageId: 1,
          locationId: 'loc-1',
          content: 'old-1',
        ),
        _storageMessageJson(
          messageId: 2,
          locationId: 'loc-1',
          content: 'old-2',
        ),
      ],
    );
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
      messageStorage: storage,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    await service.hydrateLocalMessages(worldId: 'world-1', locationId: 'loc-1');
    await service.initializeLeafLocationQueues(
      locationIds: const ['loc-1'],
      latestLimit: 2,
    );

    expect(http.messageSinceByLocation['loc-1'], [0, 4, 4, 4]);
    expect(
      service.state.messagesByLocation['loc-1']!
          .map((message) => message.locationMessageId)
          .toList(),
      [1, 2, 4, 5],
    );
    await service.dispose();
  });

  test('user message uses required top-level sender id', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverFrame('user_message', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'user_id': 'user-1',
      'sender_id': 'user-1',
      'sender_name': 'Player One',
      'global_msg_id': 90061,
      'msg_id': 61,
      'location_msg_id': 61,
      'conversation_round_id': 1280,
      'payload': {'content': '你是谁', 'client_msg_id': 'client-1'},
    });

    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.messageId == 61,
          ) ==
          true,
    );
    final message = service.state.messagesByLocation['loc-1']!.singleWhere(
      (message) => message.messageId == 61,
    );
    expect(message.globalMessageId, 90061);
    expect(message.locationMessageId, 61);
    expect(message.userId, 'user-1');
    expect(message.senderId, 'user-1');
    expect(message.clientMsgId, 'client-1');
    await service.dispose();
  });

  test(
    'tick advance push enters every leaf location queue as system time message',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
        ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
      );

      await service.connect(worldId: 'world-1', identity: _identity());
      socket.serverFrame('tick_advance', {
        'ts': 1780840607650,
        'world_id': 'world-1',
        'global_msg_id': 90154,
        'msg_id': 154,
        'location_msg_id': 0,
        'conversation_round_id': 1348,
        'current_time': 'Day 45, 19:30',
        'payload': {'content': 'Day 45, 19:30', 'tick_no': 7},
      });

      await _waitFor(
        () =>
            service.state.messagesByLocation['loc-1']?.any(
                  (message) => message.messageId == 154,
                ) ==
                true &&
            service.state.messagesByLocation['loc-2']?.any(
                  (message) => message.messageId == 154,
                ) ==
                true,
      );
      for (final locationId in const ['loc-1', 'loc-2']) {
        final message = service.state.messagesByLocation[locationId]!
            .singleWhere((message) => message.messageId == 154);
        expect(message.globalMessageId, 90154);
        expect(message.locationMessageId, 0);
        expect(message.locationId, locationId);
        expect(message.senderType, 'tick');
        expect(message.senderId, 'tick');
        expect(message.senderName, 'Time');
        expect(message.tickNo, 7);
        expect(message.content, 'Day 45, 19:30');
      }
      expect(service.state.messagesByLocation.containsKey('loc-root'), isFalse);
      await service.dispose();
    },
  );

  test(
    'non-tick push without location message id stays out of queue',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
        ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
      );

      await service.connect(worldId: 'world-1', identity: _identity());
      socket.serverFrame('nar_new_message', {
        'ts': 1780840607650,
        'world_id': 'world-1',
        'payload': {'content': '*dirty record without location id*'},
        'global_msg_id': 90156,
        'msg_id': 156,
        'location_msg_id': 0,
        'conversation_round_id': 1350,
        'sender_id': 'char_1',
        'sender_name': 'Character',
        'location_id': 'loc-1',
      });

      await Future<void>.delayed(Duration.zero);

      expect(
        service.state.messagesByLocation['loc-1']?.any(
              (message) => message.messageId == 156,
            ) ??
            false,
        isFalse,
      );
      expect(
        service.state.worldMessages.any((message) => message.messageId == 156),
        isTrue,
      );
      await service.dispose();
    },
  );

  test('narrator push with top-level fields enters location queue', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverFrame('nar_new_message', {
      'ts': 1780840607650,
      'world_id': 'world-1',
      'payload': {'content': '*黑暗中，芯片脉冲与数据卡蓝光交织*'},
      'global_msg_id': 90155,
      'msg_id': 155,
      'location_msg_id': 55,
      'conversation_round_id': 1349,
      'sender_id': 'nar',
      'sender_name': '旁白',
      'location_id': 'loc-1',
      'broadcast': true,
    });

    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.messageId == 155,
          ) ==
          true,
    );
    final message = service.state.messagesByLocation['loc-1']!.singleWhere(
      (message) => message.messageId == 155,
    );
    expect(message.globalMessageId, 90155);
    expect(message.locationMessageId, 55);
    expect(message.conversationRoundId, '1349');
    expect(message.locationId, 'loc-1');
    expect(message.senderType, 'narrator');
    expect(message.senderId, 'nar');
    expect(message.senderName, '旁白');
    expect(message.content, '*黑暗中，芯片脉冲与数据卡蓝光交织*');
    await service.dispose();
  });

  test('narrator push from non-nar sender enters queue as character', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverFrame('nar_new_message', {
      'world_id': 'world-1',
      'payload': {'content': '角色旁白式发言'},
      'global_msg_id': 90156,
      'msg_id': 156,
      'location_msg_id': 56,
      'conversation_round_id': 1350,
      'sender_id': 'char-1',
      'sender_name': 'Alice',
      'location_id': 'loc-1',
      'broadcast': true,
    });

    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.messageId == 156,
          ) ==
          true,
    );
    final message = service.state.messagesByLocation['loc-1']!.singleWhere(
      (message) => message.messageId == 156,
    );
    expect(message.globalMessageId, 90156);
    expect(message.locationMessageId, 56);
    expect(message.conversationRoundId, '1350');
    expect(message.senderId, 'char-1');
    expect(message.senderType, 'character');
    expect(message.content, '角色旁白式发言');
    await service.dispose();
  });

  test('active disconnect does not reconnect', () async {
    final socket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([socket]);
    final service = await _service(
      socketTransport: transport,
      heartbeatInterval: const Duration(milliseconds: 5),
      reconnectInterval: const Duration(milliseconds: 5),
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    await service.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(transport.connectCount, 1);
    expect(service.state.reconnecting, false);
    await service.dispose();
  });

  test('socket close reconnects when it was not user initiated', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([firstSocket, secondSocket]);
    final service = await _service(
      socketTransport: transport,
      reconnectInterval: const Duration(milliseconds: 5),
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    await firstSocket.serverClose();

    await _waitFor(() => transport.connectCount == 2);
    expect(service.state.reconnecting, false);
    await service.dispose();
  });

  test('heartbeat sends frames without ack timeout reconnects', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([firstSocket, secondSocket]);
    final service = await _service(
      socketTransport: transport,
      heartbeatInterval: const Duration(milliseconds: 5),
      reconnectInterval: const Duration(milliseconds: 5),
      ackTimeout: const Duration(milliseconds: 5),
    );

    await service.connect(worldId: 'world-1', identity: _identity());

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(transport.connectCount, 1);
    expect(
      firstSocket.sentTypes.where((type) => type == 'heartbeat').length,
      greaterThanOrEqualTo(1),
    );
    await service.dispose();
  });

  test('world_change and user_location_change refresh snapshots', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());

    http.worldName = 'World Changed';
    socket.serverFrame('world_change', {
      'world_id': 'world-1',
      'payload': {'event_type': 'world_change'},
    });
    await _waitFor(() => service.state.world?.name == 'World Changed');

    http.userLocationId = 'loc-1';
    socket.serverFrame('user_location_change', {
      'world_id': 'world-1',
      'payload': {'event_type': 'user_location_change'},
    });
    await _waitFor(
      () => service.state.entitiesById['user-1']?.locationId == 'loc-1',
    );
    expect(service.state.entitiesById['user-1']?.name, 'Role One');
    expect(service.state.entitiesById['user-1']?.name, isNot('Player One'));

    expect(http.detailRequests, 2);
    expect(http.userLocationRequests, 2);
    await service.dispose();
  });

  test(
    'snapshot-seeded connect waits for push events before refetching',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        refreshInitialSnapshotOnConnect: false,
      );
      service.applyWorldSnapshot(_worldSnapshot());

      await service.connect(worldId: 'world-1', identity: _identity());
      expect(http.detailRequests, 0);
      expect(http.userLocationRequests, 0);

      http.worldName = 'World Changed';
      socket.serverFrame('world_change', {
        'world_id': 'world-1',
        'payload': {'event_type': 'world_change'},
      });
      await _waitFor(() => service.state.world?.name == 'World Changed');
      expect(http.detailRequests, 1);
      expect(http.userLocationRequests, 0);

      http.userLocationId = 'loc-1';
      socket.serverFrame('user_location_change', {
        'world_id': 'world-1',
        'payload': {'event_type': 'user_location_change'},
      });
      await _waitFor(
        () =>
            service.state.world?.characters.any(
              (character) =>
                  character['player_uid'] == 'user-1' &&
                  character['location_id'] == 'loc-1',
            ) ==
            true,
      );
      expect(http.detailRequests, 1);
      expect(http.userLocationRequests, 1);
      expect(
        service.state.world?.characterPositions.any(
          (position) =>
              position['location_id'] == 'loc-1' &&
              (position['character'] as Map?)?['name'] == 'Role One' &&
              (position['character'] as Map?)?['player_uid'] == 'user-1',
        ),
        true,
      );
      await service.dispose();
    },
  );

  test(
    'user_location_change removes a role that leaves every location',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        refreshInitialSnapshotOnConnect: false,
      );
      service.applyWorldSnapshot(_worldSnapshot());

      await service.connect(worldId: 'world-1', identity: _identity());
      expect(service.state.entitiesByLocation['loc-2'], isNotEmpty);

      http.userLocationId = null;
      socket.serverFrame('user_location_change', {
        'world_id': 'world-1',
        'payload': {'event_type': 'user_location_change'},
      });

      await _waitFor(
        () =>
            service.state.world?.characters.any(
              (character) =>
                  character['player_uid'] == 'user-1' &&
                  !character.containsKey('location_id'),
            ) ==
            true,
      );

      expect(service.state.entitiesById['user-1']?.locationId, isEmpty);
      expect(
        service.state.entitiesByLocation['loc-2']?.map((entity) => entity.id),
        isNot(contains('user-1')),
      );
      expect(
        service.state.world?.characterPositions.any(
          (position) => (position['character'] as Map?)?['name'] == 'Role One',
        ),
        false,
      );
      expect(service.state.world?.userPositions, isEmpty);

      await service.dispose();
    },
  );

  test('world snapshot resolves image object role avatars', () async {
    final socket = _FakeChatroomSocket();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      refreshInitialSnapshotOnConnect: false,
    );
    final avatar = {
      'sm_url': 'https://cdn.example.com/role-sm.png',
      'xl_url': 'https://cdn.example.com/role-xl.png',
      'object_key': 'avatars/role.png',
    };

    service.applyWorldSnapshot(
      _worldSnapshot().copyWith(
        characters: [
          {
            'char_id': 'char-user-1',
            'type': 'player',
            'player_uid': 'user-1',
            'name': 'Role One',
            'avatar': avatar,
            'location_id': 'loc-2',
          },
        ],
        characterPositions: [
          {
            'location_id': 'loc-2',
            'character': {
              'id': 'char-user-1',
              'type': 'player',
              'player_uid': 'user-1',
              'name': 'Role One',
              'avatar': avatar,
            },
          },
        ],
        userPositions: const <Map<String, dynamic>>[],
      ),
    );

    expect(
      service.state.entitiesById['user-1']?.avatarUrl,
      'https://cdn.example.com/role-xl.png',
    );
    expect(
      service.state.entitiesByLocation['loc-2']?.single.avatarUrl,
      'https://cdn.example.com/role-xl.png',
    );

    await service.dispose();
  });

  test('push message id gaps do not fetch missing messages', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = [
        _httpMessageJson(
          messageId: 1,
          locationId: 'loc-1',
          content: 'loc-1-first',
        ),
        _httpMessageJson(
          messageId: 2,
          locationId: 'loc-1',
          content: 'loc-1-gap',
        ),
      ]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverUserMessage(messageId: 1, roundId: 1, content: 'loc-1-one');
    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.messageId == 1,
          ) ==
          true,
    );

    socket.serverUserMessage(messageId: 3, roundId: 3, content: 'loc-1-three');
    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.messageId == 3,
          ) ==
          true,
    );

    expect(http.messagesRequestsByLocation['loc-1'], isNull);
    expect(
      service.state.messagesByLocation['loc-1']!
          .map((message) => message.messageId)
          .toList(),
      [1, 3],
    );
    await service.dispose();
  });

  test('llm stream updates are matched by location and round id', () async {
    final socket = _FakeChatroomSocket();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverFrame('llm_stream_start', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'global_msg_id': 90010,
      'msg_id': 10,
      'location_msg_id': 10,
      'conversation_round_id': 8,
      'payload': {
        'sender_id': 'char-1',
        'sender_name': 'Alice',
        'round_order': 1,
      },
    });
    await _waitFor(
      () => service.state.streamMessagesByKey.containsKey('loc-1|8'),
    );
    expect(
      service.state.streamMessagesByKey['loc-1|8']?.globalMessageId,
      90010,
    );
    expect(service.state.streamMessagesByKey['loc-1|8']?.locationMessageId, 10);

    socket.serverFrame('llm_chunk', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-2',
      'global_msg_id': 90010,
      'msg_id': 10,
      'location_msg_id': 10,
      'conversation_round_id': 8,
      'payload': {'sender_id': 'char-1', 'seq': 1, 'content': 'wrong'},
    });
    await _waitFor(() => service.state.lastFailure?.code == 'stream_missing');

    socket.serverFrame('llm_chunk', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'global_msg_id': 90010,
      'msg_id': 10,
      'location_msg_id': 10,
      'conversation_round_id': 8,
      'payload': {'sender_id': 'char-1', 'seq': 1, 'content': 'hel'},
    });
    await _waitFor(
      () => service.state.streamMessagesByKey['loc-1|8']?.content == 'hel',
    );

    socket.serverFrame('llm_stream_end', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'global_msg_id': 90010,
      'msg_id': 10,
      'location_msg_id': 10,
      'conversation_round_id': 8,
      'payload': {'sender_id': 'char-1', 'content': 'hello'},
    });
    await _waitFor(
      () => !service.state.streamMessagesByKey.containsKey('loc-1|8'),
    );

    final message = service.state.messagesByLocation['loc-1']!.singleWhere(
      (message) => message.conversationRoundId == '8',
    );
    expect(message.globalMessageId, 90010);
    expect(message.locationMessageId, 10);
    expect(message.content, 'hello');
    expect(message.streaming, false);
    await service.dispose();
  });
}

Future<WorldChatroomService> _service({
  required ChatroomSocketTransport socketTransport,
  HttpTransport? httpTransport,
  Duration heartbeatInterval = const Duration(seconds: 2),
  Duration reconnectInterval = const Duration(milliseconds: 20),
  Duration ackTimeout = const Duration(milliseconds: 20),
  ChatroomMessageStorage? messageStorage,
  bool refreshInitialSnapshotOnConnect = true,
}) async {
  final store = MemoryUserSessionStore();
  await store.saveUid('user-1');
  await store.saveAuthToken('token-1');
  final api = GenesisApi(
    transport: httpTransport ?? _WorldChatroomHttpTransport(),
    useMock: false,
    deviceIdService: const _FakeDeviceIdService(),
    sessionStore: store,
    chatroomHttpBaseUrl: 'https://chatroom.test/',
  );
  final client = ChatroomClient(
    wsBaseUrl: 'ws://localhost:8082/aitown-chat/ws',
    sessionStore: store,
    deviceIdService: const _FakeDeviceIdService(),
    transport: socketTransport,
    heartbeatInterval: heartbeatInterval,
    ackTimeout: ackTimeout,
    autoHeartbeat: false,
  );
  return WorldChatroomService(
    api: api,
    client: client,
    messageStorage: messageStorage ?? MemoryChatroomMessageStorage(),
    heartbeatInterval: heartbeatInterval,
    reconnectInterval: reconnectInterval,
    refreshInitialSnapshotOnConnect: refreshInitialSnapshotOnConnect,
  );
}

WorldDetail _worldSnapshot() {
  return WorldDetail(
    id: 1,
    worldId: 'world-1',
    originId: 1,
    ownerUid: 'owner-1',
    name: 'World Snapshot',
    tickCount: 0,
    connectCount: 1,
    characterCount: 2,
    playerCount: 1,
    currentTime: '',
    latestTickAt: null,
    latestNarrator: '',
    isProgressing: false,
    relationStatus: 'owner',
    metric: const <String, dynamic>{},
    inviteToken: 'world-1',
    createdAt: null,
    updatedAt: null,
    origin: const OriginSummary(
      id: 1,
      oid: 'origin-1',
      name: 'World Snapshot',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 1,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    ),
    characters: const [
      {
        'char_id': 'char-1',
        'type': 'ai',
        'name': 'Alice',
        'location_id': 'loc-1',
      },
      {
        'char_id': 'char-user-1',
        'type': 'player',
        'player_uid': 'user-1',
        'name': 'Role One',
        'location_id': 'loc-2',
      },
    ],
    ticks: const <Map<String, dynamic>>[],
    locations: const [
      {'location_id': 'loc-1', 'location_pid': '', 'location_name': 'Square'},
      {'location_id': 'loc-2', 'location_pid': '', 'location_name': 'Cafe'},
    ],
    characterPositions: const [
      {
        'location_id': 'loc-1',
        'character': {'id': 'char-1', 'name': 'Alice', 'type': 'ai'},
      },
      {
        'location_id': 'loc-2',
        'character': {
          'id': 'char-user-1',
          'name': 'Role One',
          'type': 'player',
        },
      },
    ],
    userPositions: const [
      {'uid': 'user-1', 'location_id': 'loc-2'},
    ],
  );
}

ChatroomConnectionIdentity _identity() {
  return const ChatroomConnectionIdentity(
    userId: 'user-1',
    senderId: 'user-1',
    senderName: 'Player One',
  );
}

Map<String, dynamic> _httpMessageJson({
  required int messageId,
  required String locationId,
  required String content,
  int? locationMessageId,
}) {
  return {
    'global_message_id': 90000 + messageId,
    'message_id': messageId,
    'location_message_id': locationMessageId ?? messageId,
    'location_id': locationId,
    'conversation_round_id': messageId,
    'tick_no': 0,
    'sender_type': 'user',
    'sender_id': 'user-$messageId',
    'sender_name': 'User $messageId',
    'user_id': 'user-$messageId',
    'content': content,
    'current_time': '',
    'created_at': '2026-07-01 10:00:${messageId.toString().padLeft(2, '0')}',
  };
}

Map<String, dynamic> _storageMessageJson({
  required int messageId,
  required String locationId,
  required String content,
  int? locationMessageId,
}) {
  return {
    'global_msg_id': 90000 + messageId,
    'msg_id': messageId,
    'location_msg_id': locationMessageId ?? messageId,
    'location_id': locationId,
    'conversation_round_id': messageId,
    'round_order': 1,
    'tick_no': 0,
    'sender_type': 'user',
    'sender_id': 'user-$messageId',
    'sender_name': 'User $messageId',
    'user_id': 'user-$messageId',
    'client_msg_id': '',
    'content': content,
    'current_time': '',
    'ts': 1717300000000 + messageId,
  };
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  if (!condition()) {
    fail('Condition was not met within $timeout');
  }
}

class _WorldChatroomHttpTransport implements HttpTransport {
  String worldName = 'World One';
  String? userLocationId = 'loc-2';
  int detailRequests = 0;
  int userLocationRequests = 0;
  int worldMessagesRequests = 0;
  int messagesRequests = 0;
  final Set<String> failedMessageLocationIds = <String>{};
  final Map<String, int> messagesRequestsByLocation = {};
  final Map<String, List<int?>> messageSinceByLocation = {};
  final Map<String, List<Map<String, dynamic>>> messagesByLocation = {
    'loc-1': [
      _httpMessageJson(messageId: 2, locationId: 'loc-1', content: 'gap'),
    ],
    'loc-2': [
      _httpMessageJson(messageId: 4, locationId: 'loc-2', content: 'loc-2'),
    ],
  };

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final path = request.uri.path;
    if (path.endsWith('/api/v1/world/detail')) {
      detailRequests += 1;
      return _json({'err_no': 0, 'err_msg': 'succ', 'data': _worldDetail()});
    }
    if (path.endsWith('/aitown-chat/api/ulocation')) {
      userLocationRequests += 1;
      final locations = <Map<String, Object?>>[];
      void addUser(String locationId, Map<String, Object?> user) {
        Map<String, Object?>? group;
        for (final location in locations) {
          if (location['location_id'] == locationId) {
            group = location;
            break;
          }
        }
        final resolvedGroup =
            group ??
            <String, Object?>{
              'location_id': locationId,
              'users': <Map<String, Object?>>[],
            };
        if (group == null) locations.add(resolvedGroup);
        (resolvedGroup['users'] as List<Map<String, Object?>>).add(user);
      }

      final resolvedUserLocationId = userLocationId?.trim();
      if (resolvedUserLocationId != null && resolvedUserLocationId.isNotEmpty) {
        addUser(resolvedUserLocationId, {
          'user_id': 'user-1',
          'user_name': 'Player One',
          'avatar': '',
        });
      }
      return _json({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'world_id': 'world-1', 'locations': locations},
      });
    }
    if (path.endsWith('/aitown-chat/internal/world/messages')) {
      worldMessagesRequests += 1;
      final locations = messagesByLocation.entries
          .map((entry) => {'location_id': entry.key, 'messages': entry.value})
          .toList(growable: false);
      return _json({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'locations': locations},
      });
    }
    if (path.endsWith('/aitown-chat/api/messages')) {
      messagesRequests += 1;
      final locationId = request.uri.queryParameters['location_id'] ?? '';
      final since = int.tryParse(request.uri.queryParameters['since'] ?? '');
      messagesRequestsByLocation[locationId] =
          (messagesRequestsByLocation[locationId] ?? 0) + 1;
      messageSinceByLocation.putIfAbsent(locationId, () => <int?>[]).add(since);
      if (failedMessageLocationIds.contains(locationId)) {
        return _json({'err_no': 500, 'err_msg': 'history failed', 'data': {}});
      }
      final allMessages =
          messagesByLocation[locationId] ?? const <Map<String, dynamic>>[];
      final requestedLimit =
          int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 20;
      final messages =
          allMessages
              .where((message) {
                final locationMessageId =
                    (message['location_message_id'] as int?) ??
                    (message['message_id'] as int?) ??
                    0;
                return since == null || since <= 0 || locationMessageId < since;
              })
              .toList(growable: false)
            ..sort((left, right) {
              final leftId =
                  (left['location_message_id'] as int?) ??
                  (left['message_id'] as int?) ??
                  0;
              final rightId =
                  (right['location_message_id'] as int?) ??
                  (right['message_id'] as int?) ??
                  0;
              return rightId.compareTo(leftId);
            });
      final page = messages
          .take(requestedLimit <= 0 ? 20 : requestedLimit)
          .toList(growable: false);
      return _json({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {
          'messages': page,
          'has_more': messages.length > page.length,
          'newest_message_id': messages.fold<int>(
            0,
            (previous, message) =>
                (message['message_id'] as int? ?? 0) > previous
                ? message['message_id'] as int
                : previous,
          ),
        },
      });
    }
    return _json({
      'err_no': 404,
      'err_msg': 'Unhandled test request: $path',
      'data': {},
    });
  }

  Map<String, Object?> _worldDetail() {
    return {
      'info': {
        'world_id': 'world-1',
        'world_name': worldName,
        'origin_id': 'origin-1',
        'origin_version': 1,
        'owner_uid': 'owner-1',
        'owner_name': 'Owner',
        'brief': 'brief',
        'setting': 'setting',
        'metric': {},
        'created_at': 1717300000000,
        'updated_at': 1717300000000,
        'status': 10,
      },
      'stats': {
        'character_cnt': 1,
        'connect_cnt': 1,
        'location_cnt': 2,
        'tick_cnt': 0,
        'player_cnt': 1,
      },
      'relation_status': 'owner',
      'characters': [
        {
          'char_id': 'char-1',
          'type': 'ai',
          'name': 'Alice',
          'avatar': 'alice.png',
          'location_id': 'loc-1',
        },
        {
          'char_id': 'char-user-1',
          'type': 'player',
          'player_uid': 'user-1',
          'name': 'Role One',
          'avatar': 'role.png',
          'location_id': 'loc-2',
        },
      ],
      'locations': [
        {
          'location_id': 'loc-root',
          'location_pid': '',
          'name': 'Town',
          'description': 'Town desc',
        },
        {
          'location_id': 'loc-1',
          'location_pid': 'loc-root',
          'name': 'Square',
          'description': 'Square desc',
        },
        {
          'location_id': 'loc-2',
          'location_pid': 'loc-root',
          'name': 'Cafe',
          'description': 'Cafe desc',
        },
      ],
      'ticks': [],
    };
  }

  TransportResponse _json(Map<String, Object?> body) {
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
  }
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _BlockingChatroomMessageStorage extends MemoryChatroomMessageStorage {
  _BlockingChatroomMessageStorage(this.blockingLocationId);

  final String blockingLocationId;
  final Completer<void> _loadCompleter = Completer<void>();
  bool blockingLoadStarted = false;

  void completeBlockingLoad() {
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
  }

  @override
  Future<List<Map<String, dynamic>>> loadLatestMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int limit,
  }) async {
    if (locationId == blockingLocationId) {
      blockingLoadStarted = true;
      await _loadCompleter.future;
    }
    return super.loadLatestMessages(
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      limit: limit,
    );
  }
}

class _SequencedChatroomTransport implements ChatroomSocketTransport {
  _SequencedChatroomTransport(this.results);

  final List<ChatroomSocket> results;
  int connectCount = 0;

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    connectCount += 1;
    if (results.isEmpty) {
      throw StateError('no socket result queued');
    }
    return results.removeAt(0);
  }
}

class _FakeChatroomTransport implements ChatroomSocketTransport {
  _FakeChatroomTransport(this.socket);

  final _FakeChatroomSocket socket;

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    return socket;
  }
}

class _BlockingChatroomTransport implements ChatroomSocketTransport {
  _BlockingChatroomTransport(this.socket, this.connectCompleter);

  final _FakeChatroomSocket socket;
  final Completer<void> connectCompleter;
  bool connectStarted = false;

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    connectStarted = true;
    await connectCompleter.future;
    return socket;
  }
}

class _FakeChatroomSocket implements ChatroomSocket {
  final _messages = StreamController<String>.broadcast();
  final sent = <String>[];
  bool closed = false;

  List<String> get sentTypes {
    return sent
        .map(
          (raw) => (jsonDecode(raw) as Map<String, dynamic>)['type'] as String,
        )
        .toList(growable: false);
  }

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> send(String message) async {
    if (closed) throw StateError('socket closed');
    sent.add(message);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    await _messages.close();
  }

  Future<void> serverClose() async {
    await _messages.close();
  }

  void serverFrame(String type, Map<String, Object?> fields) {
    _messages.add(jsonEncode(<String, Object?>{'type': type, ...fields}));
  }

  void serverJoinAck() {
    final joinFrame = sent
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .lastWhere((frame) => frame['type'] == 'join');
    serverFrame('ack', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': joinFrame['location_id'],
      'user_id': 'user-1',
      'payload': {'client_msg_id': joinFrame['client_msg_id']},
    });
  }

  void serverUserMessage({
    required int messageId,
    required int roundId,
    required String content,
    String locationId = 'loc-1',
  }) {
    serverFrame('user_message', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': locationId,
      'global_msg_id': 90000 + messageId,
      'msg_id': messageId,
      'location_msg_id': messageId,
      'conversation_round_id': roundId,
      'payload': {
        'round_order': 1,
        'sender_type': 'user',
        'sender_id': 'user-1',
        'sender_name': 'Player One',
        'content': content,
        'created_at': 1717300000000 + messageId,
      },
    });
  }
}
