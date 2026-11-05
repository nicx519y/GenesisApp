part of 'world_chatroom_service_test.dart';

void _queueAnomalyServiceTests() {
  group('socket queue anomaly monitoring', () {
    late _FakeChatroomSocket socket;
    late _MutationHttpTransport http;
    late MemoryChatroomMessageStorage storage;
    late ChatroomQueueAnomalyMonitor monitor;
    late WorldChatroomService service;
    late List<Map<String, Object?>> reports;

    setUp(() async {
      socket = _FakeChatroomSocket();
      http = _MutationHttpTransport()
        ..messagesByLocation['loc-1'] = [_mutationRow(1, 80, 101)];
      storage = MemoryChatroomMessageStorage();
      reports = [];
      monitor = ChatroomQueueAnomalyMonitor(report: reports.add);
      service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
        queueAnomalyMonitor: monitor,
        useV2Protocol: true,
        refreshInitialSnapshotOnConnect: false,
      );
      service.applyWorldSnapshot(_worldSnapshot());
      await service.connect(worldId: 'world-1', identity: _identity());
      await service.initializeLeafLocationQueues();
      addTearDown(() => service.dispose());
      expect(reports, isEmpty);
      expect(monitor.latestFor('loc-1'), (round: 101, cursor: 80));
    });

    Future<void> arrive(int id, int round, int cursor) async {
      socket.serverV2Message(
        type: 'character',
        senderId: 'char-1',
        senderName: 'Alice',
        messageId: id,
        locationMessageId: cursor,
        roundId: round,
        content: 'live $id',
      );
      await _waitFor(
        () => service.state.messagesByLocation['loc-1']!.any(
          (m) => m.globalMessageId == 90000 + id,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    test(
      'anomalies enter memory and disk without advancing either cached ID',
      () async {
        await arrive(2, 100, 81);
        await arrive(3, 100, 82);
        expect(reports.map((r) => r['action']), [
          'location_chat_queue_old_conversation_round',
          'location_chat_queue_old_conversation_round',
        ]);
        expect(monitor.latestFor('loc-1'), (round: 101, cursor: 80));
        await arrive(4, 101, 81);
        expect(
          reports.last['action'],
          'location_chat_queue_old_location_message_id',
        );
        final ext = jsonDecode(reports.last['ext_data']! as String) as Map;
        expect(ext['reason'], 'same_cursor_different_message');
        expect(ext['latest_sync_verified'], true);
        await arrive(5, 102, 83);
        expect(monitor.latestFor('loc-1'), (round: 102, cursor: 83));
        expect(reports, hasLength(3));
        await Future<void>.delayed(Duration.zero);
        final stored = await storage.loadLatestMessages(
          ownerUid: 'user-1',
          worldId: 'world-1',
          locationId: 'loc-1',
          limit: 20,
        );
        expect(stored.any((m) => m['global_message_id'] == 90003), true);
      },
    );

    for (final attempt in [false, true]) {
      test(
        'first stream arrival only is checked, including interleaving and end cleanup attempt=$attempt',
        () async {
          void frame(String type, {int number = 1, int id = 2}) {
            socket.serverFrame('character', {
              'stream_type': type,
              'world_id': 'world-1',
              'location_id': 'loc-1',
              'global_message_id': 90000 + id,
              'message_id': id,
              'location_message_id': 81,
              'conversation_round_id': 100,
              if (attempt) ...{
                'gateway_request_id': 'stream-request',
                'attempt_no': number,
              },
              'sender_type': 'character',
              'sender_id': 'char-1',
              'payload': {'seq': 1, 'content': 'stream body'},
              'err_no': 0,
            });
          }

          frame('llm_stream_start');
          await _waitFor(() => reports.length == 1);
          await arrive(3, 102, 82);
          frame('llm_chunk');
          frame('llm_stream_end');
          frame('llm_stream_end');
          await _waitFor(
            () => service.state.messagesByLocation['loc-1']!.any(
              (m) => m.globalMessageId == 90002 && !m.streaming,
            ),
          );
          await Future<void>.delayed(Duration.zero);
          expect(reports, hasLength(1));
          expect(monitor.latestFor('loc-1'), (round: 102, cursor: 82));
          if (attempt) {
            socket.serverFrame('llm_generation_state', {
              'world_id': 'world-1',
              'location_id': 'loc-1',
              'conversation_round_id': 100,
              'gateway_request_id': 'stream-request',
              'payload': {
                'state': 'failed',
                'retract_attempt_no': 1,
                'reason_code': 'test',
              },
              'err_no': 0,
            });
            frame('llm_stream_start', id: 4);
            await Future<void>.delayed(const Duration(milliseconds: 20));
            expect(reports, hasLength(1));
            expect(
              service.state.messagesByLocation['loc-1']!.any(
                (m) => m.globalMessageId == 90004,
              ),
              false,
            );
          }
        },
      );
    }

    test(
      'HTTP calibration, local restore and known historical echoes never report',
      () async {
        http.messagesByLocation['loc-1'] = [
          _mutationRow(9, 79, 100),
          _mutationRow(1, 80, 101),
        ];
        await service.refreshLatestMessages(locationId: 'loc-1');
        await arrive(9, 100, 79);
        expect(reports, isEmpty);
        await arrive(10, 100, 79);
        expect(reports, hasLength(2));
        await service.refreshLatestMessages(locationId: 'loc-1');
        expect(reports, hasLength(2));
      },
    );

    test(
      'authoritative range deletion rebuilds baseline without extra reports',
      () async {
        http.messagesByLocation['loc-1'] = [];
        _rangeFrame(socket, 101, 101);
        await _waitFor(
          () => service.state.messagesByLocation['loc-1']!.isEmpty,
        );
        expect(monitor.latestFor('loc-1'), (round: 0, cursor: 0));
        expect(reports, isEmpty);
        await arrive(2, 100, 79);
        expect(reports, isEmpty);
        expect(monitor.latestFor('loc-1'), (round: 100, cursor: 79));
      },
    );

    test(
      'HTTP responses cannot calibrate IDs from a newer substituted live message',
      () async {
        final pending = Completer<TransportResponse>();
        http.history = (_) => pending.future;
        final refresh = service.refreshLatestMessages(locationId: 'loc-1');
        await _waitFor(() => http.historyRequests.length >= 3);
        await arrive(2, 100, 81);
        pending.complete(http._page([_mutationRow(1, 80, 101)]));
        await refresh;
        expect(monitor.latestFor('loc-1'), (round: 101, cursor: 80));
        expect(reports, hasLength(1));
      },
    );

    test(
      'reconnect seeds retained queue before its new latest-page request completes',
      () async {
        await service.dispose();
        final second = _FakeChatroomSocket();
        socket = _FakeChatroomSocket();
        service = await _service(
          socketTransport: _SequencedChatroomTransport([socket, second]),
          httpTransport: http,
          messageStorage: storage,
          queueAnomalyMonitor: monitor,
          useV2Protocol: true,
          refreshInitialSnapshotOnConnect: false,
        );
        service.applyWorldSnapshot(_worldSnapshot());
        await service.connect(worldId: 'world-1', identity: _identity());
        await service.initializeLeafLocationQueues();
        final pending = Completer<TransportResponse>();
        http.history = (_) => pending.future;
        final generation = service.messageSyncGeneration;
        await socket.serverClose();
        await _waitFor(
          () =>
              service.state.connected &&
              service.messageSyncGeneration > generation,
        );
        socket = second;
        await arrive(2, 100, 81);
        expect(reports, hasLength(1));
        expect(monitor.latestFor('loc-1'), (round: 101, cursor: 80));
        final ext = jsonDecode(reports.single['ext_data']! as String) as Map;
        expect(ext['latest_sync_verified'], false);
        pending.complete(http._page([_mutationRow(1, 80, 101)]));
        await service.initializeLeafLocationQueues();
      },
    );

    test(
      'reporter failures leave formal messages ingested and persisted',
      () async {
        await service.dispose();
        var calls = 0;
        monitor = ChatroomQueueAnomalyMonitor(
          report: (_) {
            calls++;
            throw StateError('collector unavailable');
          },
        );
        socket = _FakeChatroomSocket();
        service = await _service(
          socketTransport: _FakeChatroomTransport(socket),
          httpTransport: http,
          messageStorage: storage,
          queueAnomalyMonitor: monitor,
          useV2Protocol: true,
          refreshInitialSnapshotOnConnect: false,
        );
        service.applyWorldSnapshot(_worldSnapshot());
        await service.connect(worldId: 'world-1', identity: _identity());
        await service.initializeLeafLocationQueues();
        await arrive(2, 100, 79);
        expect(calls, 2);
        expect(monitor.latestFor('loc-1'), (round: 101, cursor: 80));
        final stored = await storage.loadLatestMessages(
          ownerUid: 'user-1',
          worldId: 'world-1',
          locationId: 'loc-1',
          limit: 20,
        );
        expect(stored.any((m) => m['global_message_id'] == 90002), true);
      },
    );

    test(
      'clearing cache resets baseline and first arrival is normal',
      () async {
        await arrive(2, 100, 81);
        await service.clearCachedMessages();
        expect(monitor.latestFor('loc-1'), (round: 0, cursor: 0));
        await arrive(3, 99, 70);
        expect(reports, hasLength(1));
        expect(monitor.latestFor('loc-1'), (round: 99, cursor: 70));
      },
    );
  });
}
