import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_queue_anomaly_monitor.dart';

ChatroomQueueMessageInfo message(
  int id,
  int round,
  int cursor, {
  String client = '',
  int? global,
}) => ChatroomQueueMessageInfo(
  globalMessageId: global ?? 4666198161671324416 + id,
  messageId: id,
  locationMessageId: cursor,
  conversationRoundId: round,
  clientMsgId: client,
  type: 'narrator',
  streamType: 'llm_stream_start',
  gatewayRequestId: 'request',
  attemptNo: 1,
);

void main() {
  late ChatroomQueueAnomalyMonitor monitor;
  late List<Map<String, Object?>> reports;
  setUp(() {
    reports = [];
    monitor = ChatroomQueueAnomalyMonitor(report: reports.add);
    monitor.reset(worldId: 'w', connectionGeneration: 7);
    final base = message(1, 101, 80);
    monitor.replaceQueue('l', [base]);
    monitor.calibrate('l', [base]);
  });
  ChatroomQueueObservation? inspect(
    ChatroomQueueMessageInfo info, {
    String location = 'l',
  }) => monitor.inspect(
    location: location,
    incoming: info,
    context: {
      'connected': true,
      'reconnecting': false,
      'latest_sync_verified': true,
    },
  );
  Map<String, dynamic> details(int index) =>
      jsonDecode(reports[index]['ext_data']! as String) as Map<String, dynamic>;

  test('normal arrival advances cached IDs only after commit', () {
    final incoming = message(2, 102, 81);
    final observation = inspect(incoming);
    expect(reports, isEmpty);
    expect(monitor.latestFor('l'), (round: 101, cursor: 80));
    monitor.replaceQueue('l', [message(1, 101, 80), incoming]);
    monitor.commit(observation);
    expect(monitor.latestFor('l'), (round: 102, cursor: 81));
  });

  test(
    'old round never advances either ID and actual cursor conflict still reports',
    () {
      final abnormal = message(2, 100, 81);
      monitor.commit(inspect(abnormal));
      monitor.replaceQueue('l', [message(1, 101, 80), abnormal]);
      expect(
        reports.single['action'],
        'location_chat_queue_old_conversation_round',
      );
      expect(monitor.latestFor('l'), (round: 101, cursor: 80));
      monitor.commit(inspect(message(3, 101, 81)));
      expect(
        reports.last['action'],
        'location_chat_queue_old_location_message_id',
      );
      expect(details(1)['reason'], 'same_cursor_different_message');
      monitor.commit(inspect(message(4, 100, 82)));
      expect(
        reports.last['action'],
        'location_chat_queue_old_conversation_round',
      );
      expect(monitor.latestFor('l'), (round: 101, cursor: 80));
      monitor.commit(inspect(message(5, 102, 83)));
      expect(reports, hasLength(3));
      expect(monitor.latestFor('l'), (round: 102, cursor: 83));
    },
  );

  test(
    'oversized escaped identifiers retain valid bounded diagnostic JSON',
    () {
      final incoming = ChatroomQueueMessageInfo(
        globalMessageId: 4666198161671324418,
        messageId: 2,
        locationMessageId: 79,
        conversationRoundId: 100,
        clientMsgId: '\u0000' * 5000,
        gatewayRequestId: '\u0000' * 5000,
      );
      monitor.commit(inspect(incoming));
      expect(reports, hasLength(2));
      for (var i = 0; i < reports.length; i++) {
        expect(
          (reports[i]['ext_data']! as String).length,
          lessThanOrEqualTo(4000),
        );
        expect(details(i)['global_message_id'], '4666198161671324418');
        expect(details(i)['metadata_truncated'], true);
      }
    },
  );

  test('old cursor freezes a newer round too', () {
    monitor.commit(inspect(message(2, 102, 79)));
    expect(
      reports.single['action'],
      'location_chat_queue_old_location_message_id',
    );
    expect(monitor.latestFor('l'), (round: 101, cursor: 80));
    monitor.commit(inspect(message(3, 101, 81)));
    expect(monitor.latestFor('l'), (round: 101, cursor: 81));
  });

  test(
    'both anomalies emit independent events with lossless IDs and baseline',
    () {
      final incoming = message(2, 100, 79);
      monitor.commit(inspect(incoming));
      expect(reports.map((r) => r['action']), [
        'location_chat_queue_old_conversation_round',
        'location_chat_queue_old_location_message_id',
      ]);
      expect(reports[0]['object3'], '100');
      expect(reports[0]['object4'], '101');
      expect(reports[1]['object3'], '79');
      expect(reports[1]['object4'], '80');
      final data = details(0);
      expect(data['global_message_id'], '${incoming.globalMessageId}');
      expect(data['connection_generation'], 7);
      expect(data['queue_count'], 1);
      expect(data['latest_sync_verified'], true);
      expect(data.containsKey('content'), false);
    },
  );

  test('current cursor reused by another global ID is a collision', () {
    monitor.commit(inspect(message(2, 101, 80)));
    expect(reports, hasLength(1));
    expect(details(0)['reason'], 'same_cursor_different_message');
  });

  test(
    'subsequent chunks and repeats are not inspected after a newer message',
    () {
      final first = message(2, 101, 81);
      monitor.commit(inspect(first));
      monitor.replaceQueue('l', [first]);
      monitor.commit(inspect(message(3, 102, 82)));
      monitor.commit(inspect(first));
      monitor.commit(inspect(first));
      expect(reports, isEmpty);
    },
  );

  test(
    'HTTP or local queue identities suppress echoes while new IDs still collide',
    () {
      final old = message(2, 100, 79);
      monitor.replaceQueue('l', [message(1, 101, 80), old]);
      monitor.calibrate('l', [old]);
      monitor.commit(inspect(old));
      expect(reports, isEmpty);
      monitor.commit(inspect(message(3, 100, 79)));
      expect(reports, hasLength(2));
    },
  );

  test(
    'identity fallback recognizes client and message IDs without hiding different globals',
    () {
      final local = message(2, 101, 80, global: 0, client: 'client');
      monitor.replaceQueue('l', [local]);
      monitor.commit(inspect(message(2, 101, 80, client: 'client')));
      expect(reports, isEmpty);
      monitor.replaceQueue('l', [message(2, 101, 80, client: 'client')]);
      monitor.commit(inspect(message(3, 101, 80, client: 'client')));
      expect(reports, hasLength(1));
      monitor.replaceQueue('l', [message(9, 101, 80, global: 0)]);
      monitor.commit(inspect(message(9, 101, 80)));
      expect(reports, hasLength(1));
    },
  );

  test('missing comparison IDs skip only their own comparison', () {
    monitor.commit(inspect(message(2, 0, 81)));
    expect(monitor.latestFor('l'), (round: 101, cursor: 81));
    monitor.commit(inspect(message(3, 102, 0)));
    expect(monitor.latestFor('l'), (round: 102, cursor: 81));
    final before = monitor.observedCount;
    expect(inspect(message(0, 99, 2, global: 0)), isNull);
    expect(monitor.observedCount, before);
    expect(reports, isEmpty);
  });

  test(
    'removal rebuild excludes quarantined arrivals until HTTP verifies them',
    () {
      final abnormal = message(2, 100, 81);
      monitor.commit(inspect(abnormal));
      monitor.replaceQueue('l', [message(1, 101, 80), abnormal]);
      monitor.rebuildBaseline('l');
      expect(monitor.latestFor('l'), (round: 101, cursor: 80));
      monitor.calibrate('l', [abnormal]);
      monitor.rebuildBaseline('l');
      expect(monitor.latestFor('l'), (round: 101, cursor: 81));
      monitor.replaceQueue('l', [message(4, 90, 70)]);
      monitor.rebuildBaseline('l');
      expect(monitor.latestFor('l'), (round: 90, cursor: 70));
    },
  );

  test('locations, connections, worlds and stale commits are isolated', () {
    monitor.commit(inspect(message(2, 1, 1), location: 'other'));
    expect(reports, isEmpty);
    final pending = inspect(message(3, 102, 81));
    monitor.reset(worldId: 'next', connectionGeneration: 8);
    monitor.commit(pending);
    expect(monitor.latestFor('l'), (round: 0, cursor: 0));
    monitor.replaceQueue('l', [message(1, 101, 80)]);
    monitor.rebuildBaseline('l');
    monitor.commit(inspect(message(2, 100, 79)));
    expect(reports.last['object1'], 'next');
    expect(details(0)['connection_generation'], 8);
    monitor.clear();
    expect(monitor.observedCount, 0);
    expect(inspect(message(2, 100, 79)), isNull);
  });

  test(
    'observed identity cache stays bounded and retained queue still suppresses echoes',
    () {
      for (var i = 1; i <= 1100; i++) {
        monitor.commit(inspect(message(i + 1, 101, i + 80)));
      }
      expect(
        monitor.observedCount,
        ChatroomQueueAnomalyMonitor.maxObservedMessages,
      );
      final first = message(2, 101, 81);
      monitor.replaceQueue('l', [first]);
      monitor.commit(inspect(first));
      expect(reports, isEmpty);
    },
  );

  test(
    'failure of first report does not prevent second report or escape ingestion',
    () {
      var calls = 0;
      monitor = ChatroomQueueAnomalyMonitor(
        report: (_) {
          calls++;
          throw StateError('report failed');
        },
      );
      monitor.reset(worldId: 'w', connectionGeneration: 1);
      monitor.calibrate('l', [message(1, 101, 80)]);
      expect(
        () => monitor.commit(inspect(message(2, 100, 79))),
        returnsNormally,
      );
      expect(calls, 2);
      expect(monitor.latestFor('l'), (round: 101, cursor: 80));
    },
  );
}
