import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/photo_task.dart';
import 'package:genesis_flutter_android/network/photo_generation_monitor.dart';

import '../support/mini_phone_collect_probe.dart';

void main() {
  late MiniPhoneCollectProbe probe;
  late PhotoGenerationMonitor monitor;

  setUp(() {
    probe = MiniPhoneCollectProbe();
    monitor = PhotoGenerationMonitor('world-1');
  });

  tearDown(() {
    monitor.dispose();
    probe.dispose();
  });

  testWidgets('pending creates report once after two minutes', (tester) async {
    monitor.start('chat', 'chat-1', locationId: 'location-1');
    monitor.start('camera', 'camera-1');
    monitor.observe(
      'camera',
      const PhotoTask(
        taskId: 'task-1',
        requestId: 'camera-1',
        status: PhotoTaskStatus.generating,
      ),
    );
    await tester.pump(const Duration(seconds: 119));
    expect(await probe.take(), isEmpty);

    monitor.start('chat', 'chat-1', locationId: 'location-1');
    await tester.pump(const Duration(seconds: 1));
    final events = {for (final e in await probe.take()) e.object2: e};
    expect(events.keys, unorderedEquals(['chat', 'camera']));
    for (final event in events.values) {
      expect(event.actionType, 'monitor');
      expect(event.action, 'photo_generation_timeout');
      expect(event.object1, 'world-1');
      expect(jsonDecode(event.extData)['timeout_ms'], 120000);
    }
    expect(events['chat']!.object3, 'chat-1');
    expect(events['chat']!.object4, isEmpty);
    expect(jsonDecode(events['chat']!.extData)['location_id'], 'location-1');
    expect(events['camera']!.object4, 'task-1');

    monitor.start('chat', 'chat-1');
    monitor.start('camera', 'camera-1');
    await tester.pump(const Duration(minutes: 2));
    expect(await probe.take(), isEmpty);
  });

  testWidgets('terminal results stop the corresponding timers', (tester) async {
    monitor.start('chat', 'chat-1');
    monitor.start('camera', 'camera-1');
    monitor.start('camera', 'rejected');
    monitor.reject('camera', 'rejected');
    // The result can precede the receipt and omit the request ID.
    monitor.observe(
      'chat',
      const PhotoTask(
        taskId: 'chat-task',
        requestId: '',
        status: PhotoTaskStatus.succeeded,
      ),
    );
    monitor.observe(
      'chat',
      const PhotoTask(
        taskId: 'chat-task',
        requestId: 'chat-1',
        status: PhotoTaskStatus.generating,
      ),
    );
    monitor.observe(
      'camera',
      const PhotoTask(
        taskId: 'camera-task',
        requestId: 'camera-1',
        status: PhotoTaskStatus.failed,
      ),
    );
    await tester.pump(const Duration(minutes: 2));
    expect(await probe.take(), isEmpty);
  });

  testWidgets('chat click, receipt and late result share the first attempt', (
    tester,
  ) async {
    const source = 'chat';
    const id = 'chat-1';
    final first = monitor.recordClick(source, locationId: 'location-1');
    monitor.start(
      source,
      id,
      attemptId: first,
      locationId: 'location-1',
      roundId: 101,
      cardId: 9007199254740993,
    );
    final retry = monitor.recordClick(source, locationId: 'location-1');
    monitor.start(source, id, attemptId: retry);
    expect(first, isNot(retry));
    const receipt = PhotoTask(
      taskId: 'task-1',
      requestId: id,
      status: PhotoTaskStatus.generating,
    );
    monitor.acceptReceipt(source, id, receipt);
    monitor.acceptReceipt(source, id, receipt);
    final start = await probe.take();
    expect(start.map((e) => e.object3), ['click', 'click', 'accepted']);
    expect(start.map((e) => e.object4), [first, retry, first]);
    for (final event in start) {
      expect(event.actionType, 'event');
      expect(event.action, 'photo_generation');
      expect(event.object1, 'world-1');
      expect(event.object2, source);
    }
    expect(jsonDecode(start.first.extData), {'location_id': 'location-1'});
    final details = {
      'location_id': 'location-1',
      'client_request_id': id,
      'task_id': 'task-1',
      'conversation_round_id': '101',
      'card_id': '9007199254740993',
    };
    expect(jsonDecode(start.last.extData), details);
    await tester.pump(const Duration(minutes: 2));
    expect((await probe.take()).single.action, 'photo_generation_timeout');

    const result = PhotoTask(
      taskId: 'task-1',
      requestId: '',
      status: PhotoTaskStatus.succeeded,
      imageUrl: 'https://example.com/photo.png',
    );
    monitor.observe(source, result);
    monitor.observe(source, result);
    final event = (await probe.take()).single;
    expect(event.object3, 'succeeded');
    expect(event.object4, first);
    expect(jsonDecode(event.extData), details);
  });

  testWidgets('camera matches an early failure with or without request ID', (
    tester,
  ) async {
    for (final withId in [true, false]) {
      final id = 'camera-$withId';
      final attempt = monitor.recordClick('camera');
      monitor.start('camera', id, attemptId: attempt);
      expect((await probe.take()).single.extData, isEmpty);
      final result = PhotoTask(
        taskId: 'task-$withId',
        requestId: withId ? id : '',
        status: PhotoTaskStatus.failed,
        failureCode: 'insufficient_balance',
        failureMessage: 'Raw error text',
      );
      monitor.observe('camera', result);
      monitor.acceptReceipt(
        'camera',
        id,
        PhotoTask(
          taskId: result.taskId,
          requestId: '',
          status: PhotoTaskStatus.generating,
        ),
      );
      monitor.observe('camera', result);
      final events = await probe.take();
      expect(
        events.map((e) => e.object3),
        withId ? ['failed', 'accepted'] : ['accepted', 'failed'],
      );
      final failed = events.singleWhere((e) => e.object3 == 'failed');
      expect(failed.object4, attempt);
      expect(jsonDecode(failed.extData), {
        'client_request_id': id,
        'task_id': result.taskId,
        'failure_code': 'insufficient_balance',
      });
    }
    await tester.pump(const Duration(minutes: 2));
    expect(await probe.take(), isEmpty);
  });

  testWidgets('only balance rejection is recorded and disposal ends tracking', (
    tester,
  ) async {
    final attempt = monitor.recordClick('camera');
    monitor.start('camera', 'balance', attemptId: attempt);
    monitor.reject('camera', 'balance', errorCode: 3001);
    monitor.reject('camera', 'balance', errorCode: 21001);
    monitor.start('camera', 'other', attemptId: attempt);
    monitor.reject('camera', 'other', errorCode: 2062);
    monitor.start('camera', 'pending', attemptId: attempt);
    final events = await probe.take();
    expect(events.map((e) => e.object3), ['click', 'rejected']);
    expect(jsonDecode(events.last.extData), {
      'client_request_id': 'balance',
      'failure_code': 'insufficient_balance',
    });

    monitor.dispose();
    const result = PhotoTask(
      taskId: 'late',
      requestId: 'pending',
      status: PhotoTaskStatus.succeeded,
    );
    monitor.acceptReceipt('camera', 'pending', result);
    monitor.observe('camera', result);
    await tester.pump(const Duration(minutes: 2));
    expect(await probe.take(), isEmpty);
  });
}
