import '../api_client.dart';
import '../json_utils.dart';
import '../v1/v1_api_resource.dart';

abstract class V2ApiResource {
  const V2ApiResource(this.client);

  final ApiClient client;

  Future<Map<String, dynamic>> postMap(
    String path, [
    Object? body,
    Map<String, String>? headers,
  ]) async {
    final json = await client.post<Object?>(
      'v2/$path',
      body: body ?? const <String, Object?>{},
      headers: headers,
    );
    final data = handleV1ResponseErrNo(json);
    return data == null ? <String, dynamic>{} : asJsonMap(data);
  }
}

Map<String, Object?> v2Body(Map<String, Object?> values) {
  return {
    for (final entry in values.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
