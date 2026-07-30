import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'dio_http_transport.dart';
import 'http_transport.dart';
import 'static_image_network_config.dart';

const int genesisImageHttp2ConnectionCount = 3;
const int genesisImageConcurrentFetchesPerConnection = 3;
const Duration genesisImageHttp2IdleTimeout = Duration(minutes: 5);

class GenesisHttp2CacheManager extends CacheManager with ImageCacheManager {
  GenesisHttp2CacheManager._(this._transportPool)
    : super(
        Config(
          DefaultCacheManager.key,
          fileService: GenesisHttp2FileService(transport: _transportPool),
        ),
      );

  static final GenesisHttp2CacheManager instance = GenesisHttp2CacheManager._(
    GenesisImageHttp2TransportPool(),
  );

  final GenesisImageHttp2TransportPool _transportPool;

  factory GenesisHttp2CacheManager() => instance;

  Future<void> warmUpConnections() {
    return _transportPool.warmUp(genesisStaticImageCdnWarmUpUri);
  }
}

class GenesisHttp2FileService extends FileService {
  GenesisHttp2FileService({HttpTransport? transport, this.timeoutMs = 120000})
    : _transport = transport ?? GenesisImageHttp2TransportPool() {
    concurrentFetches =
        genesisImageHttp2ConnectionCount *
        genesisImageConcurrentFetchesPerConnection;
  }

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

class GenesisImageHttp2TransportPool implements HttpTransport {
  GenesisImageHttp2TransportPool({List<HttpTransport>? transports})
    : _transports = List<HttpTransport>.unmodifiable(
        transports ??
            List<HttpTransport>.generate(
              genesisImageHttp2ConnectionCount,
              (_) => DioHttpTransport(
                http2IdleTimeout: genesisImageHttp2IdleTimeout,
              ),
              growable: false,
            ),
      ) {
    if (_transports.isEmpty) {
      throw ArgumentError.value(
        transports,
        'transports',
        'Must contain at least one transport.',
      );
    }
  }

  final List<HttpTransport> _transports;
  final Map<String, Future<void>> _warmUpRequests = <String, Future<void>>{};
  int _nextTransportIndex = 0;

  Future<void> warmUp(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https' || uri.host.trim().isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Must be an HTTPS origin.');
    }
    final originKey =
        '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}'
        ':${uri.port}';
    final existing = _warmUpRequests[originKey];
    if (existing != null) return existing;

    final request = _warmUpOrigin(originKey: originKey, uri: uri);
    _warmUpRequests[originKey] = request;
    return request;
  }

  Future<void> _warmUpOrigin({
    required String originKey,
    required Uri uri,
  }) async {
    try {
      await Future.wait<void>([
        for (final transport in _transports)
          transport
              .send(
                TransportRequest(
                  method: 'HEAD',
                  uri: uri,
                  headers: const <String, String>{'accept': '*/*'},
                  bodyBytes: null,
                  timeoutMs: 10000,
                ),
              )
              .then((_) {}),
      ]);
    } catch (_) {
      _warmUpRequests.remove(originKey);
      rethrow;
    }
  }

  @override
  Future<TransportResponse> send(TransportRequest request) {
    final transport = _transports[_nextTransportIndex];
    _nextTransportIndex = (_nextTransportIndex + 1) % _transports.length;
    return transport.send(request);
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
