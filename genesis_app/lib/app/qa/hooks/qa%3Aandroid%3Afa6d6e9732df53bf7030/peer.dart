import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Captures real frames before acknowledging them; foreign worlds are rejected.
class ParentPeer {
  ParentPeer(this.worldId, this.uid, this.requireOwner);
  final String worldId, uid;
  final Future<void> Function() requireOwner;
  HttpServer? _server;
  final _sockets = <WebSocket>{};
  final frames = <Map<String, dynamic>>[];
  final errors = <Object>[];
  bool closed = false;
  bool get acquired => _server != null;
  bool get connected => !closed && _sockets.isNotEmpty;
  String get url => 'ws://127.0.0.1:${_server!.port}/chat';
  Future<void> open() async {
    await requireOwner();
    if (acquired || closed) throw StateError('Peer already acquired');
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(
      (request) async {
        try {
          await requireOwner();
          if (request.uri.path != '/chat' ||
              request.uri.queryParameters['world_id'] != worldId ||
              !WebSocketTransformer.isUpgradeRequest(request)) {
            request.response.statusCode = 404;
            await request.response.close();
            return;
          }
          final socket = await WebSocketTransformer.upgrade(request);
          _sockets.add(socket);
          socket.listen(
            (raw) async {
              try {
                await requireOwner();
                final frame = Map<String, dynamic>.from(
                  jsonDecode(raw as String) as Map,
                );
                frames.add({...frame, 'sequence': frames.length + 1});
                if ([
                  'join',
                  'leave',
                  'heartbeat',
                  'send_message',
                ].contains(frame['type']))
                  socket.add(
                    jsonEncode({
                      'type': 'ack',
                      'world_id': worldId,
                      'user_id': uid,
                      'session_id': 'parent-$uid',
                      'location_id': frame['location_id'] ?? '',
                      'client_msg_id': frame['client_msg_id'],
                      'err_no': 0,
                      'payload': <String, dynamic>{},
                    }),
                  );
              } catch (e) {
                errors.add(e);
              }
            },
            onDone: () => _sockets.remove(socket),
            onError: (Object e) {
              errors.add(e);
              _sockets.remove(socket);
            },
          );
        } catch (e) {
          errors.add(e);
        }
      },
      onError: (Object e) {
        errors.add(e);
      },
    );
  }

  Future<void> close() async {
    if (!acquired) throw StateError('No peer acquired');
    for (final s in _sockets.toList()) {
      await s.close();
    }
    _sockets.clear();
    await _server!.close(force: true);
    closed = true;
    if (errors.isNotEmpty)
      throw StateError('Peer errors: ${errors.join(' | ')}');
  }
}
