part of 'genesis_api.dart';

HttpTransport? _resolveTransport({
  required HttpTransport? transport,
  required bool? useMock,
}) {
  if (transport != null) return transport;
  const apiEnvironment = String.fromEnvironment('GENESIS_API_ENV');
  final environmentUseMock = _mockEnabledByApiEnvironment(apiEnvironment);
  final enabled = useMock ?? environmentUseMock ?? false;
  if (!enabled || !kLocalMockTransportAvailable) return null;
  return createLocalMockGenesisTransport();
}

List<Map<String, dynamic>> _payloadMapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw.map((item) => asJsonMap(item)).toList(growable: false);
}

List<String>? _createOriginStringList(Object? raw) {
  if (raw is! List) return null;
  final values = raw
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? null : values;
}

List<String> _createOriginEventStrings(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((item) {
        if (item is Map) {
          return asString(item['content'], fallback: asString(item['event']));
        }
        return '$item';
      })
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _createOriginOptionalString(Object? raw) {
  final value = asString(raw).trim();
  return value.isEmpty ? null : value;
}

Object? _createOriginImageInput(Object? raw) {
  if (raw is Map) return asJsonMap(raw);
  return _createOriginOptionalString(raw);
}

int? _createOriginOptionalInt(Object? raw) {
  if (raw == null) return null;
  if (raw is String && raw.trim().isEmpty) return null;
  return asInt(raw);
}

String _originIdFromUpsert(
  Map<String, dynamic> response, {
  String fallback = '',
}) {
  final detail = response['info'] is Map
      ? asJsonMap(response['info'])
      : response['origin'] is Map
      ? asJsonMap(response['origin'])
      : response;
  return asString(
    detail['origin_id'],
    fallback: asString(
      detail['oid'],
      fallback: asString(response['origin_id'], fallback: fallback),
    ),
  );
}

String? _createOriginTickDurationTime(Map<String, dynamic> payload) {
  final value = _createOriginOptionalString(payload['tick_duration_time']);
  if (value != null) return value;
  final days = _createOriginOptionalInt(payload['tick_duration_days']);
  if (days == null) return null;
  return days == 1 ? '1 day' : '$days days';
}

List<Map<String, dynamic>> _createOriginCharacters(
  Map<String, dynamic> payload,
) {
  final locations = _payloadMapList(payload['location_list']);
  final initialLocationByCharacter = <String, String>{};
  for (final location in locations) {
    final locationId = asString(location['location_id']).trim();
    final characterIds = location['initial_character_ids'];
    if (locationId.isEmpty || characterIds is! List) continue;
    for (final charIdRaw in characterIds) {
      final charId = '$charIdRaw'.trim();
      if (charId.isNotEmpty) initialLocationByCharacter[charId] = locationId;
    }
  }

  return _payloadMapList(payload['character_list'])
      .map((item) {
        final charId = asString(item['char_id']).trim();
        return <String, dynamic>{
          if (charId.isNotEmpty) 'char_id': charId,
          'name': asString(item['name']),
          'identity': asString(item['identity']),
          'personality': asString(
            item['personality'],
            fallback: asString(
              item['tagline'],
              fallback: asString(item['brief']),
            ),
          ),
          if (item.containsKey('bio') || item.containsKey('description'))
            'bio': asString(
              item['bio'],
              fallback: asString(item['description']),
            ),
          'goal': asString(item['goal']),
          'avatar': _createOriginImageInput(item['avatar']) ?? '',
          'initial_location_id': asString(
            item['initial_location_id'],
            fallback: initialLocationByCharacter[charId] ?? '',
          ),
        };
      })
      .toList(growable: false);
}

List<Map<String, dynamic>> _createOriginLocations(
  Map<String, dynamic> payload,
) {
  final rawLocations = _payloadMapList(payload['location_list']);
  return rawLocations
      .map((item) {
        return <String, dynamic>{
          if (asString(item['location_id']).trim().isNotEmpty)
            'location_id': asString(item['location_id']).trim(),
          if (asString(item['location_pid']).trim().isNotEmpty)
            'location_pid': asString(item['location_pid']).trim(),
          'level': asInt(item['level']),
          'location_name': asString(
            item['location_name'],
            fallback: asString(item['name']),
          ),
          'location_description': asString(
            item['location_description'],
            fallback: asString(
              item['description'],
              fallback: asString(item['location_summary']),
            ),
          ),
          'location_summary': asString(item['location_summary']),
          'image':
              _createOriginImageInput(item['image']) ??
              _createOriginImageInput(item['icon']) ??
              '',
          'x_percent': asInt(item['x_percent']),
          'y_percent': asInt(item['y_percent']),
          'map_url': asString(item['map_url']),
        };
      })
      .toList(growable: false);
}

bool? _mockEnabledByApiEnvironment(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  if (normalized == 'mock' || normalized == 'local' || normalized == 'debug') {
    return true;
  }
  if (normalized == 'production' ||
      normalized == 'prod' ||
      normalized == 'real') {
    return false;
  }
  return null;
}

bool _isAuthFailureStatus(int? statusCode) {
  return statusCode == 401 || statusCode == 403;
}

Object? _defaultGenesisProcessor(ApiResponse response) {
  final ok = response.statusCode >= 200 && response.statusCode < 300;
  if (ok) return response.data;

  final data = response.data;
  if (data is Map) {
    final error = data['error'];
    if (error != null && error.toString().trim().isNotEmpty) {
      throw ApiException(
        message: error.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        responseHeaders: response.headers,
        uri: response.uri,
        kind: ApiExceptionKind.httpStatus,
      );
    }
  }

  throw ApiException(
    message: 'Something went wrong',
    statusCode: response.statusCode,
    responseBody: response.body,
    responseHeaders: response.headers,
    uri: response.uri,
    kind: ApiExceptionKind.httpStatus,
  );
}

String _normalizeBaseUrl(String url) {
  return normalizeRemoteUrl(url);
}

String normalizeRemoteUrl(String url) {
  final noBackticks = url.replaceAll('`', '').trim();
  return noBackticks.replaceAll(
    RegExp(r'[\u00A0\u2000-\u200B\u202F\u205F\u3000]'),
    '',
  );
}

String resolveAssetUrl(String raw) {
  final value = normalizeRemoteUrl(raw);
  if (value.isEmpty) return '';
  if (value.startsWith('assets/')) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  final base = GenesisApi.defaultAssetBaseUrl;
  if (value.startsWith('/')) return '$base${value.substring(1)}';
  return '$base$value';
}

GenesisImageResource _resolveImageAssetResource(
  Object? raw, {
  Object? fallback,
}) {
  final resource = GenesisImageResource.fromJson(
    raw,
    fallback: fallback,
  ).mapUrls(resolveAssetUrl);
  return GenesisImageResourceRegistry.register(resource);
}

String _resolveImageAssetUrl(Object? raw, {Object? fallback}) {
  return _resolveImageAssetResource(raw, fallback: fallback).displayUrl;
}

int _pageFromOffset({required int limit, required int offset}) {
  if (limit <= 0 || offset <= 0) return 1;
  return (offset ~/ limit) + 1;
}
