import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/websocket_capture.dart';
import 'package:genesis_flutter_android/network/websocket_transport.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Acde7c29bc0058f1961ed/outgoing_capture.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Afa6d6e9732df53bf7030/peer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'waits for the configured periodic heartbeat before starting observation',
    () async {
      final c = WebSocketCaptureController(available: true);
      final uri = Uri.parse('ws://127.0.0.1:1234/chat?world_id=world');
      final connection = c.openConnection(uri);
      final capture = ParentOutgoingCapture(
        endpoint: uri,
        worldId: 'world',
        parentId: 'parent',
        controller: c,
        heartbeatInterval: const Duration(seconds: 6),
      );
      final timer = Timer(const Duration(seconds: 6), () {
        connection.recordFrame(
          WebSocketCaptureDirection.send,
          '{"type":"heartbeat","world_id":"world"}',
        );
      });
      try {
        await capture.start();
        expect(capture.count('send_message'), 0);
        connection.recordFrame(
          WebSocketCaptureDirection.send,
          '{"type":"send_message","world_id":"world","location_id":"parent"}',
        );
        expect(capture.count('send_message'), 1);
      } finally {
        timer.cancel();
        await capture.restore();
        c.dispose();
      }
    },
  );
  test(
    'counts real outgoing traffic before delayed receiver ownership checks finish',
    () async {
      final oldHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = oldHttpOverrides);
      var delayNext = false;
      final entered = Completer<void>(), release = Completer<void>();
      final peer = ParentPeer('world', 'qa_test_capture', () async {
        if (delayNext) {
          delayNext = false;
          entered.complete();
          await release.future;
        }
      });
      final controller = WebSocketCaptureController(available: true);
      await peer.open();
      final endpoint = Uri.parse(peer.url);
      final socket = await IoWebSocketTransport(
        captureController: controller,
      ).connect(endpoint.replace(queryParameters: {'world_id': 'world'}));
      final messages = StreamIterator(socket.messages);
      final capture = ParentOutgoingCapture(
        endpoint: endpoint,
        worldId: 'world',
        parentId: 'parent',
        controller: controller,
      );
      try {
        await capture.start(
          () => socket.send(
            jsonEncode({'type': 'heartbeat', 'world_id': 'world'}),
          ),
        );
        expect(await messages.moveNext(), true);
        delayNext = true;
        await socket.send(
          jsonEncode({
            'type': 'send_message',
            'world_id': 'world',
            'location_id': 'parent',
          }),
        );
        await entered.future.timeout(const Duration(seconds: 3));
        expect(peer.frames.where((f) => f['type'] == 'send_message'), isEmpty);
        expect(capture.count('send_message'), 1);
        release.complete();
        expect(await messages.moveNext(), true);
        await socket.send(
          jsonEncode({
            'type': 'join',
            'world_id': 'world',
            'location_id': 'child',
          }),
        );
        expect(await messages.moveNext(), true);
        expect(capture.count('join'), 0);
        await socket.send(
          jsonEncode({
            'type': 'join',
            'world_id': 'world',
            'location_id': 'parent',
          }),
        );
        expect(capture.count('join'), 1);
        expect(await messages.moveNext(), true);
        await socket.send(
          jsonEncode({
            'type': 'leave',
            'world_id': 'world',
            'location_id': 'parent',
          }),
        );
        expect(capture.count('leave'), 1);
        expect(await messages.moveNext(), true);
      } finally {
        if (!release.isCompleted) release.complete();
        await capture.restore();
        await messages.cancel();
        await socket.close();
        await peer.close();
        controller.dispose();
      }
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          WebSocketCaptureController.enabledStorageKey,
        ),
        false,
      );
    },
  );

  for (final damage in ['disabled', 'truncated', 'oversized']) {
    test('rejects $damage observations instead of reporting zero', () async {
      final c = WebSocketCaptureController(
        available: true,
        maxRecords: 2,
        maxFrameBodyBytes: 128,
      );
      final uri = Uri.parse('ws://127.0.0.1:1234/chat?world_id=world');
      final connection = c.openConnection(uri);
      final capture = ParentOutgoingCapture(
        endpoint: uri,
        worldId: 'world',
        parentId: 'parent',
        controller: c,
      );
      try {
        await capture.start(() async {
          connection.recordFrame(
            WebSocketCaptureDirection.send,
            '{"type":"heartbeat","world_id":"world"}',
          );
        });
        if (damage == 'disabled') await c.setEnabled(false);
        if (damage == 'truncated') {
          for (var i = 0; i < 3; i++) {
            connection.recordFrame(
              WebSocketCaptureDirection.send,
              '{"type":"heartbeat"}',
            );
          }
        }
        if (damage == 'oversized') {
          connection.recordFrame(WebSocketCaptureDirection.send, 'x' * 200);
        }
        expect(() => capture.count('send_message'), throwsStateError);
      } finally {
        await capture.restore();
        c.dispose();
      }
    });
  }
  for (final initial in [true, false]) {
    test('restores existing capture preference $initial', () async {
      SharedPreferences.setMockInitialValues({
        WebSocketCaptureController.enabledStorageKey: initial,
      });
      final c = WebSocketCaptureController(available: true);
      await c.loadSettings();
      final uri = Uri.parse('ws://127.0.0.1:1234/chat?world_id=world');
      final connection = c.openConnection(uri);
      final capture = ParentOutgoingCapture(
        endpoint: uri,
        worldId: 'world',
        parentId: 'parent',
        controller: c,
      );
      await capture.start(() async {
        connection.recordFrame(
          WebSocketCaptureDirection.send,
          '{"type":"heartbeat","world_id":"world"}',
        );
      });
      expect(capture.count('send_message'), 0);
      await capture.restore();
      expect(c.enabled, initial);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          WebSocketCaptureController.enabledStorageKey,
        ),
        initial,
      );
      c.dispose();
    });
  }
  test(
    'attributes V2 nested joins and locationless send/leave using the same connection',
    () async {
      final c = WebSocketCaptureController(available: true);
      final uri = Uri.parse('ws://127.0.0.1:1234/chat?world_id=world'),
          connection = c.openConnection(
            Uri.parse('ws://127.0.0.1:1234/chat?world_id=world'),
          );
      final capture = ParentOutgoingCapture(
        endpoint: uri,
        worldId: 'world',
        parentId: 'parent',
        controller: c,
      );
      void send(Map<String, Object> frame) => connection.recordFrame(
        WebSocketCaptureDirection.send,
        jsonEncode(frame),
      );
      try {
        await capture.start(() async {
          send({'type': 'heartbeat'});
        });
        send({
          'type': 'join',
          'world_id': 'world',
          'payload': {'location_id': 'parent'},
        });
        send({
          'type': 'send_message',
          'world_id': 'world',
          'payload': {'content': 'test'},
        });
        send({'type': 'leave', 'payload': {}});
        for (final type in ['join', 'send_message', 'leave']) {
          expect(capture.count(type), 1);
        }
        send({
          'type': 'send_message',
          'payload': {'content': 'unknown target'},
        });
        expect(() => capture.count('send_message'), throwsStateError);
      } finally {
        await capture.restore();
        c.dispose();
      }
    },
  );
}
