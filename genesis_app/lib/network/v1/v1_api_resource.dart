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

  Future<Map<String, dynamic>> getMapPreservingKeys(
    String path, [
    Map<String, Object?>? query,
  ]) async {
    final json = await client.get<Object?>('v1/$path', query: query);
    final data = handleV1ResponseErrNo(json, normalizeKeys: false);
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
/// By default it returns response `data` with object keys normalized to
/// snake_case. Opaque payloads such as map JSON can disable normalization.
Object? handleV1ResponseErrNo(Object? json, {bool normalizeKeys = true}) {
  if (json is! Map) return normalizeKeys ? _normalizeV1Keys(json) : json;
  final map = asJsonMap(json);
  final errNoRaw = map.containsKey('err_no') ? map['err_no'] : map['errNo'];
  if (errNoRaw == null) return normalizeKeys ? _normalizeV1Keys(map) : map;

  final errNo = asInt(errNoRaw);
  if (errNo == 0) {
    return normalizeKeys ? _normalizeV1Keys(map['data']) : map['data'];
  }

  throw ApiException(
    message: asString(
      map.containsKey('err_msg')
          ? map['err_msg']
          : map.containsKey('err_str')
          ? map['err_str']
          : map['errStr'],
      fallback: 'Something went wrong',
    ),
    code: errNo,
    kind: ApiExceptionKind.business,
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
