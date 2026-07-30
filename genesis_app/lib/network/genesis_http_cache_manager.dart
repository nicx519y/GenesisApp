import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'genesis_http_transport_pool.dart';
import 'http_transport.dart';
import 'static_image_network_config.dart';

class GenesisHttpCacheManager extends CacheManager with ImageCacheManager {
  GenesisHttpCacheManager._(this._transport)
    : super(
        Config(
          DefaultCacheManager.key,
          fileService: GenesisHttpFileService(transport: _transport),
        ),
      );

  static GenesisHttpCacheManager? _instance;
  static HttpTransport? _configuredTransport;

  final HttpTransport _transport;

  factory GenesisHttpCacheManager() {
    return _instance ??= GenesisHttpCacheManager._(
      _configuredTransport ?? GenesisHttpTransportRegistry.current,
    );
  }

  static void configureTransport(HttpTransport transport) {
    if (_instance != null) {
      debugPrint(
        '[Network][Image] cache manager was initialized before transport '
        'configuration; keeping its existing transport.',
      );
      return;
    }
    _configuredTransport = transport;
  }

  Future<void> warmUpConnections() {
    final transport = _transport;
    if (transport is GenesisHttpTransportPool) {
      return transport.warmUp(genesisStaticImageCdnWarmUpUri);
    }
    return transport
        .send(
          TransportRequest(
            method: 'HEAD',
            uri: genesisStaticImageCdnWarmUpUri,
            headers: const <String, String>{'accept': '*/*'},
            bodyBytes: null,
            timeoutMs: 10000,
          ),
        )
        .then((_) {});
  }
}

class GenesisHttpFileService extends FileService {
  GenesisHttpFileService({HttpTransport? transport, this.timeoutMs = 120000})
    : _transport = transport ?? GenesisHttpTransportRegistry.current {
    concurrentFetches = genesisHttpImageConcurrentFetches;
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
    return GenesisHttpFileServiceResponse(response);
  }
}

class GenesisHttpFileServiceResponse implements FileServiceResponse {
  GenesisHttpFileServiceResponse(this.response) : _receivedAt = DateTime.now();

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
