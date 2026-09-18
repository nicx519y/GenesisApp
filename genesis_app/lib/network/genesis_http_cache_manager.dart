import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'genesis_http_transport_pool.dart';
import 'http_transport.dart';
import 'network_capture.dart';
import 'static_image_network_config.dart';

class GenesisHttpCacheManager extends CacheManager with ImageCacheManager {
  GenesisHttpCacheManager._(
    this._transport, {
    String cacheKey = DefaultCacheManager.key,
    Config? config,
  }) : super(
         config ??
             Config(
               cacheKey,
               fileService: GenesisHttpFileService(transport: _transport),
             ),
       );

  static GenesisHttpCacheManager? _instance;
  static HttpTransport? _configuredTransport;

  final HttpTransport _transport;
  final Map<String, _SharedCancellableFileDownload> _cancellableDownloads =
      <String, _SharedCancellableFileDownload>{};

  factory GenesisHttpCacheManager() {
    return _instance ??= GenesisHttpCacheManager._(
      _configuredTransport ?? GenesisHttpTransportRegistry.current,
    );
  }

  @visibleForTesting
  factory GenesisHttpCacheManager.debug({
    required HttpTransport transport,
    required Config config,
  }) {
    return GenesisHttpCacheManager._(transport, config: config);
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

  Future<File> getSingleFileCancellable(
    String url, {
    required NetworkCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final cached = await getFileFromCache(url);
    cancellationToken.throwIfCancelled();
    if (cached != null && cached.validTill.isAfter(DateTime.now())) {
      return cached.file;
    }

    var shared = _cancellableDownloads[url];
    if (shared == null) {
      shared = _SharedCancellableFileDownload();
      _cancellableDownloads[url] = shared;
      final download = shared;
      unawaited(
        _downloadAndCache(url, cancellationToken: download.networkToken)
            .then<void>(download.complete, onError: download.completeError)
            .whenComplete(() {
              if (identical(_cancellableDownloads[url], download)) {
                _cancellableDownloads.remove(url);
              }
            }),
      );
    }
    return shared.subscribe(cancellationToken);
  }

  Future<File> _downloadAndCache(
    String url, {
    required NetworkCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final cacheObject = await store.retrieveCacheData(url);
    cancellationToken.throwIfCancelled();
    final response = await _transport.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: <String, String>{
          if (cacheObject?.eTag case final eTag?) 'if-none-match': eTag,
        },
        bodyBytes: null,
        timeoutMs: 120000,
        decodeResponseBody: false,
        cancellationToken: cancellationToken,
      ),
    );
    // A completed TransportResponse owns the full response body. From this
    // point on, finish the cache write even if the final consumer just left.
    final fileResponse = GenesisHttpFileServiceResponse(response);

    if (response.statusCode == HttpStatus.notModified) {
      if (cacheObject == null) {
        throw HttpExceptionWithStatus(
          response.statusCode,
          'Received 304 without a cached image.',
          uri: Uri.parse(url),
        );
      }
      await store.putFile(
        cacheObject.copyWith(
          validTill: fileResponse.validTill,
          eTag: fileResponse.eTag ?? cacheObject.eTag,
        ),
      );
      final cached = await getFileFromCache(url);
      if (cached == null) {
        throw StateError('Cached image disappeared after revalidation: $url');
      }
      return cached.file;
    }

    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.accepted) {
      throw HttpExceptionWithStatus(
        response.statusCode,
        'Invalid statusCode: ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }

    final maxAge = fileResponse.validTill.difference(DateTime.now());
    final extension = fileResponse.fileExtension.replaceFirst(
      RegExp(r'^\.'),
      '',
    );
    return putFile(
      url,
      Uint8List.fromList(response.bodyBytes),
      eTag: fileResponse.eTag,
      maxAge: maxAge.isNegative ? Duration.zero : maxAge,
      fileExtension: extension.isEmpty ? 'file' : extension,
    );
  }
}

class _SharedCancellableFileDownload {
  final NetworkCancellationToken networkToken = NetworkCancellationToken();
  final Set<_CancellableFileSubscriber> _subscribers =
      <_CancellableFileSubscriber>{};
  File? _file;
  Object? _error;
  StackTrace? _stackTrace;
  var _isComplete = false;

  Future<File> subscribe(NetworkCancellationToken cancellationToken) {
    cancellationToken.throwIfCancelled();
    if (_isComplete) {
      final error = _error;
      if (error != null) {
        return Future<File>.error(error, _stackTrace);
      }
      return Future<File>.value(_file!);
    }

    final subscriber = _CancellableFileSubscriber();
    _subscribers.add(subscriber);
    subscriber.removeCancellationListener = cancellationToken.addCancelListener(
      () {
        if (!subscriber.completer.isCompleted) {
          subscriber.completer.completeError(
            const NetworkRequestCancelledException(),
          );
        }
        _removeSubscriber(subscriber);
      },
    );
    return subscriber.completer.future.whenComplete(
      () => _removeSubscriber(subscriber),
    );
  }

  void complete(File file) {
    if (_isComplete) return;
    _isComplete = true;
    _file = file;
    for (final subscriber in List<_CancellableFileSubscriber>.of(
      _subscribers,
    )) {
      if (!subscriber.completer.isCompleted) {
        subscriber.completer.complete(file);
      }
    }
    _clearSubscribers();
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (_isComplete) return;
    _isComplete = true;
    _error = error;
    _stackTrace = stackTrace;
    for (final subscriber in List<_CancellableFileSubscriber>.of(
      _subscribers,
    )) {
      if (!subscriber.completer.isCompleted) {
        subscriber.completer.completeError(error, stackTrace);
      }
    }
    _clearSubscribers();
  }

  void _removeSubscriber(_CancellableFileSubscriber subscriber) {
    if (!_subscribers.remove(subscriber)) return;
    subscriber.removeCancellationListener?.call();
    subscriber.removeCancellationListener = null;
    if (_subscribers.isEmpty && !_isComplete) networkToken.cancel();
  }

  void _clearSubscribers() {
    for (final subscriber in _subscribers) {
      subscriber.removeCancellationListener?.call();
      subscriber.removeCancellationListener = null;
    }
    _subscribers.clear();
  }
}

class _CancellableFileSubscriber {
  final Completer<File> completer = Completer<File>();
  VoidCallback? removeCancellationListener;
}

class GenesisHttpFileService extends FileService {
  GenesisHttpFileService({
    HttpTransport? transport,
    this.timeoutMs = 120000,
    bool isDebugBuild = kDebugMode,
    NetworkCaptureController? captureController,
  }) : _transport = debugNetworkCaptureTransport(
         delegate: transport ?? GenesisHttpTransportRegistry.current,
         isDebugBuild: isDebugBuild,
         controller: captureController,
       ) {
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
        decodeResponseBody: false,
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
