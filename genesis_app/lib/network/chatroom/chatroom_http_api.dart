import 'dart:convert';

import '../api_client.dart';
import '../json_utils.dart';
import '../v1/v1_api_resource.dart';
import 'chatroom_http_models.dart';

class ChatroomHttpApi {
  const ChatroomHttpApi(this._client);

  final ApiClient _client;

  /// GET /aitown-chat/internal/world/messages
  Future<ChatroomWorldMessagesResponse> getWorldMessages({
    required String worldId,
  }) async {
    final data = await _getMap(
      'aitown-chat/internal/world/messages',
      v1Query({'world_id': _required(worldId, 'worldId')}),
    );
    return ChatroomWorldMessagesResponse.fromJson(data);
  }

  /// GET /aitown-chat/api/messages
  Future<ChatroomMessageListResponse> getMessages({
    required String worldInstanceId,
    required String locationId,
    int? since,
    int? limit,
  }) async {
    final data = await _getMap(
      'aitown-chat/api/messages',
      v1Query({
        'world_instance_id': _required(worldInstanceId, 'worldInstanceId'),
        'location_id': _required(locationId, 'locationId'),
        'since': since,
        'limit': limit,
      }),
    );
    return ChatroomMessageListResponse.fromJson(data);
  }

  /// POST /aitown-chat/internal/tick/lock
  Future<bool> lockWorld({required String worldId}) async {
    final resolvedWorldId = _required(worldId, 'worldId');
    final data = await _postMultipartMap(
      'aitown-chat/internal/tick/lock',
      fields: {'world_id': resolvedWorldId},
      query: {'world_id': resolvedWorldId},
    );
    return asBool(data['locked']);
  }

  /// GET /aitown-chat/internal/tick/progress
  Future<ChatroomTickProgress> tickProgress({required String worldId}) async {
    final data = await _getMap(
      'aitown-chat/internal/tick/progress',
      v1Query({'world_id': _required(worldId, 'worldId')}),
    );
    return ChatroomTickProgress.fromJson(data);
  }

  /// POST /aitown-chat/internal/tick/unlock
  Future<bool> unlockWorld({required String worldId}) async {
    final data = await _postMultipartMap(
      'aitown-chat/internal/tick/unlock',
      fields: {'world_id': _required(worldId, 'worldId')},
    );
    return asBool(data['unlocked']);
  }

  /// POST /aitown-chat/internal/narrator/write
  Future<int> writeNarrator({
    required String worldId,
    required String tickId,
    required List<ChatroomNarratorLocationGroup> locationGroups,
  }) async {
    final data = await _postJsonMap('aitown-chat/internal/narrator/write', {
      'world_id': _required(worldId, 'worldId'),
      'tick_id': _required(tickId, 'tickId'),
      'location_groups': locationGroups
          .map((group) => group.toJson())
          .toList(growable: false),
    });
    return asInt(data['message_id']);
  }

  Future<Map<String, dynamic>> _getMap(
    String path,
    Map<String, Object?> query,
  ) async {
    final json = await _client.get<Object?>(path, query: query);
    final data = handleV1ResponseErrNo(json);
    return data == null ? <String, dynamic>{} : asJsonMap(data);
  }

  Future<Map<String, dynamic>> _postJsonMap(
    String path,
    Map<String, Object?> body,
  ) async {
    final json = await _client.post<Object?>(path, body: body);
    final data = handleV1ResponseErrNo(json);
    return data == null ? <String, dynamic>{} : asJsonMap(data);
  }

  Future<Map<String, dynamic>> _postMultipartMap(
    String path, {
    required Map<String, String> fields,
    Map<String, Object?>? query,
  }) async {
    final boundary =
        'genesis-chatroom-${DateTime.now().microsecondsSinceEpoch}';
    final json = await _client.post<Object?>(
      path,
      query: query,
      body: _multipartFormBody(boundary: boundary, fields: fields),
      headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
    );
    final data = handleV1ResponseErrNo(json);
    return data == null ? <String, dynamic>{} : asJsonMap(data);
  }
}

String _required(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return trimmed;
}

List<int> _multipartFormBody({
  required String boundary,
  required Map<String, String> fields,
}) {
  final out = <int>[];
  void addText(String value) => out.addAll(utf8.encode(value));

  for (final entry in fields.entries) {
    addText('--$boundary\r\n');
    addText('Content-Disposition: form-data; name="${entry.key}"\r\n\r\n');
    addText('${entry.value}\r\n');
  }

  addText('--$boundary--\r\n');
  return out;
}
