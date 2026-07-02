import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'io_http_transport.dart';

const kLogWebSocketFrames = !bool.fromEnvironment('dart.vm.product');

typedef WebSocketFrameLogSink =
    void Function(String direction, String formatted);

abstract interface class NetworkWebSocket {
  Stream<String> get messages;

  Future<void> send(String message);

  Future<void> close([int? code, String? reason]);
}

abstract interface class NetworkWebSocketTransport {
  Future<NetworkWebSocket> connect(Uri uri, {Map<String, String>? headers});
}

class IoWebSocketTransport implements NetworkWebSocketTransport {
  IoWebSocketTransport({
    String? proxy,
    bool logFrames = kLogWebSocketFrames,
    String logName = 'NetworkWebSocket',
    String frameLogName = 'NetworkWebSocketFrame',
    WebSocketFrameLogSink? frameLogSink,
  }) : _client = createProxyAwareHttpClient(proxy),
       _logFrames = logFrames,
       _logName = logName,
       _frameLogName = frameLogName,
       _frameLogSink = frameLogSink;

  final HttpClient _client;
  final bool _logFrames;
  final String _logName;
  final String _frameLogName;
  final WebSocketFrameLogSink? _frameLogSink;

  @override
  Future<NetworkWebSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    developer.log('connecting $uri', name: _logName);
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: headers,
      compression: CompressionOptions.compressionOff,
      customClient: _client,
    );
    developer.log(
      'connected $uri protocol=${socket.protocol ?? ''}',
      name: _logName,
    );
    return _IoNetworkWebSocket(
      socket,
      logFrames: _logFrames,
      logName: _logName,
      frameLogName: _frameLogName,
      frameLogSink: _frameLogSink,
    );
  }
}

class _IoNetworkWebSocket implements NetworkWebSocket {
  _IoNetworkWebSocket(
    this._socket, {
    required bool logFrames,
    required String logName,
    required String frameLogName,
    required WebSocketFrameLogSink? frameLogSink,
  }) : _logFrames = logFrames,
       _logName = logName,
       _frameLogName = frameLogName,
       _frameLogSink = frameLogSink;

  final WebSocket _socket;
  final bool _logFrames;
  final String _logName;
  final String _frameLogName;
  final WebSocketFrameLogSink? _frameLogSink;

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
            name: _logName,
            error: error,
            stackTrace: stackTrace,
          );
        })
        .transform(
          StreamTransformer<String, String>.fromHandlers(
            handleDone: (sink) {
              developer.log(
                'socket closed code=${_socket.closeCode} reason=${_socket.closeReason ?? ''}',
                name: _logName,
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
      name: _logName,
    );
    return _socket.close(code, reason);
  }

  void _logFrame(String direction, String message) {
    if (!_logFrames || const bool.fromEnvironment('dart.vm.product')) return;
    final formatted = formatWebSocketFrameLog(
      direction: direction,
      message: message,
    );
    developer.log(formatted, name: _frameLogName);
    _frameLogSink?.call(direction, formatted);
  }
}

String formatWebSocketFrameLog({
  required String direction,
  required String message,
}) {
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
