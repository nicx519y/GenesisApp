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
      expect(events, hasLength(1));
      expect(events.single.photo!.assetId, 9007199254740993);
      expect(service.state.messagesByLocation, before);
      expect(service.state.waitingConversationRoundIdsByLocation, waiting);
    },
  );

  for (final cached in [false, true]) {
    for (final privateCard in [false, true]) {
      test(
        'photo navigation loads a continuous window to an old target cached=$cached private=$privateCard',
        () async {
          final http = _PhotoHistoryTransport();
          final service = await _service(
            socketTransport: _FakeChatroomTransport(_FakeChatroomSocket()),
            httpTransport: http,
            useV2Protocol: true,
            refreshInitialSnapshotOnConnect: false,
          );
          addTearDown(service.dispose);
          await service.connect(worldId: 'world-1', identity: _identity());
          if (cached) {
            service.acceptLivePhoto(
              WorldChatroomMessage.fromHttpMessage(
                ChatroomHttpMessage.fromV2Json({
                  'type': 'live_photo',
                  ..._photoEnvelope('succeeded'),
                }),
              ),
            );
          }
          final result = await service.loadPhotoNavigationWindow(
            ChatPhotoTarget(
              cardId: privateCard ? 9902 : null,
              locationId: 'loc-1',
              roundId: 88,
              globalMessageId: privateCard ? 999999 : 880,
            ),
            owner: Object(),
            isCurrent: () => true,
          );
          expect(result, isNotNull);
          final ids = result!.messages.map((m) => m.locationMessageId).toList();
          expect(ids, containsAll(List.generate(241, (i) => i + 80)));
          expect(ids.last, 320);
          expect(http.roundRequests, cached ? 0 : 1);
          expect(http.pageCursors, containsAll([0, 221, 121]));
        },
      );
    }
  }
  test(
    'photo navigation cancellation never publishes its isolated target round',
    () async {
      final http = _PhotoHistoryTransport();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(_FakeChatroomSocket()),
        httpTransport: http,
        useV2Protocol: true,
        refreshInitialSnapshotOnConnect: false,
      );
      addTearDown(service.dispose);
      await service.connect(worldId: 'world-1', identity: _identity());
      final result = await service.loadPhotoNavigationWindow(
        const ChatPhotoTarget(
          locationId: 'loc-1',
          roundId: 88,
          globalMessageId: 880,
        ),
        owner: Object(),
        isCurrent: () => http.roundRequests == 0,
      );
      expect(result, isNull);
      expect(
        service.state.messagesByLocation['loc-1']?.any(
              (m) => m.globalMessageId == 880,
            ) ??
            false,
        isFalse,
      );
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
        final waiting = service.state.waitingConversationRoundIdsByLocation;
        socket.serverFrame('live_photo', _photoEnvelope(terminal));
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']!.any(
            (m) => m.photo?.status.name == terminal,
          ),
        );
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

class _PhotoHistoryTransport extends _WorldChatroomHttpTransport {
  int roundRequests = 0;
  final pageCursors = <int>[];
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    if (!request.uri.path.endsWith('/api/v2/messages') ||
        request.uri.queryParameters['location_id'] != 'loc-1') {
      return super.send(request);
    }
    final query = request.uri.queryParameters;
    final round = query['start_conversation_round_id'];
    final since = int.parse(query['since'] ?? '0');
    final limit = int.parse(query['limit'] ?? '20');
    if (round != null) {
      roundRequests++;
    } else {
      pageCursors.add(since);
    }
    final rows = [
      for (var id = 320; id >= 1; id--)
        if ((since == 0 || id < since) && (round == null || id == 80))
          id == 80
              ? {'type': 'live_photo', ..._photoEnvelope('succeeded')}
              : _asV2HttpMessage({
                  'world_id': 'world-1',
                  'location_id': 'loc-1',
                  'location_message_id': id,
                  'global_message_id': id + 1000,
                  'message_id': id + 1000,
                  'conversation_round_id': 1,
                  'sender_type': 'narrator',
                  'content': 'message $id',
                  'message_type': 'text',
                }),
    ];
    return TransportResponse(
      statusCode: 200,
      headers: {},
      body: jsonEncode({
        'err_no': 0,
        'data': {
          'messages': rows.take(limit).toList(),
          'has_more': rows.length > limit,
          'newest_message_id': 320,
        },
      }),
    );
  }
}
