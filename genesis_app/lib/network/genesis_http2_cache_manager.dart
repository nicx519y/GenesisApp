import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'dio_http_transport.dart';
import 'http_transport.dart';

class GenesisHttp2CacheManager extends CacheManager with ImageCacheManager {
  GenesisHttp2CacheManager._()
    : super(
        Config(DefaultCacheManager.key, fileService: GenesisHttp2FileService()),
      );

  static final GenesisHttp2CacheManager instance = GenesisHttp2CacheManager._();

  factory GenesisHttp2CacheManager() => instance;
}

class GenesisHttp2FileService extends FileService {
  GenesisHttp2FileService({HttpTransport? transport, this.timeoutMs = 120000})
    : _transport = transport ?? DioHttpTransport();

  final HttpTransport _transport;
  final int timeoutMs;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _transport.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: headers ?? const <String, String>{},
        bodyBytes: null,
        timeoutMs: timeoutMs,
      ),
    );
    return GenesisHttp2FileServiceResponse(response);
  }
}

class GenesisHttp2FileServiceResponse implements FileServiceResponse {
  GenesisHttp2FileServiceResponse(this.response) : _receivedAt = DateTime.now();

  final TransportResponse response;
  final DateTime _receivedAt;

  @override
  Stream<List<int>> get content => Stream<List<int>>.value(response.bodyBytes);

  @override
  int? get contentLength =>
      response.responsePayloadSizeBytes ??
      _nonNegativeIntHeader('content-length') ??
      response.bodyBytes.length;

  @override
  int get statusCode => response.statusCode;

  @override
  DateTime get validTill {
    var maxAge = const Duration(days: 7);
    final cacheControl = _header('cache-control');
    if (cacheControl != null) {
      for (final directive in cacheControl.split(',')) {
        final normalized = directive.trim().toLowerCase();
        if (normalized == 'no-cache' || normalized == 'no-store') {
          maxAge = Duration.zero;
          break;
        }
        if (normalized.startsWith('max-age=')) {
          final seconds = int.tryParse(normalized.substring('max-age='.length));
          if (seconds != null && seconds >= 0) {
            maxAge = Duration(seconds: seconds);
          }
        }
      }
    }
    return _receivedAt.add(maxAge);
  }

  @override
  String? get eTag => _header('etag');

  @override
  String get fileExtension {
    final contentType = _header('content-type');
    if (contentType == null || contentType.trim().isEmpty) return '';
    try {
      final parsed = ContentType.parse(contentType);
      return switch (parsed.mimeType) {
        'image/jpeg' => '.jpg',
        'image/svg+xml' => '.svg',
        _ => '.${parsed.subType}',
      };
    } catch (_) {
      return '';
    }
  }

  String? _header(String name) {
    final normalizedName = name.toLowerCase();
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == normalizedName) return entry.value;
    }
    return null;
  }

  int? _nonNegativeIntHeader(String name) {
    final value = int.tryParse(_header(name) ?? '');
    return value != null && value >= 0 ? value : null;
  }
}
