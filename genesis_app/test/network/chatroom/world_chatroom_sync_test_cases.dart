part of 'world_chatroom_service_test.dart';

void _worldMessageSyncTests() {
  group('world message sync', () {
    Future<WorldChatroomService> create(
      _FakeChatroomSocket socket,
      _MutationHttpTransport http, {
      ChatroomSocketTransport? sockets,
      ChatroomMessageStorage? storage,
      WorldDetail? world,
    }) async {
      final service = await _service(
        socketTransport: sockets ?? _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
        useV2Protocol: true,
        refreshInitialSnapshotOnConnect: false,
        ackTimeout: const Duration(seconds: 5),
      );
      addTearDown(service.dispose);
      if (world != null) service.applyWorldSnapshot(world);
      await service.connect(worldId: 'world-1', identity: _identity());
      return service;
    }

    test(
      'connect limits reads to four and shares all queued preloads',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        final pending = <Completer<TransportResponse>>[];
        var active = 0;
        var maximum = 0;
        http.history = (_) async {
          active++;
          maximum = active > maximum ? active : maximum;
          final result = Completer<TransportResponse>();
          pending.add(result);
          try {
            return await result.future;
          } finally {
            active--;
          }
        };
        final world = _worldSnapshot().copyWith(
          locations: [
            {
              'location_id': 'parent',
              'location_pid': '',
              'location_name': 'Parent',
            },
            for (var i = 0; i < 7; i++)
              {
                'location_id': 'leaf-$i',
                'location_pid': 'parent',
                'location_name': 'Leaf $i',
              },
          ],
        );
        final service = await create(socket, http, world: world);
        final duplicate = service.initializeLeafLocationQueues();
        await _waitFor(() => pending.length == 4);
        expect(http.historyRequests, hasLength(4));
        for (final response in pending.toList()) {
          response.complete(http._page([]));
        }
        await _waitFor(() => pending.length == 7);
        for (final response in pending.skip(4)) {
          response.complete(http._page([]));
        }
        await duplicate;
        expect(maximum, 4);
        expect(http.historyRequests, hasLength(7));
        expect(
          http.historyRequests.map((r) => r.uri.queryParameters['location_id']),
          isNot(contains('parent')),
        );
        expect(
          http.historyRequests.every(
            (r) =>
                r.uri.queryParameters['since'] == '0' &&
                r.uri.queryParameters['limit'] == '20',
          ),
          true,
        );
        expect(socket.sentTypes, isNot(contains('join')));
        await service.initializeLeafLocationQueues();
        expect(http.historyRequests, hasLength(7));
      },
    );

    test('automatic reconnect restores silent tail for every leaf', () async {
      final first = _FakeChatroomSocket();
      final second = _FakeChatroomSocket();
      final http = _MutationHttpTransport()
        ..messagesByLocation['loc-1'] = [_mutationRow(1, 1, 10)];
      final service = await create(
        first,
        http,
        world: _worldSnapshot(),
        sockets: _SequencedChatroomTransport([first, second]),
      );
      await service.initializeLeafLocationQueues();
      expect(http.historyRequests, hasLength(2));
      final generation = service.messageSyncGeneration;
      http.messagesByLocation['loc-1']!.add(_mutationRow(2, 2, 11));
      http.messagesByLocation['loc-2'] = [
        {..._mutationRow(3, 1, 12), 'location_id': 'loc-2'},
      ];
      await first.serverClose();
      await _waitFor(
        () =>
            service.messageSyncGeneration > generation &&
            service.state.connected,
      );
      await service.initializeLeafLocationQueues();
      expect(http.historyRequests, hasLength(4));
      expect(
        service.state.messagesByLocation['loc-1']!.map((m) => m.messageId),
        [1, 2],
      );
      expect(service.state.messagesByLocation['loc-2']!.single.messageId, 3);
      expect(second.sentTypes, isNot(contains('join')));
    });

    test('late location tree and new leaves are synchronized once', () async {
      final socket = _FakeChatroomSocket();
      final http = _MutationHttpTransport();
      final service = await create(socket, http);
      expect(http.historyRequests, isEmpty);
      service.applyWorldSnapshot(_worldSnapshot());
      await service.initializeLeafLocationQueues();
      service.applyWorldSnapshot(
        _worldSnapshot().copyWith(
          locations: [
            ..._worldSnapshot().locations,
            {
              'location_id': 'new-leaf',
              'location_name': 'New',
              'location_pid': '',
            },
          ],
        ),
      );
      await service.initializeLeafLocationQueues();
      expect(
        http.historyRequests.map((r) => r.uri.queryParameters['location_id']),
        unorderedEquals(['loc-1', 'loc-2', 'new-leaf']),
      );
    });

    test('late old-socket HTTP cannot alter memory or disk', () async {
      final first = _FakeChatroomSocket();
      final second = _FakeChatroomSocket();
      final http = _MutationHttpTransport();
      final storage = MemoryChatroomMessageStorage();
      final late = Completer<TransportResponse>();
      http.history = (request) =>
          request.uri.queryParameters['location_id'] == 'loc-1'
          ? late.future
          : Future.value(http._page([]));
      final service = await create(
        first,
        http,
        world: _worldSnapshot(),
        storage: storage,
        sockets: _SequencedChatroomTransport([first, second]),
      );
      await _waitFor(() => http.historyRequests.length == 2);
      final oldRequest = http.historyRequests.firstWhere(
        (r) => r.uri.queryParameters['location_id'] == 'loc-1',
      );
      http.history = null;
      http.messagesByLocation['loc-1'] = [
        _mutationRow(2, 2, 11, content: 'new socket'),
      ];
      await first.serverClose();
      await _waitFor(
        () =>
            oldRequest.cancellationToken!.isCancelled &&
            service.state.connected,
      );
      await service.initializeLeafLocationQueues();
      late.complete(
        http._page([_mutationRow(1, 1, 10, content: 'obsolete')], newest: 1),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        service.state.messagesByLocation['loc-1']!.single.content,
        'new socket',
      );
      final cached = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 20,
      );
      expect(cached.single['content'], 'new socket');
    });

    test(
      'HTTP page preserves newer live content and additional messages',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        final page = Completer<TransportResponse>();
        http.history = (r) => r.uri.queryParameters['location_id'] == 'loc-1'
            ? page.future
            : Future.value(http._page([]));
        final service = await create(socket, http, world: _worldSnapshot());
        await _waitFor(() => http.historyRequests.length == 2);
        for (final id in [1, 2]) {
          socket.serverV2Message(
            type: 'character',
            senderId: 'char-1',
            senderName: 'Alice',
            messageId: id,
            locationMessageId: id,
            roundId: 10,
            content: 'live $id',
          );
        }
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']?.length == 2,
        );
        page.complete(
          http._page([_mutationRow(1, 1, 10, content: 'old body')], newest: 1),
        );
        await service.initializeLeafLocationQueues();
        expect(
          service.state.messagesByLocation['loc-1']!.map((m) => m.content),
          ['live 1', 'live 2'],
        );
      },
    );

    test('unopened location fills a real gap through one shared job', () async {
      final socket = _FakeChatroomSocket();
      final http = _MutationHttpTransport()
        ..messagesByLocation['loc-1'] = [_mutationRow(1, 1, 10)];
      final service = await create(socket, http, world: _worldSnapshot());
      await service.initializeLeafLocationQueues();
      http.messagesByLocation['loc-1'] = [
        for (var id = 1; id <= 4; id++) _mutationRow(id, id, 10),
      ];
      socket.serverV2Message(
        type: 'character',
        senderId: 'char-1',
        senderName: 'Alice',
        messageId: 4,
        locationMessageId: 4,
        roundId: 10,
        content: 'live four',
      );
      await _waitFor(
        () => service.state.messagesByLocation['loc-1']?.last.messageId == 4,
      );
      await Future.wait([
        service.repairLocationMessageGaps('loc-1'),
        service.repairLocationMessageGaps('loc-1'),
      ]);
      expect(
        service.state.messagesByLocation['loc-1']!.map(
          (m) => m.locationMessageId,
        ),
        [1, 2, 3, 4],
      );
      expect(
        http.historyRequests.where(
          (r) => r.uri.queryParameters['since'] == '4',
        ),
        hasLength(1),
      );
      expect(socket.sentTypes, isNot(contains('join')));
    });

    test(
      'unrecoverable gaps release after three reads without an event loop',
      () async {
        final socket = _FakeChatroomSocket();
        final nextSocket = _FakeChatroomSocket();
        final http = _MutationHttpTransport()
          ..messagesByLocation['loc-1'] = [_mutationRow(1, 1, 10)];
        final service = await create(
          socket,
          http,
          world: _worldSnapshot(),
          sockets: _SequencedChatroomTransport([socket, nextSocket]),
        );
        await service.initializeLeafLocationQueues();
        for (var i = 0; i < 2; i++) {
          socket.serverV2Message(
            type: 'character',
            senderId: 'char-1',
            senderName: 'Alice',
            messageId: 4,
            locationMessageId: 4,
            roundId: 10,
            content: 'live four',
          );
          await _waitFor(
            () => service.state.messagesByLocation['loc-1']?.length == 2,
          );
          await service.repairLocationMessageGaps('loc-1');
        }
        expect(
          http.historyRequests.where(
            (r) => r.uri.queryParameters['since'] == '4',
          ),
          hasLength(3),
        );
        expect(service.releasedLocationMessageGapKeys('loc-1'), {
          'loc-1\u001F1\u001F4',
        });
        final generation = service.messageSyncGeneration;
        http.messagesByLocation['loc-1'] = [
          for (var id = 1; id <= 4; id++) _mutationRow(id, id, 10),
        ];
        await socket.serverClose();
        await _waitFor(
          () =>
              service.messageSyncGeneration > generation &&
              service.state.connected,
        );
        await service.initializeLeafLocationQueues();
        expect(service.releasedLocationMessageGapKeys('loc-1'), isEmpty);
        expect(
          service.state.messagesByLocation['loc-1']!.map(
            (m) => m.locationMessageId,
          ),
          [1, 2, 3, 4],
        );
      },
    );

    test(
      'failed leaf keeps cache and retries only on explicit entry',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        var fail = true;
        http.history = (r) async {
          if (fail && r.uri.queryParameters['location_id'] == 'loc-1') {
            throw StateError('offline');
          }
          return http._page([
            if (r.uri.queryParameters['location_id'] == 'loc-1')
              _mutationRow(1, 1, 10),
          ]);
        };
        final service = await create(socket, http, world: _worldSnapshot());
        await service.initializeLeafLocationQueues();
        expect(
          service.entryForLocation('loc-1').value.phase,
          ChatroomEntryPhase.failed,
        );
        expect(
          service.entryForLocation('loc-2').value.phase,
          ChatroomEntryPhase.ready,
        );
        final reads = http.historyRequests.length;
        service.applyWorldSnapshot(_worldSnapshot());
        await Future<void>.delayed(Duration.zero);
        expect(http.historyRequests.length, reads);
        fail = false;
        await service.initializeLeafLocationQueues(locationIds: ['loc-1']);
        expect(
          service.entryForLocation('loc-1').value.phase,
          ChatroomEntryPhase.ready,
        );
      },
    );

    for (final missingFields in [false, true]) {
      test(
        'message arrival, notices, round end and join never query metadata missing=$missingFields',
        () async {
          final socket = _FakeChatroomSocket();
          final row = _mutationRow(1, 1, 10);
          if (missingFields) {
            row.remove('conversation_type');
            row.remove('trigger_uid');
          }
          final http = _MutationHttpTransport()
            ..messagesByLocation['loc-1'] = [row];
          final service = await create(socket, http, world: _worldSnapshot());
          await service.initializeLeafLocationQueues();
          final reads = http.historyRequests.length;
          var archiveChanges = 0;
          final subscription = service.historyChanges.listen(
            (_) => archiveChanges++,
          );
          addTearDown(subscription.cancel);
          socket.serverV2Message(
            type: 'character',
            senderId: 'char-1',
            senderName: 'Alice',
            messageId: 2,
            locationMessageId: 2,
            roundId: 11,
            content: 'live body',
          );
          await _waitFor(
            () => service.state.messagesByLocation['loc-1']!.length == 2,
          );
          for (final location in ['loc-1', '']) {
            socket.serverFrame('world_new_message', {
              'stream_type': '',
              'world_id': 'world-1',
              'location_id': location,
              'payload': <String, Object?>{},
              'err_no': 0,
              'err_msg': '',
            });
          }
          await _waitFor(() => archiveChanges == 3);
          socket.serverEndConversationRound(locationId: 'loc-1', roundId: 11);
          final joining = service.join(locationId: 'loc-1');
          await _waitFor(() => socket.sentTypes.contains('join'));
          final frame = socket.sent
              .map((raw) => jsonDecode(raw) as Map)
              .lastWhere((f) => f['type'] == 'join');
          socket.serverV2Ack(clientMsgId: frame['client_msg_id'] as String);
          await joining;
          await service.initializeLeafLocationQueues();
          expect(http.historyRequests.length, reads);
          expect(
            http.historyRequests.any(
              (r) => r.uri.queryParameters.containsKey(
                'start_conversation_round_id',
              ),
            ),
            false,
          );
          expect(
            service.state.messagesByLocation['loc-1']!.last.content,
            'live body',
          );
          expect(
            service.replyActions!.stateForRound('loc-1', 11)?.conversationType,
            '',
          );
        },
      );
    }

    test(
      'latest page arrives before a live gap can discard older cache',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        final storage = MemoryChatroomMessageStorage();
        await storage.mergeMessages(
          ownerUid: 'user-1',
          worldId: 'world-1',
          locationId: 'loc-1',
          messages: [
            _storageMessageJson(
              messageId: 1,
              locationId: 'loc-1',
              content: 'one',
            ),
          ],
        );
        final page = Completer<TransportResponse>();
        http.history = (r) => r.uri.queryParameters['location_id'] == 'loc-1'
            ? page.future
            : Future.value(http._page([]));
        final service = await create(
          socket,
          http,
          storage: storage,
          world: _worldSnapshot(),
        );
        await _waitFor(() => http.historyRequests.length == 2);
        socket.serverV2Message(
          type: 'character',
          senderId: 'char-1',
          senderName: 'Alice',
          messageId: 60,
          locationMessageId: 60,
          roundId: 10,
          content: 'sixty',
        );
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']?.length == 2,
        );
        expect(service.state.messagesByLocation['loc-1']!.first.messageId, 1);
        http.history = null;
        http.messagesByLocation['loc-1'] = [
          for (var id = 1; id <= 60; id++) _mutationRow(id, id, 10),
        ];
        page.complete(
          http._page(
            http.messagesByLocation['loc-1']!.skip(40).toList(),
            newest: 60,
            hasMore: true,
          ),
        );
        await service.initializeLeafLocationQueues();
        expect(
          service.state.messagesByLocation['loc-1']!.map(
            (m) => m.locationMessageId,
          ),
          List.generate(60, (i) => i + 1),
        );
      },
    );

    test(
      'range replacement supersedes an old connection page and sync resumes',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        final oldPage = Completer<TransportResponse>();
        var latestReads = 0;
        http.history = (r) async {
          if (r.uri.queryParameters['location_id'] != 'loc-1') {
            return http._page([]);
          }
          if (!r.uri.queryParameters.containsKey(
                'start_conversation_round_id',
              ) &&
              ++latestReads == 1) {
            return oldPage.future;
          }
          return http._page([
            _mutationRow(1, 1, 10, content: 'edited'),
          ], newest: 1);
        };
        final service = await create(socket, http, world: _worldSnapshot());
        await _waitFor(() => latestReads == 1);
        _rangeFrame(socket, 10, 10, newest: 1);
        await _waitFor(
          () =>
              service.state.messagesByLocation['loc-1']?.firstOrNull?.content ==
              'edited',
        );
        oldPage.complete(
          http._page([_mutationRow(1, 1, 10, content: 'obsolete')], newest: 1),
        );
        await service.initializeLeafLocationQueues();
        expect(
          service.state.messagesByLocation['loc-1']!.single.content,
          'edited',
        );
        expect(latestReads, 2);
      },
    );

    test(
      'changing world invalidates queued old-world reads before persistence',
      () async {
        final first = _FakeChatroomSocket();
        final second = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        final storage = MemoryChatroomMessageStorage();
        final late = Completer<TransportResponse>();
        http.history = (_) => late.future;
        final service = await create(
          first,
          http,
          storage: storage,
          world: _worldSnapshot(),
          sockets: _SequencedChatroomTransport([first, second]),
        );
        await _waitFor(() => http.historyRequests.length == 2);
        await service.connect(worldId: 'world-2', identity: _identity());
        late.complete(http._page([_mutationRow(1, 1, 10)], newest: 1));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          service.state.messagesByLocation.values.expand((m) => m),
          isEmpty,
        );
        expect(
          await storage.loadLatestMessages(
            ownerUid: 'user-1',
            worldId: 'world-1',
            locationId: 'loc-1',
            limit: 20,
          ),
          isEmpty,
        );
      },
    );

    test('large gap never retracts a streaming prefix', () async {
      final socket = _FakeChatroomSocket();
      final http = _MutationHttpTransport();
      final service = await create(socket, http);
      socket.serverV2StreamFrame(
        streamType: 'llm_chunk',
        senderId: 'char-1',
        messageId: 1,
        locationMessageId: 1,
        roundId: 10,
        seq: 1,
        content: 'still growing',
      );
      await _waitFor(
        () => service.state.messagesByLocation['loc-1']?.length == 1,
      );
      socket.serverV2Message(
        type: 'user',
        senderId: 'user-1',
        senderName: 'Me',
        messageId: 100,
        locationMessageId: 100,
        roundId: 20,
        content: 'later',
      );
      await _waitFor(
        () => service.state.messagesByLocation['loc-1']?.length == 2,
      );
      await service.repairLocationMessageGaps('loc-1');
      expect(service.state.messagesByLocation['loc-1']!.first.streaming, true);
      expect(
        service.state.messagesByLocation['loc-1']!.first.content,
        'still growing',
      );
      expect(http.historyRequests, isEmpty);
      expect(service.releasedLocationMessageGapKeys('loc-1'), {
        'loc-1\u001F1\u001F100',
      });
    });

    test(
      'reconnect history updates an ended stream body and its persisted row',
      () async {
        final first = _FakeChatroomSocket();
        final second = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        final storage = MemoryChatroomMessageStorage();
        final service = await create(
          first,
          http,
          storage: storage,
          world: _worldSnapshot(),
          sockets: _SequencedChatroomTransport([first, second]),
        );
        await service.initializeLeafLocationQueues();
        first.serverV2StreamFrame(
          streamType: 'llm_stream_end',
          senderId: 'char-1',
          messageId: 1,
          locationMessageId: 1,
          roundId: 10,
          content: 'before edit',
        );
        await _waitFor(
          () =>
              service
                  .state
                  .messagesByLocation['loc-1']
                  ?.singleOrNull
                  ?.content ==
              'before edit',
        );
        http.messagesByLocation['loc-1'] = [
          _mutationRow(1, 1, 10, content: 'edited while offline'),
        ];
        final generation = service.messageSyncGeneration;
        await first.serverClose();
        await _waitFor(
          () =>
              service.messageSyncGeneration > generation &&
              service.state.connected,
        );
        await service.initializeLeafLocationQueues();
        final message = service.state.messagesByLocation['loc-1']!.single;
        expect(message.content, 'edited while offline');
        expect(message.isLlmStreamMessage, true);
        expect(message.streaming, false);
        expect(message.globalMessageId, 90001);
        final cached = await storage.loadLatestMessages(
          ownerUid: 'user-1',
          worldId: 'world-1',
          locationId: 'loc-1',
          limit: 20,
        );
        expect(cached.single['content'], 'edited while offline');
        expect(cached.single['is_llm_stream'], true);
      },
    );

    test(
      'fresh HTTP can update a previously edited completed stream',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        final service = await create(socket, http);
        socket.serverV2StreamFrame(
          streamType: 'llm_stream_end',
          senderId: 'char-1',
          messageId: 1,
          locationMessageId: 1,
          roundId: 10,
          content: 'original',
        );
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']?.length == 1,
        );
        _editFrame(socket, id: 1, cursor: 1, round: 10, content: 'first edit');
        await _waitFor(
          () =>
              service.state.messagesByLocation['loc-1']!.single.content ==
              'first edit',
        );
        http.messagesByLocation['loc-1'] = [
          _mutationRow(1, 1, 10, content: 'second edit'),
        ];
        await service.refreshLatestMessages(locationId: 'loc-1');
        expect(
          service.state.messagesByLocation['loc-1']!.single.content,
          'second edit',
        );
        expect(
          service.state.messagesByLocation['loc-1']!.single.globalMessageId,
          90001,
        );
      },
    );

    test(
      'HTTP begun before a stream end cannot undo its newer final content',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        final service = await create(socket, http);
        socket.serverV2StreamFrame(
          streamType: 'llm_stream_end',
          senderId: 'char-1',
          messageId: 1,
          locationMessageId: 1,
          roundId: 10,
          content: 'old',
        );
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']?.length == 1,
        );
        final pending = Completer<TransportResponse>();
        http.history = (_) => pending.future;
        final refresh = service.refreshLatestMessages(locationId: 'loc-1');
        await _waitFor(() => http.historyRequests.length == 1);
        socket.serverV2StreamFrame(
          streamType: 'llm_stream_end',
          senderId: 'char-1',
          messageId: 1,
          locationMessageId: 1,
          roundId: 10,
          content: 'new final',
        );
        await _waitFor(
          () =>
              service.state.messagesByLocation['loc-1']!.single.content ==
              'new final',
        );
        pending.complete(
          http._page([
            _mutationRow(1, 1, 10, content: 'stale HTTP'),
          ], newest: 1),
        );
        await refresh;
        expect(
          service.state.messagesByLocation['loc-1']!.single.content,
          'new final',
        );
      },
    );

    test(
      'new formal arrivals retry a failed leaf once and restore subsequent gap repair',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        var unavailable = true;
        http.history = (r) async {
          if (r.uri.queryParameters['location_id'] == 'loc-1' && unavailable) {
            throw StateError('offline');
          }
          return http._page([]);
        };
        final storage = MemoryChatroomMessageStorage();
        await storage.mergeMessages(
          ownerUid: 'user-1',
          worldId: 'world-1',
          locationId: 'loc-1',
          messages: [
            _storageMessageJson(
              messageId: 1,
              locationId: 'loc-1',
              content: 'cached',
            ),
          ],
        );
        final service = await create(
          socket,
          http,
          world: _worldSnapshot(),
          storage: storage,
        );
        await service.initializeLeafLocationQueues();
        expect(
          service.entryForLocation('loc-1').value.phase,
          ChatroomEntryPhase.failed,
        );
        unavailable = false;
        http.history = null;
        http.messagesByLocation['loc-1'] = [
          for (var id = 1; id <= 4; id++) _mutationRow(id, id, 10),
        ];
        final reads = http.historyRequests.length;
        for (final id in [3, 3, 4]) {
          socket.serverV2Message(
            type: 'character',
            senderId: 'char-1',
            senderName: 'Alice',
            messageId: id,
            locationMessageId: id,
            roundId: 10,
            content: 'live $id',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(
          http.historyRequests.length,
          reads,
          reason: 'Live recovery backs off instead of reading on every frame',
        );
        await _waitFor(
          () =>
              service.entryForLocation('loc-1').value.phase ==
                  ChatroomEntryPhase.ready &&
              service.state.messagesByLocation['loc-1']!.length == 4,
          timeout: const Duration(seconds: 3),
        );
        expect(http.historyRequests.length, reads + 1);
        http.messagesByLocation['loc-1']!.addAll([
          _mutationRow(5, 5, 10),
          _mutationRow(6, 6, 10),
        ]);
        socket.serverV2Message(
          type: 'character',
          senderId: 'char-1',
          senderName: 'Alice',
          messageId: 6,
          locationMessageId: 6,
          roundId: 10,
          content: 'live six',
        );
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']!.any(
            (m) => m.messageId == 5,
          ),
        );
        expect(socket.sentTypes, isNot(contains('send_message')));
      },
    );

    test(
      'failed-leaf live retries are coalesced and bounded per connection',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        http.history = (r) async {
          if (r.uri.queryParameters['location_id'] == 'loc-1') {
            throw StateError('still offline');
          }
          return http._page([]);
        };
        final service = await create(socket, http, world: _worldSnapshot());
        await service.initializeLeafLocationQueues();
        int reads() => http.historyRequests
            .where((r) => r.uri.queryParameters['location_id'] == 'loc-1')
            .length;
        void frame(int id) => socket.serverV2Message(
          type: 'character',
          senderId: 'char-1',
          senderName: 'Alice',
          messageId: id,
          locationMessageId: id,
          roundId: 10,
          content: 'live $id',
        );
        frame(1);
        frame(1);
        frame(1);
        await _waitFor(() => reads() == 2, timeout: const Duration(seconds: 3));
        await Future<void>.delayed(Duration.zero);
        frame(2);
        await _waitFor(() => reads() == 3, timeout: const Duration(seconds: 4));
        await Future<void>.delayed(Duration.zero);
        for (var id = 3; id <= 10; id++) {
          frame(id);
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(reads(), 3);
        http.history = null;
        http.messagesByLocation['loc-1'] = [
          for (var id = 1; id <= 10; id++) _mutationRow(id, id, 10),
        ];
        await service.initializeLeafLocationQueues(locationIds: ['loc-1']);
        expect(
          service.entryForLocation('loc-1').value.phase,
          ChatroomEntryPhase.ready,
        );
      },
    );

    test(
      'reconnect cancels pending failed-leaf retry instead of duplicating its new sync',
      () async {
        final first = _FakeChatroomSocket();
        final second = _FakeChatroomSocket();
        final http = _MutationHttpTransport();
        http.history = (r) async {
          if (r.uri.queryParameters['location_id'] == 'loc-1') {
            throw StateError('offline');
          }
          return http._page([]);
        };
        final service = await create(
          first,
          http,
          world: _worldSnapshot(),
          sockets: _SequencedChatroomTransport([first, second]),
        );
        await service.initializeLeafLocationQueues();
        first.serverV2Message(
          type: 'character',
          senderId: 'char-1',
          senderName: 'Alice',
          messageId: 1,
          locationMessageId: 1,
          roundId: 10,
          content: 'live',
        );
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']?.length == 1,
        );
        http.history = null;
        http.messagesByLocation['loc-1'] = [_mutationRow(1, 1, 10)];
        final generation = service.messageSyncGeneration;
        await first.serverClose();
        await _waitFor(
          () =>
              service.messageSyncGeneration > generation &&
              service.state.connected,
        );
        await service.initializeLeafLocationQueues();
        final reads = http.historyRequests.length;
        await Future<void>.delayed(const Duration(milliseconds: 1150));
        expect(http.historyRequests.length, reads);
        expect(reads, 4);
      },
    );

    test(
      'gap retries wait one and two seconds and can recover on the last read',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport()
          ..messagesByLocation['loc-1'] = [_mutationRow(1, 1, 10)];
        final service = await create(socket, http, world: _worldSnapshot());
        await service.initializeLeafLocationQueues();
        final elapsed = Stopwatch()..start();
        final timestamps = <int>[];
        http.history = (r) async {
          if (r.uri.queryParameters['since'] == '4') {
            timestamps.add(elapsed.elapsedMilliseconds);
            return http._page(
              timestamps.length == 3
                  ? [_mutationRow(2, 2, 10), _mutationRow(3, 3, 10)]
                  : [],
            );
          }
          return http._page([]);
        };
        socket.serverV2Message(
          type: 'character',
          senderId: 'char-1',
          senderName: 'Alice',
          messageId: 4,
          locationMessageId: 4,
          roundId: 10,
          content: 'live four',
        );
        await _waitFor(() => timestamps.isNotEmpty);
        await service.repairLocationMessageGaps('loc-1');
        expect(timestamps, hasLength(3));
        expect(timestamps[1] - timestamps[0], greaterThanOrEqualTo(900));
        expect(timestamps[2] - timestamps[1], greaterThanOrEqualTo(1900));
        expect(
          service.state.messagesByLocation['loc-1']!.map(
            (m) => m.locationMessageId,
          ),
          [1, 2, 3, 4],
        );
        expect(service.releasedLocationMessageGapKeys('loc-1'), isEmpty);
      },
    );

    test(
      'a live fill during gap backoff avoids an unnecessary HTTP retry',
      () async {
        final socket = _FakeChatroomSocket();
        final http = _MutationHttpTransport()
          ..messagesByLocation['loc-1'] = [_mutationRow(1, 1, 10)];
        final service = await create(socket, http, world: _worldSnapshot());
        await service.initializeLeafLocationQueues();
        http.history = (_) async => http._page([]);
        void frame(int id) => socket.serverV2Message(
          type: 'character',
          senderId: 'char-1',
          senderName: 'Alice',
          messageId: id,
          locationMessageId: id,
          roundId: 10,
          content: 'live $id',
        );
        frame(4);
        await _waitFor(
          () => http.historyRequests.any(
            (r) => r.uri.queryParameters['since'] == '4',
          ),
        );
        final repair = service.repairLocationMessageGaps('loc-1');
        frame(2);
        frame(3);
        await repair;
        expect(
          http.historyRequests.where(
            (r) => r.uri.queryParameters['since'] == '4',
          ),
          hasLength(1),
        );
        expect(service.releasedLocationMessageGapKeys('loc-1'), isEmpty);
      },
    );
  });
}
