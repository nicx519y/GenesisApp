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
    monitor.finish('camera', 'rejected');
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
}
