import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Session-owned loopback peer. It acknowledges only the protocol operations
/// required to connect/join/leave; it never advances the world or sends messages.
class LocationChatPeer {
  LocationChatPeer(this.worldId, this.uid);
  final String worldId, uid;
  HttpServer? _server;
  final _sockets = <WebSocket>{};
  bool closed = false;
  bool get acquired => _server != null;
  String get url => 'ws://127.0.0.1:${_server!.port}/chat';
  Future<void> open() async {
    if (_server != null || closed) throw StateError('Peer already acquired');
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      if (request.uri.path != '/chat' || request.uri.queryParameters['world_id'] != worldId || !WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      socket.listen((raw) {
        final frame = jsonDecode(raw as String) as Map<String, dynamic>;
        final type = frame['type'];
        if (!['join','leave','heartbeat'].contains(type)) return;
        socket.add(jsonEncode({
          'type':'ack','world_id':worldId,'user_id':uid,
          'session_id':'qa-location-session','location_id':frame['location_id'] ?? '',
          'err_no':0,'client_msg_id':frame['client_msg_id'],'payload':<String,dynamic>{},
        }));
      }, onDone: () => _sockets.remove(socket), onError: (Object error) { _sockets.remove(socket); });
    });
  }
  Future<bool> probe() async {
    if (closed || _server == null) return false;
    final socket = await WebSocket.connect('$url?world_id=$worldId');
    try {
      socket.add(jsonEncode({'type':'heartbeat','client_msg_id':'qa-probe'}));
      final raw = jsonDecode(await socket.first.timeout(const Duration(seconds:3)) as String) as Map;
      return raw['type'] == 'ack' && raw['world_id'] == worldId && raw['client_msg_id'] == 'qa-probe';
    } finally { await socket.close(); }
  }
  Future<void> close() async {
    if (_server == null) throw StateError('No peer acquired');
    for (final socket in _sockets.toList()) { await socket.close(); }
    _sockets.clear();
    await _server!.close(force:true);
    closed = true;
  }
}
