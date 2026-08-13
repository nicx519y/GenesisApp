import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/websocket_capture.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('default websocket limits are 1000 frames, 40 MB and 128 KB', () {
    final controller = WebSocketCaptureController();
    expect(controller.maxRecords, 1000);
    expect(controller.maxBodyBytes, 40 * 1024 * 1024);
    expect(controller.maxFrameBodyBytes, 128 * 1024);
  });

  test('capture and filter settings persist', () async {
    final controller = WebSocketCaptureController(
      notificationBatchDuration: Duration.zero,
    );

    await controller.setEnabled(true);
    await controller.setDirectionFilter(WebSocketCaptureDirection.receive);
    await controller.setTypeFilter(
      mode: WebSocketCaptureFilterMode.onlyShow,
      selectedTypes: const <String>{' Character ', 'ACK'},
    );

    final restored = WebSocketCaptureController(
      notificationBatchDuration: Duration.zero,
    );
    expect(await restored.loadSettings(), isTrue);
    expect(restored.directionFilter, WebSocketCaptureDirection.receive);
    expect(restored.filterMode, WebSocketCaptureFilterMode.onlyShow);
    expect(restored.selectedTypes, <String>{'character', 'ack'});
  });

  test('non-debug controller stays disabled and stores no records', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      WebSocketCaptureController.enabledStorageKey: true,
    });
    final controller = WebSocketCaptureController(
      available: false,
      notificationBatchDuration: Duration.zero,
    );

    expect(await controller.loadSettings(), isFalse);
    await controller.setEnabled(true);
    controller
        .openConnection(Uri.parse('wss://api.example/ws'))
        .recordFrame(WebSocketCaptureDirection.receive, '{"type":"character"}');

    expect(controller.enabled, isFalse);
    expect(controller.records, isEmpty);
  });

  test('captures both directions, IDs and normalized top-level type', () async {
    final controller = WebSocketCaptureController(
      notificationBatchDuration: Duration.zero,
    );
    await controller.setEnabled(true);
    final connection = controller.openConnection(
      Uri.parse('wss://api.example/ws?token=query-secret&world_id=w_1'),
    );

    connection.recordFrame(
      WebSocketCaptureDirection.send,
      jsonEncode(<String, Object?>{
        'type': ' Send_Message ',
        'client_message_id': 'client_1',
        'authorization': 'Bearer body-secret',
      }),
    );
    connection.recordFrame(
      WebSocketCaptureDirection.receive,
      jsonEncode(<String, Object?>{
        'type': 'CHARACTER',
        'stream_type': 'llm_chunk',
        'world_id': 'w_1',
        'location_id': 'loc_1',
        'global_message_id': 33809,
      }),
    );

    expect(controller.records, hasLength(2));
    final receive = controller.records.first;
    final send = controller.records.last;
    expect(receive.direction, WebSocketCaptureDirection.receive);
    expect(send.direction, WebSocketCaptureDirection.send);
    expect(receive.connectionId, send.connectionId);
    expect(receive.sequence, 2);
    expect(send.sequence, 1);
    expect(receive.typeKey, 'character');
    expect(receive.streamType, 'llm_chunk');
    expect(receive.globalMessageId, '33809');
    expect(receive.locationId, 'loc_1');
    expect(send.clientMessageId, 'client_1');
    expect(send.bodyText, contains('body-secret'));
    expect(send.uri.queryParameters['token'], 'query-secret');
  });

  test(
    'unknown, direction, only-show, hide and search filters intersect',
    () async {
      final controller = WebSocketCaptureController(
        notificationBatchDuration: Duration.zero,
      );
      await controller.setEnabled(true);
      final connection = controller.openConnection(Uri.parse('wss://host/ws'));
      connection.recordFrame(
        WebSocketCaptureDirection.receive,
        '{"type":"character","stream_type":"llm_chunk","location_id":"loc_1"}',
      );
      connection.recordFrame(
        WebSocketCaptureDirection.receive,
        '{"type":"ack","client_message_id":"client_1"}',
      );
      connection.recordFrame(WebSocketCaptureDirection.send, 'raw text');

      expect(
        controller.records.first.typeKey,
        WebSocketCaptureController.unknownTypeKey,
      );
      await controller.setDirectionFilter(WebSocketCaptureDirection.receive);
      await controller.setTypeFilter(
        mode: WebSocketCaptureFilterMode.onlyShow,
        selectedTypes: const <String>{'character'},
      );
      expect(controller.filteredRecords(), hasLength(1));
      expect(controller.filteredRecords(query: 'llm_chunk'), hasLength(1));
      expect(controller.filteredRecords(query: 'client_1'), isEmpty);

      await controller.setDirectionFilter(null);
      await controller.setTypeFilter(
        mode: WebSocketCaptureFilterMode.hide,
        selectedTypes: const <String>{'ack'},
      );
      expect(
        controller.filteredRecords().map((record) => record.typeKey),
        containsAll(<String>['character', '(unknown)']),
      );
      expect(controller.filteredRecords(), hasLength(2));
    },
  );

  test(
    'JSON without an object type and raw bearer text are retained',
    () async {
      final controller = WebSocketCaptureController(
        notificationBatchDuration: Duration.zero,
      );
      await controller.setEnabled(true);
      final connection = controller.openConnection(Uri.parse('wss://host/ws'));
      connection.recordFrame(
        WebSocketCaptureDirection.receive,
        '[{"message":"hello"}]',
      );
      connection.recordFrame(
        WebSocketCaptureDirection.receive,
        'debug Bearer raw-secret',
      );

      expect(controller.records.last.isJson, isTrue);
      expect(
        controller.records.last.typeKey,
        WebSocketCaptureController.unknownTypeKey,
      );
      expect(controller.records.first.isJson, isFalse);
      expect(controller.records.first.bodyText, contains('Bearer raw-secret'));
    },
  );

  test('oversized and oldest records are bounded safely', () async {
    final controller = WebSocketCaptureController(
      maxRecords: 2,
      maxBodyBytes: 1024,
      maxFrameBodyBytes: 32,
      notificationBatchDuration: Duration.zero,
    );
    await controller.setEnabled(true);
    final connection = controller.openConnection(Uri.parse('wss://host/ws'));
    connection.recordFrame(WebSocketCaptureDirection.receive, 'x' * 40);
    expect(controller.records.single.omitted, isTrue);
    expect(controller.records.single.byteCount, 40);
    expect(controller.records.single.bodyText, contains('omitted'));

    connection.recordFrame(WebSocketCaptureDirection.receive, '{"type":"one"}');
    connection.recordFrame(WebSocketCaptureDirection.receive, '{"type":"two"}');
    expect(controller.records, hasLength(2));
    expect(controller.records.map((record) => record.sequence), <int>[3, 2]);
  });

  test('128 KB frame is retained and larger frame is omitted', () async {
    final controller = WebSocketCaptureController(
      notificationBatchDuration: Duration.zero,
    );
    await controller.setEnabled(true);
    final connection = controller.openConnection(Uri.parse('wss://host/ws'));
    connection.recordFrame(
      WebSocketCaptureDirection.receive,
      'a' * (128 * 1024),
    );
    connection.recordFrame(
      WebSocketCaptureDirection.receive,
      'b' * (128 * 1024 + 1),
    );

    expect(controller.records.last.omitted, isFalse);
    expect(controller.records.last.bodyText.length, 128 * 1024);
    expect(controller.records.first.omitted, isTrue);
    expect(controller.records.first.bodyText, contains('omitted'));
  });

  test('clear retains enabled state and filters', () async {
    final controller = WebSocketCaptureController(
      notificationBatchDuration: Duration.zero,
    );
    await controller.setEnabled(true);
    await controller.setTypeFilter(
      mode: WebSocketCaptureFilterMode.hide,
      selectedTypes: const <String>{'heartbeat'},
    );
    controller
        .openConnection(Uri.parse('wss://host/ws'))
        .recordFrame(WebSocketCaptureDirection.receive, '{"type":"character"}');

    controller.clear();

    expect(controller.records, isEmpty);
    expect(controller.enabled, isTrue);
    expect(controller.selectedTypes, <String>{'heartbeat'});
  });

  test(
    'frame notifications are batched without delaying record storage',
    () async {
      final controller = WebSocketCaptureController(
        notificationBatchDuration: const Duration(milliseconds: 50),
      );
      await controller.setEnabled(true);
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      final connection = controller.openConnection(Uri.parse('wss://host/ws'));

      for (var index = 0; index < 10; index += 1) {
        connection.recordFrame(
          WebSocketCaptureDirection.receive,
          '{"type":"character","index":$index}',
        );
      }

      expect(controller.records, hasLength(10));
      expect(notifications, 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(notifications, 1);
      controller.dispose();
    },
  );
}
