import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;

import '../app/telemetry/firebase_performance_monitoring.dart';
import 'dio_http_transport.dart';
import 'http_transport.dart';
import 'io_http_transport.dart';
import 'static_image_network_config.dart';

typedef HttpProtocolResolver = String? Function(http.StreamedResponse response);

class PlatformHttp3Transport implements HttpTransport {
  PlatformHttp3Transport({
    required http.Client client,
    HttpTransport? nonHttpsTransport,
    HttpProtocolResolver? protocolResolver,
    HttpRequestPerformanceMetricFactory? performanceMetricFactory,
    HttpRequestPerformanceMetricUrlFilter? performanceMetricUrlFilter,
    HttpRequestPerformanceMetricReady? performanceMetricReady,
  }) : _client = client,
       _nonHttpsTransport = nonHttpsTransport ?? DioHttpTransport(),
       _protocolResolver = protocolResolver ?? platformHttpProtocol,
       _performanceMetricFactory =
           performanceMetricFactory ?? createFirebasePerformanceMetric,
       _performanceMetricUrlFilter =
           performanceMetricUrlFilter ?? isFirebasePerformanceMetricUrl,
       _performanceMetricReady =
           performanceMetricReady ??
           (() => FirebasePerformanceMonitoring.isReady);

  final http.Client _client;
  final HttpTransport _nonHttpsTransport;
  final HttpProtocolResolver _protocolResolver;
  final HttpRequestPerformanceMetricFactory _performanceMetricFactory;
  final HttpRequestPerformanceMetricUrlFilter _performanceMetricUrlFilter;
  final HttpRequestPerformanceMetricReady _performanceMetricReady;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    if (request.uri.scheme.toLowerCase() != 'https') {
      return _nonHttpsTransport.send(request);
    }

    request.cancellationToken?.throwIfCancelled();
    final metric = await _startPerformanceMetric(request);
    final abortCompleter = Completer<void>();
    void abort() {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
    }

    final removeCancelListener = request.cancellationToken?.addCancelListener(
      abort,
    );
    try {
      final nativeRequest = http.AbortableRequest(
        request.method,
        request.uri,
        abortTrigger: abortCompleter.future,
      )..headers.addAll(request.headers);
      final requestBody = request.bodyBytes;
      if (requestBody != null) {
        nativeRequest.bodyBytes = requestBody;
        request.onSendProgress?.call(requestBody.length, requestBody.length);
      }

      final timeout = Duration(milliseconds: request.timeoutMs);
      final streamedResponse = await _client
          .send(nativeRequest)
          .timeout(
            timeout,
            onTimeout: () {
              abort();
              throw TimeoutException(
                'HTTP request timed out after ${request.timeoutMs} ms.',
              );
            },
          );
      request.cancellationToken?.throwIfCancelled();

      final protocol = normalizeHttpProtocolVersion(
        _protocolResolver(streamedResponse),
      );
      recordPerformanceMetricProtocol(metric, protocol);
      if (protocol == 'http/1.1') {
        abort();
        throw http.ClientException(
          'HTTPS requires HTTP/2 or HTTP/3, but negotiated HTTP/1.1.',
          request.uri,
        );
      }

      final bodyBytes = await _readResponseBytes(
        streamedResponse,
        timeout: timeout,
        onReceiveProgress: request.onReceiveProgress,
        cancellationToken: request.cancellationToken,
      );
      final response = TransportResponse(
        statusCode: streamedResponse.statusCode,
        headers: Map<String, String>.from(streamedResponse.headers),
        body: request.decodeResponseBody
            ? utf8.decode(bodyBytes, allowMalformed: true)
            : '',
        bodyBytes: bodyBytes,
        responsePayloadSizeBytes:
            responsePayloadSizeFromHeaders(streamedResponse.headers) ??
            nonNegativeContentLength(streamedResponse.contentLength) ??
            bodyBytes.length,
        httpProtocolVersion: protocol,
      );
      recordPerformanceMetricResponse(metric, response);
      return response;
    } on http.RequestAbortedException {
      throw const NetworkRequestCancelledException();
    } on TimeoutException {
      abort();
      rethrow;
    } finally {
      removeCancelListener?.call();
      await stopPerformanceMetric(metric);
    }
  }

  Future<HttpRequestPerformanceMetric?> _startPerformanceMetric(
    TransportRequest request,
  ) async {
    HttpRequestPerformanceMetric? metric;
    try {
      final method = firebaseHttpMethodFor(request.method);
      if (method == null) return null;
      if (!_performanceMetricReady()) return null;
      if (!_performanceMetricUrlFilter(request.uri)) return null;
      metric = _performanceMetricFactory(
        firebaseMetricUrl(request.uri),
        method,
      );
      if (metric == null) return null;
      metric.requestPayloadSize = request.bodyBytes?.length ?? 0;
      await metric.start();
      return metric;
    } catch (_) {
      await stopPerformanceMetric(metric);
      return null;
    }
  }
}

Future<Uint8List> _readResponseBytes(
  http.StreamedResponse response, {
  required Duration timeout,
  required NetworkProgressCallback? onReceiveProgress,
  required NetworkCancellationToken? cancellationToken,
}) async {
  final output = BytesBuilder(copy: false);
  final totalBytes = nonNegativeContentLength(response.contentLength) ?? -1;
  await for (final chunk in response.stream.timeout(timeout)) {
    cancellationToken?.throwIfCancelled();
    output.add(chunk);
    onReceiveProgress?.call(output.length, totalBytes);
  }
  cancellationToken?.throwIfCancelled();
  return output.takeBytes();
}

http.Client createPlatformHttp3Client() {
  if (Platform.isAndroid) {
    final engine = CronetEngine.build(
      cacheMode: CacheMode.disabled,
      enableHttp2: true,
      enableQuic: true,
      quicHints: <(String, int, int)>[
        for (final host in genesisHttp3CapableHosts) (host, 443, 443),
      ],
    );
    return CronetClient.fromCronetEngine(engine, closeEngine: true);
  }
  if (Platform.isIOS) {
    final configuration =
        URLSessionConfiguration.ephemeralSessionConfiguration()
          ..cache = URLCache.withCapacity();
    return CupertinoClient.fromSessionConfiguration(configuration);
  }
  throw UnsupportedError(
    'HTTP/3 native transport is supported only on Android and iOS.',
  );
}

String? platformHttpProtocol(http.StreamedResponse response) {
  if (response is CronetStreamedResponse) {
    return response.negotiatedProtocol;
  }
  return null;
}
