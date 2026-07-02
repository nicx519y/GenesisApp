import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../io_http_transport.dart';

const _kLogWebSocketFrames = !bool.fromEnvironment('dart.vm.product');

abstract interface class ChatroomSocket {
  Stream<String> get messages;

  Future<void> send(String message);

  Future<void> close([int? code, String? reason]);
}

abstract interface class ChatroomSocketTransport {
  Future<ChatroomSocket> connect(Uri uri, {Map<String, String>? headers});
}

class IoChatroomSocketTransport implements ChatroomSocketTransport {
  IoChatroomSocketTransport({
    String? proxy,
    bool logFrames = _kLogWebSocketFrames,
  }) : _client = createProxyAwareHttpClient(proxy),
       _logFrames = logFrames;

  final HttpClient _client;
  final bool _logFrames;

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    developer.log('connecting $uri', name: 'ChatroomSocket');
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: headers,
      compression: CompressionOptions.compressionOff,
      customClient: _client,
    );
    developer.log(
      'connected $uri protocol=${socket.protocol ?? ''}',
      name: 'ChatroomSocket',
    );
    return _IoChatroomSocket(socket, logFrames: _logFrames);
  }
}

class _IoChatroomSocket implements ChatroomSocket {
  _IoChatroomSocket(this._socket, {required bool logFrames})
    : _logFrames = logFrames;

  final WebSocket _socket;
  final bool _logFrames;

  @override
  Stream<String> get messages {
    return _socket
        .where((event) => event is String)
        .cast<String>()
        .map((message) {
          _logFrame('<=', message);
          return message;
        })
        .handleError((Object error, StackTrace stackTrace) {
          developer.log(
            'socket stream error',
            name: 'ChatroomSocket',
            error: error,
            stackTrace: stackTrace,
          );
        })
        .transform(
          StreamTransformer<String, String>.fromHandlers(
            handleDone: (sink) {
              developer.log(
                'socket closed code=${_socket.closeCode} reason=${_socket.closeReason ?? ''}',
                name: 'ChatroomSocket',
              );
              sink.close();
            },
          ),
        );
  }

  @override
  Future<void> send(String message) async {
    _logFrame('=>', message);
    _socket.add(message);
  }

  @override
  Future<void> close([int? code, String? reason]) {
    developer.log(
      'closing socket code=${code ?? ''} reason=${reason ?? ''}',
      name: 'ChatroomSocket',
    );
    return _socket.close(code, reason);
  }

  void _logFrame(String direction, String message) {
    if (!_logFrames || const bool.fromEnvironment('dart.vm.product')) return;
    final formatted = _formatFrameLog(direction: direction, message: message);
    developer.log(formatted, name: 'ChatroomSocketFrame');
    if (direction == '<=') {
      debugPrint('[ChatroomSocketFrame] $formatted');
    }
  }
}

String _formatFrameLog({required String direction, required String message}) {
  Object? decoded;
  try {
    decoded = jsonDecode(message);
  } catch (_) {
    return 'WS $direction raw\n$message';
  }
  if (decoded is Map) {
    final map = decoded.map((key, value) => MapEntry('$key', value));
    final type = _stringField(map, 'type');
    final requestType = _stringField(map, 'request_type');
    final summary = [
      'WS $direction',
      if (type != null) 'type=$type',
      if (requestType != null) 'request=$requestType',
    ].join(' ');
    return '$summary\n$message';
  }
  return 'WS $direction json\n$message';
}

String? _stringField(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}
