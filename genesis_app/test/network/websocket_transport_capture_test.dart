import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/websocket_capture.dart';
import 'package:genesis_flutter_android/network/websocket_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'transport records SEND and RECV without changing socket messages',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final serverReceived = Completer<String>();
      final serverTask = server.first.then((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add('{"type":"character","stream_type":"llm_chunk"}');
        final message = await socket.first;
        serverReceived.complete(message as String);
        await socket.close();
      });
      final controller = WebSocketCaptureController(
        notificationBatchDuration: Duration.zero,
      );
      await controller.setEnabled(true);
      final transport = IoWebSocketTransport(
        logFrames: false,
        captureController: controller,
      );
      final socket = await transport.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/chat?token=hidden'),
      );

      final received = await socket.messages.first;
      await socket.send('{"type":"send_message","client_message_id":"c_1"}');

      expect(received, contains('llm_chunk'));
      expect(await serverReceived.future, contains('send_message'));
      await serverTask;
      expect(controller.records, hasLength(2));
      expect(
        controller.records.map((record) => record.direction),
        containsAll(<WebSocketCaptureDirection>[
          WebSocketCaptureDirection.receive,
          WebSocketCaptureDirection.send,
        ]),
      );
      expect(
        controller.records.first.connectionId,
        controller.records.last.connectionId,
      );
      expect(controller.records.map((record) => record.sequence).toSet(), <int>{
        1,
        2,
      });
    },
  );
}
