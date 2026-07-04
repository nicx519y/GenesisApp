import 'package:flutter/foundation.dart';

import '../websocket_transport.dart';

typedef ChatroomSocket = NetworkWebSocket;
typedef ChatroomSocketTransport = NetworkWebSocketTransport;

class IoChatroomSocketTransport extends IoWebSocketTransport {
  IoChatroomSocketTransport({
    super.proxy,
    super.logFrames = kLogWebSocketFrames,
  }) : super(
         logName: 'ChatroomSocket',
         frameLogName: 'ChatroomSocketFrame',
         frameLogSink: _debugPrintIncomingFrame,
       );
}

String formatChatroomSocketFrameLog({
  required String direction,
  required String message,
}) {
  return formatWebSocketFrameLog(direction: direction, message: message);
}

void _debugPrintIncomingFrame(String direction, String formatted) {
  if (direction == '<=') {
    debugPrint('[ChatroomSocketFrame] $formatted');
  }
}
