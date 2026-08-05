import 'dart:convert';

import 'package:http_profile/http_profile.dart';

import 'devtools_http_profile.dart';

const kDevToolsWebSocketProfileMaxBodyBytes = 64 * 1024;

const _redactedValue = '[REDACTED]';
const _sensitiveFieldNames = <String>{
  'api_key',
  'apikey',
  'authorization',
  'cookie',
  'password',
  'refresh_token',
  'secret',
  'set-cookie',
  'signature',
  'token',
  'x-signature',
};

class DevToolsWebSocketProfile {
  DevToolsWebSocketProfile(
    this._uri, {
    GenesisHttpProfileFactory profileFactory = _createWebSocketProfile,
    String? connectionId,
  }) : _profileFactory = profileFactory,
       _connectionId = connectionId ?? 'ws-${_nextConnectionId++}';

  static int _nextConnectionId = 1;

  final Uri _uri;
  final GenesisHttpProfileFactory _profileFactory;
  final String _connectionId;
  int _nextSequence = 1;

  Future<void> recordFrame({
    required String direction,
    required String message,
  }) async {
    if (const bool.fromEnvironment('dart.vm.product')) return;

    final isOutgoing = direction == '=>';
    final sequence = _nextSequence++;
    HttpClientRequestProfile? profile;
    try {
      final recordedAt = DateTime.now();
      final payload = _profilePayload(message);
      final requestUri = _profileUri(
        _uri,
        connectionId: _connectionId,
        sequence: sequence,
        messageType: payload.messageType,
        messageId: payload.messageId,
        locationMessageId: payload.locationMessageId,
      );
      profile = _profileFactory(
        requestStartTime: recordedAt,
        requestMethod: isOutgoing ? 'WS_SEND' : 'WS_RECV',
        requestUri: requestUri.toString(),
      );
      if (profile == null) return;

      final metadataHeaders = <String, String>{
        'x-genesis-devtools-synthetic': 'websocket-frame',
        'x-genesis-websocket-connection-id': _connectionId,
        'x-genesis-websocket-direction': isOutgoing ? 'send' : 'receive',
        'x-genesis-websocket-sequence': '$sequence',
        if (payload.messageType != null)
          'x-genesis-websocket-message-type': payload.messageType!,
        if (payload.messageId != null)
          'x-genesis-websocket-msg-id': payload.messageId!,
        if (payload.locationMessageId != null)
          'x-genesis-websocket-location-msg-id': payload.locationMessageId!,
      };
      final contentHeaders = <String, String>{
        ...metadataHeaders,
        'content-type': payload.contentType,
        'content-length': '${payload.bodyBytes.length}',
      };

      final requestData = profile.requestData;
      requestData.followRedirects = false;
      requestData.persistentConnection = true;
      requestData.headersCommaValues = isOutgoing
          ? contentHeaders
          : metadataHeaders;
      requestData.contentLength = isOutgoing ? payload.bodyBytes.length : 0;
      if (isOutgoing && payload.bodyBytes.isNotEmpty) {
        requestData.bodySink.add(payload.bodyBytes);
      }

      final responseData = profile.responseData;
      responseData.startTime = recordedAt;
      responseData.statusCode = 200;
      responseData.persistentConnection = true;
      responseData.isRedirect = false;
      responseData.headersCommaValues = <String, String>{
        ...metadataHeaders,
        'content-type': payload.contentType,
        'content-length': isOutgoing ? '0' : '${payload.bodyBytes.length}',
      };
      responseData.contentLength = isOutgoing ? 0 : payload.bodyBytes.length;
      if (!isOutgoing && payload.bodyBytes.isNotEmpty) {
        responseData.bodySink.add(payload.bodyBytes);
      }

      profile.connectionInfo = <String, dynamic>{
        'transport': 'websocket',
        'connectionId': _connectionId,
        'direction': isOutgoing ? 'send' : 'receive',
        'sequence': sequence,
      };
      profile.addEvent(
        HttpProfileRequestEvent(
          timestamp: recordedAt,
          name: isOutgoing
              ? 'WebSocket frame sent'
              : 'WebSocket frame received',
        ),
      );
    } catch (_) {
      // Profiling is diagnostic-only and must never affect WebSocket traffic.
    } finally {
      final capturedProfile = profile;
      if (capturedProfile != null) {
        try {
          await capturedProfile.requestData.close();
        } catch (_) {
          // Profiling is diagnostic-only and must never affect WebSocket traffic.
        }
        try {
          await capturedProfile.responseData.close();
        } catch (_) {
          // Profiling is diagnostic-only and must never affect WebSocket traffic.
        }
      }
    }
  }
}

