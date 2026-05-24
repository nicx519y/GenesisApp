import 'dart:convert';

import '../api_client.dart';
import '../api_exception.dart';
import '../json_utils.dart';

abstract class V1ApiResource {
  const V1ApiResource(this.client);

  final ApiClient client;

  Future<Map<String, dynamic>> getMap(
    String path, [
    Map<String, Object?>? query,
  ]) async {
    final data = await getData(path, query);
    return data == null ? <String, dynamic>{} : asJsonMap(data);
  }

  Future<Object?> getData(String path, [Map<String, Object?>? query]) async {
    final json = await client.get<Object?>('v1/$path', query: query);
    return handleV1ResponseErrNo(json);
  }

  Future<Map<String, dynamic>> postMap(
    String path, [
    Object? body,
    Map<String, String>? headers,
  ]) async {
    final data = await postData(path, body, headers);
    return data == null ? <String, dynamic>{} : asJsonMap(data);
  }

  Future<void> postVoid(String path, [Object? body]) async {
    await postData(path, body, null);
  }

  Future<Object?> postData(
    String path, [
    Object? body,
    Map<String, String>? headers,
  ]) async {
    final json = await client.post<Object?>(
      'v1/$path',
      body: body ?? const <String, Object?>{},
      headers: headers,
    );
    return handleV1ResponseErrNo(json);
  }
}

/// Handles the shared v1 response envelope:
/// `{"err_no":0,"err_msg":"succ","data":...}`.
///
/// It also accepts the legacy spellings `err_str`, `errNo`, and `errStr`,
/// then returns response `data` with all object keys normalized to snake_case.
Object? handleV1ResponseErrNo(Object? json) {
  if (json is! Map) return _normalizeV1Keys(json);
  final map = asJsonMap(json);
  final errNoRaw = map.containsKey('err_no') ? map['err_no'] : map['errNo'];
  if (errNoRaw == null) return _normalizeV1Keys(map);

  final errNo = asInt(errNoRaw);
  if (errNo == 0) return _normalizeV1Keys(map['data']);

  throw ApiException(
    message: asString(
      map.containsKey('err_msg')
          ? map['err_msg']
          : map.containsKey('err_str')
          ? map['err_str']
          : map['errStr'],
      fallback: 'API error',
    ),
  );
}

Map<String, Object?> v1Query(Map<String, Object?> values) {
  return {
    for (final entry in values.entries)
      if (entry.value != null && entry.value.toString().trim().isNotEmpty)
        entry.key: entry.value,
  };
}

Map<String, Object?> v1Body(Map<String, Object?> values) {
  return {
    for (final entry in values.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}

List<int> multipartBody({
  required String boundary,
  required List<int> bytes,
  required String bizType,
  required String filename,
  required String contentType,
}) {
  final out = <int>[];
  void addText(String value) => out.addAll(utf8.encode(value));

  addText('--$boundary\r\n');
  addText('Content-Disposition: form-data; name="biz_type"\r\n\r\n');
  addText('$bizType\r\n');
  addText('--$boundary\r\n');
  addText(
    'Content-Disposition: form-data; name="file"; filename="$filename"\r\n',
  );
  addText('Content-Type: $contentType\r\n\r\n');
  out.addAll(bytes);
  addText('\r\n--$boundary--\r\n');
  return out;
}

Object? _normalizeV1Keys(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        _camelToSnake(entry.key.toString()): _normalizeV1Keys(entry.value),
    };
  }
  if (value is List) {
    return value.map(_normalizeV1Keys).toList(growable: false);
  }
  return value;
}

String _camelToSnake(String value) {
  return value.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}
