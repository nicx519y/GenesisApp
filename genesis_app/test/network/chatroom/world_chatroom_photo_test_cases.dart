part of 'world_chatroom_service_test.dart';

Map<String, Object?> _photo(String status) => {
  'task_id': 'photo-task',
  'client_request_id': '',
  'status': status,
  'image': status == 'succeeded'
      ? {
          'asset_id': 9,
          'image_url': 'https://example.com/photo.png',
          'description': 'A photo',
          'chat_global_message_id': '880',
        }
      : null,
  'failure': status == 'failed'
      ? {'code': 'generation_failed', 'message': 'Could not generate'}
      : null,
};
Map<String, Object?> _photoEnvelope(String status) => {
  'world_id': 'world-1',
  'location_id': 'loc-1',
  'global_message_id': 880,
  'message_id': 880,
  'location_message_id': 80,
  'conversation_round_id': 88,
  'sender_type': 'live_photo',
  'conversation_type': 'live_photo',
  'message_type': 'image',
  'created_at': '2026-11-04T01:00:00Z',
  'err_no': 0,
  'payload': {
    'content': status == 'succeeded' ? 'https://example.com/photo.png' : '',
    'photo': _photo(status),
  },
};
void _photoServiceTests() {
  test('leaving the World cancels both photo timeout timers', () async {
    final service = await _service(
      socketTransport: _FakeChatroomTransport(_FakeChatroomSocket()),
      useV2Protocol: true,
      refreshInitialSnapshotOnConnect: false,
    );
    addTearDown(service.dispose);
    await service.connect(worldId: 'world-1', identity: _identity());
    final monitor = service.photoGenerationMonitor!;
    final clock = FakeAsync()
      ..run((_) {
        monitor.start('chat', 'chat-pending', locationId: 'loc-1');
        monitor.start('camera', 'camera-pending');
      });
    expect(clock.nonPeriodicTimerCount, 2);

    final disconnecting = service.disconnect();
    expect(clock.nonPeriodicTimerCount, 0);
    expect(service.photoGenerationMonitor, isNull);
    await disconnecting;

    clock.run((_) => monitor.start('camera', 'late-old-create'));
    expect(clock.nonPeriodicTimerCount, 0);
  });

  test(
    'photo recovery merges journal and memory targets by round and retains failed reads',
    () async {
      final http = _MutationHttpTransport();
      Map<String, dynamic> card(int id, String status) => {
        'card_id': id,
        'card_index': id == 9911 ? 1 : 2,
        'is_original': id == 9911,
        'generation_state': 'succeeded',
        'created_at': '2026-11-05',
        'can_edit': true,
        'can_delete': true,
        'billing': {'status': 'not_required'},
        'messages': [
          {
            'type': 'character',
            'sender_type': 'character',
            'world_id': 'world-1',
            'location_id': 'loc-1',
            'conversation_round_id': 88,
            'global_message_id': id + 200,
            'card_id': id,
            'card_message_index': 1,
            'payload': {'content': 'Reply before photo'},
          },
          {
            'type': 'live_photo',
            'sender_type': 'live_photo',
            'world_id': 'world-1',
            'location_id': 'loc-1',
            'conversation_round_id': 88,
            'global_message_id': id + 100,
            'card_id': id,
            'card_message_index': 2,
            'payload': {
              'content': '',
              'photo': {..._photo(status), 'task_id': 'batch-$id'},
            },
          },
        ],
      };
      http.cards.addAll([card(9911, 'generating'), card(9912, 'generating')]);
      final service = await _service(
        socketTransport: _FakeChatroomTransport(_FakeChatroomSocket()),
        httpTransport: http,
        useV2Protocol: true,
        refreshInitialSnapshotOnConnect: false,
      );
      addTearDown(service.dispose);
      await service.connect(worldId: 'world-1', identity: _identity());
      final store = ChatPhotoJobStore(
        'https://chatroom.test/',
        'user-1',
        'world-1',
        'loc-1',
      );
      addTearDown(() async {
        await store.remove('batch-9911');
        await store.remove('batch-9912');
      });
      for (final id in [9911, 9912]) {
        await service.acceptPhotoReceipt(
          ChatPhotoReceipt.fromJson({
            'source': 'chat',
            'world_id': 'world-1',
            'location_id': 'loc-1',
            'conversation_round_id': 88,
            'card_id': id,
            'global_message_id': id + 100,
            'photo': {..._photo('generating'), 'task_id': 'batch-$id'},
          }),
        );
      }
      expect(await store.read(), hasLength(2));
      http.cardRequests.clear();
      await service.recoverPhotos('loc-1');
      expect(http.cardRequests, hasLength(1));
      expect(await store.read(), hasLength(2));
      http.cardError = StateError('offline');
      http.cardRequests.clear();
      await service.recoverPhotos('loc-1');
      expect(http.cardRequests, hasLength(1));
      expect(await store.read(), hasLength(2));
      http.cardError = null;
      http.cards
        ..clear()
        ..addAll([card(9911, 'succeeded'), card(9912, 'failed')]);
      http.cardRequests.clear();
      await service.recoverPhotos('loc-1');
      expect(http.cardRequests, hasLength(1));
      expect(await store.read(), isEmpty);
    },
  );

  test(
    'private card photo events never enter formal history or cursors',
    () async {
      final socket = _FakeChatroomSocket();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        useV2Protocol: true,
        refreshInitialSnapshotOnConnect: false,
      );
      addTearDown(service.dispose);
      await service.connect(worldId: 'world-1', identity: _identity());
      final before = service.state.messagesByLocation;
      final history = <String>[];
      final sub = service.historyChanges.listen(history.add);
      addTearDown(sub.cancel);
      final envelope = _photoEnvelope('generating')
        ..remove('message_id')
        ..remove('location_message_id');
      envelope['payload'] = {
        'card_id': 9902,
        'card_message_index': 3,
        'content': '',
        'photo': _photo('generating'),
      };
      socket.serverFrame('live_photo', envelope);
      await _waitFor(() => service.photoLiveRevision('photo-task') > 0);
      expect(service.state.messagesByLocation, before);
      expect(history, isEmpty);
    },
  );

  test(
    'camera result is deduplicated without chat messages, rounds or history',
    () async {
      final socket = _FakeChatroomSocket();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        useV2Protocol: true,
        refreshInitialSnapshotOnConnect: false,
      );
      addTearDown(service.dispose);
      await service.connect(worldId: 'world-1', identity: _identity());
      final events = <ChatroomPhotoResult>[];
      final sub = service.photoResults.listen(events.add);
      addTearDown(sub.cancel);
      final before = service.state.messagesByLocation;
      final waiting = service.state.waitingConversationRoundIdsByLocation;
      final clock = FakeAsync()
        ..run((_) {
          service.photoGenerationMonitor!.start('camera', 'camera-r');
        });
      expect(clock.nonPeriodicTimerCount, 1);
      final result = {
        'world_id': 'world-1',
        'err_no': 0,
        'payload': {
          'source': 'camera',
          'event_id': 'camera-result',
          'title': 'Ready',
          'summary': 'Ready',
          'photo': {
            'task_id': 'camera-task',
            'client_request_id': 'camera-r',
            'status': 'succeeded',
            'failure': null,
            'image': {
              'asset_id': '9007199254740993',
              'image_url': 'https://example.com/camera.png',
              'description': 'Camera image',
            },
          },
        },
      };
      socket.serverFrame('phone.photo.result', result);
      socket.serverFrame('phone.photo.result', result);
      await _waitFor(() => events.isNotEmpty);
      expect(clock.nonPeriodicTimerCount, 0);
      expect(events, hasLength(1));
      expect(events.single.photo!.assetId, 9007199254740993);
      expect(service.state.messagesByLocation, before);
      expect(service.state.waitingConversationRoundIdsByLocation, waiting);
    },
  );

  for (final terminal in ['failed', 'succeeded']) {
    test(
      'photo $terminal updates one message and ignores late generating',
      () async {
        final socket = _FakeChatroomSocket();
        final storage = MemoryChatroomMessageStorage();
        final service = await _service(
          socketTransport: _FakeChatroomTransport(socket),
          useV2Protocol: true,
          messageStorage: storage,
          refreshInitialSnapshotOnConnect: false,
        );
        addTearDown(service.dispose);
        await service.connect(worldId: 'world-1', identity: _identity());
        socket.serverFrame('live_photo', _photoEnvelope('generating'));
        await _waitFor(
          () =>
              service.state.messagesByLocation['loc-1']?.any(
                (m) => m.photo != null,
              ) ==
              true,
        );
        final monitor = service.photoGenerationMonitor!;
        final clock = FakeAsync()
          ..run((_) {
            monitor.start('chat', 'chat-r', locationId: 'loc-1');
          });
        monitor.observe(
          'chat',
          service.state.messagesByLocation['loc-1']!
              .firstWhere((m) => m.photo != null)
              .photo!,
          requestId: 'chat-r',
        );
        expect(clock.nonPeriodicTimerCount, 1);
        final waiting = service.state.waitingConversationRoundIdsByLocation;
        socket.serverFrame('live_photo', _photoEnvelope(terminal));
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']!.any(
            (m) => m.photo?.status.name == terminal,
          ),
        );
        expect(clock.nonPeriodicTimerCount, 0);
        socket.serverFrame('live_photo', _photoEnvelope('generating'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final photos = service.state.messagesByLocation['loc-1']!
            .where((m) => m.photo != null)
            .toList();
        expect(photos, hasLength(1));
        expect(photos.single.photo!.status.name, terminal);
        expect(photos.single.locationMessageId, 80);
        expect(service.state.waitingConversationRoundIdsByLocation, waiting);
        expect(service.replyActions?.stateFor('loc-1')?.roundId, isNot(88));
        final cached = await storage.loadLatestMessages(
          ownerUid: 'user-1',
          worldId: 'world-1',
          locationId: 'loc-1',
          limit: 200,
        );
        final restored = cached
            .map(WorldChatroomMessage.fromStorageJson)
            .where((m) => m.photo != null)
            .single;
        expect(restored.photo!.status.name, terminal);
      },
    );
  }
  test(
    'photo result before creation is merged and popup event is deduplicated',
    () async {
      final socket = _FakeChatroomSocket();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        useV2Protocol: true,
        refreshInitialSnapshotOnConnect: false,
      );
      addTearDown(service.dispose);
      await service.connect(worldId: 'world-1', identity: _identity());
      final results = <ChatroomPhotoResult>[];
      final sub = service.photoResults.listen(results.add);
      addTearDown(sub.cancel);
      final result = {
        'world_id': 'world-1',
        'location_id': 'loc-1',
        'err_no': 0,
        'payload': {
          'source': 'chat',
          'event_id': 'event-photo',
          'title': 'Ready',
          'summary': 'Ready',
          'photo': _photo('succeeded'),
        },
      };
      socket.serverFrame('phone.photo.result', result);
      socket.serverFrame('phone.photo.result', result);
      await _waitFor(() => results.isNotEmpty);
      expect(
        service.state.messagesByLocation['loc-1']?.where(
              (m) => m.photo != null,
            ) ??
            const [],
        isEmpty,
      );
      socket.serverFrame('live_photo', _photoEnvelope('generating'));
      await _waitFor(
        () =>
            service.state.messagesByLocation['loc-1']?.any(
              (m) => m.photo?.status == ChatPhotoStatus.succeeded,
            ) ==
            true,
      );
      expect(results, hasLength(1));
    },
  );
}
