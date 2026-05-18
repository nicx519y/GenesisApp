import 'dart:async';
import 'dart:io';

abstract interface class ChatroomSocket {
  Stream<String> get messages;

  Future<void> send(String message);

  Future<void> close([int? code, String? reason]);
}

abstract interface class ChatroomSocketTransport {
  Future<ChatroomSocket> connect(Uri uri, {Map<String, String>? headers});
}

class IoChatroomSocketTransport implements ChatroomSocketTransport {
  const IoChatroomSocketTransport();

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final socket = await WebSocket.connect(uri.toString(), headers: headers);
    return _IoChatroomSocket(socket);
  }
}

class _IoChatroomSocket implements ChatroomSocket {
  _IoChatroomSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages {
    return _socket.where((event) => event is String).cast<String>();
  }

  @override
  Future<void> send(String message) async {
    _socket.add(message);
  }

  @override
  Future<void> close([int? code, String? reason]) {
    return _socket.close(code, reason);
  }
}