HttpClientRequestProfile? _createWebSocketProfile({
  required DateTime requestStartTime,
  required String requestMethod,
  required String requestUri,
}) {
  return HttpClientRequestProfile.profile(
    requestStartTime: requestStartTime,
    requestMethod: requestMethod,
    requestUri: requestUri,
  );
}

Uri _profileUri(
  Uri uri, {
  required String connectionId,
  required int sequence,
  required String? messageType,
  required String? messageId,
  required String? locationMessageId,
}) {
  final queryParameters = <String, dynamic>{};
  for (final entry in uri.queryParametersAll.entries) {
    queryParameters[entry.key] = _isSensitiveField(entry.key)
        ? const <String>[_redactedValue]
        : entry.value;
  }
  final fragment = Uri(
    queryParameters: <String, String>{
      if (messageType != null) 'type': messageType,
      if (messageId != null) 'msg_id': messageId,
      if (locationMessageId != null) 'location_msg_id': locationMessageId,
      'connection': connectionId,
      'frame': '$sequence',
    },
  ).query;
  return uri.replace(
    userInfo: '',
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
    fragment: fragment,
  );
}

_WebSocketProfilePayload _profilePayload(String message) {
  String sanitized;
  var contentType = 'text/plain; charset=utf-8';
  String? messageType;
  String? messageId;
  String? locationMessageId;
  try {
    final decoded = jsonDecode(message);
    if (decoded is Map) {
      messageType = _profileField(decoded, 'type');
      messageId = _profileField(decoded, 'msg_id');
      locationMessageId = _profileField(decoded, 'location_msg_id');
    }
    sanitized = jsonEncode(_redactJson(decoded));
    contentType = 'application/json; charset=utf-8';
  } catch (_) {
    sanitized = _redactRawSecrets(message);
  }
  return _WebSocketProfilePayload(
    contentType: contentType,
    bodyBytes: _truncateUtf8(sanitized),
    messageType: messageType,
    messageId: messageId,
    locationMessageId: locationMessageId,
  );
}

String? _profileField(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! String && value is! num && value is! bool) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

Object? _redactJson(Object? value) {
  if (value is Map) {
    return value.map((key, nestedValue) {
      final field = '$key';
      return MapEntry(
        field,
        _isSensitiveField(field) ? _redactedValue : _redactJson(nestedValue),
      );
    });
  }
  if (value is List) return value.map(_redactJson).toList(growable: false);
  if (value is String) return _redactRawSecrets(value);
  return value;
}

bool _isSensitiveField(String field) {
  return _sensitiveFieldNames.contains(field.trim().toLowerCase());
}

String _redactRawSecrets(String value) {
  return value.replaceAllMapped(
    RegExp(r'(Bearer\s+)[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    (match) => '${match.group(1)}$_redactedValue',
  );
}

List<int> _truncateUtf8(String value) {
  final encoded = utf8.encode(value);
  if (encoded.length <= kDevToolsWebSocketProfileMaxBodyBytes) return encoded;

  final suffix = '\n...[truncated ${encoded.length} byte payload]';
  final suffixBytes = utf8.encode(suffix);
  var prefixLength = kDevToolsWebSocketProfileMaxBodyBytes - suffixBytes.length;
  var result = <int>[];
  while (prefixLength >= 0) {
    final prefix = utf8.decode(
      encoded.sublist(0, prefixLength),
      allowMalformed: true,
    );
    result = utf8.encode('$prefix$suffix');
    if (result.length <= kDevToolsWebSocketProfileMaxBodyBytes) return result;
    prefixLength -= result.length - kDevToolsWebSocketProfileMaxBodyBytes;
  }
  return suffixBytes.take(kDevToolsWebSocketProfileMaxBodyBytes).toList();
}

class _WebSocketProfilePayload {
  const _WebSocketProfilePayload({
    required this.contentType,
    required this.bodyBytes,
    required this.messageType,
    required this.messageId,
    required this.locationMessageId,
  });

  final String contentType;
  final List<int> bodyBytes;
  final String? messageType;
  final String? messageId;
  final String? locationMessageId;
}
