import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

import '../app/telemetry/firebase_performance_monitoring.dart';
import 'devtools_http_profile.dart';
import 'http_transport.dart';
import 'io_http_transport.dart';

class DioHttpTransport implements HttpTransport {
  DioHttpTransport({
    Dio? dio,
    String? proxy,
    Duration http2IdleTimeout = const Duration(seconds: 15),
    HttpRequestPerformanceMetricFactory? performanceMetricFactory,
    HttpRequestPerformanceMetricUrlFilter? performanceMetricUrlFilter,
    HttpRequestPerformanceMetricReady? performanceMetricReady,
  }) : _dio = dio ?? _createDio(proxy, http2IdleTimeout),
       _performanceMetricFactory =
           performanceMetricFactory ?? createFirebasePerformanceMetric,
       _performanceMetricUrlFilter =
           performanceMetricUrlFilter ?? isFirebasePerformanceMetricUrl,
       _performanceMetricReady =
           performanceMetricReady ??
           (() => FirebasePerformanceMonitoring.isReady);

  final Dio _dio;
  final HttpRequestPerformanceMetricFactory _performanceMetricFactory;
  final HttpRequestPerformanceMetricUrlFilter _performanceMetricUrlFilter;
  final HttpRequestPerformanceMetricReady _performanceMetricReady;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    request.cancellationToken?.throwIfCancelled();
    final metric = await _startPerformanceMetric(request);
    final devToolsProfile = DevToolsHttpProfile.start(request);
    await devToolsProfile?.completeRequest(request);
    final dioCancelToken = CancelToken();
    final removeCancelListener = request.cancellationToken?.addCancelListener(
      () {
        if (!dioCancelToken.isCancelled) {
          dioCancelToken.cancel(const NetworkRequestCancelledException());
        }
      },
    );
    try {
      final timeout = Duration(milliseconds: request.timeoutMs);
      final response = await _dio.request<Object?>(
        request.uri.toString(),
        data: _requestBodyData(request.bodyBytes),
        cancelToken: dioCancelToken,
        onSendProgress: request.onSendProgress,
        onReceiveProgress: request.onReceiveProgress,
        options: Options(
          method: request.method,
          headers: request.headers,
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
          connectTimeout: timeout,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );

      final headers = <String, String>{
        for (final entry in response.headers.map.entries)
          entry.key: entry.value.join(','),
      };
      final httpProtocolVersion = response
          .extra[HttpClientAdapter.extraKeyHttpVersion]
          ?.toString();
      if (request.uri.scheme.toLowerCase() == 'https' &&
          httpProtocolVersion != '2.0') {
        throw DioException.connectionError(
          requestOptions: response.requestOptions,
          reason:
              'HTTPS requires HTTP/2, but the negotiated protocol was '
              '${httpProtocolVersion ?? 'unknown'}.',
        );
      }
      final bodyBytes = _responseBodyBytes(response.data);
      final normalizedProtocol = normalizeHttpProtocolVersion(
        httpProtocolVersion,
      );
      final transportResponse = TransportResponse(
        statusCode: response.statusCode ?? 0,
        headers: headers,
        body: request.decodeResponseBody
            ? utf8.decode(bodyBytes, allowMalformed: true)
            : '',
        bodyBytes: bodyBytes,
        responsePayloadSizeBytes:
            responsePayloadSizeFromHeaders(headers) ?? bodyBytes.length,
        httpProtocolVersion: normalizedProtocol,
      );
      recordPerformanceMetricProtocol(metric, normalizedProtocol);
      recordPerformanceMetricResponse(metric, transportResponse);
      await devToolsProfile?.completeResponse(transportResponse);
      return transportResponse;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        const cancellationError = NetworkRequestCancelledException();
        await devToolsProfile?.completeWithError(cancellationError);
        throw cancellationError;
      }
      await devToolsProfile?.completeWithError(error);
      rethrow;
    } catch (error) {
      await devToolsProfile?.completeWithError(error);
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

Object? _requestBodyData(List<int>? bodyBytes) {
  if (bodyBytes == null) return null;
  if (bodyBytes is Uint8List) return bodyBytes;
  return Uint8List.fromList(bodyBytes);
}

Dio _createDio(String? proxy, Duration http2IdleTimeout) {
  final normalizedProxy = normalizeHttpProxyAddress(proxy);
  final dio = Dio();
  final httpAdapter = IOHttpClientAdapter(
    createHttpClient: () => createProxyAwareHttpClient(normalizedProxy),
  );
  final proxyUri = _proxyUri(normalizedProxy);
  final httpsAdapter = Http2Adapter(
    ConnectionManager(
      idleTimeout: http2IdleTimeout,
      onClientCreate: (_, setting) {
        setting.proxy = proxyUri;
        if (proxyUri != null &&
            !const bool.fromEnvironment('dart.vm.product')) {
          setting.onBadCertificate = (_) => true;
        }
      },
    ),
    fallbackAdapter: httpAdapter,
    onNotSupported: (options, requestStream, cancelFuture, error) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'HTTPS endpoint does not support the required HTTP/2 protocol.',
        error: error,
      );
    },
  );
  dio.httpClientAdapter = SchemeRoutingHttpClientAdapter(
    httpsAdapter: httpsAdapter,
    otherAdapter: httpAdapter,
  );
  return dio;
}

class SchemeRoutingHttpClientAdapter implements HttpClientAdapter {
  SchemeRoutingHttpClientAdapter({
    required HttpClientAdapter httpsAdapter,
    required HttpClientAdapter otherAdapter,
  }) : _httpsAdapter = httpsAdapter,
       _otherAdapter = otherAdapter;

  final HttpClientAdapter _httpsAdapter;
  final HttpClientAdapter _otherAdapter;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final adapter = options.uri.scheme.toLowerCase() == 'https'
        ? _httpsAdapter
        : _otherAdapter;
    return adapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _httpsAdapter.close(force: force);
    _otherAdapter.close(force: force);
  }
}

Uri? _proxyUri(String? proxy) {
  if (proxy == null) return null;
  return Uri.parse('http://$proxy');
}

Uint8List _responseBodyBytes(Object? data) {
  if (data == null) return Uint8List(0);
  if (data is Uint8List) return data;
  if (data is List<int>) return Uint8List.fromList(data);
  if (data is String) return Uint8List.fromList(utf8.encode(data));
  if (data is Iterable<int>) return Uint8List.fromList(data.toList());
  return Uint8List.fromList(utf8.encode(data.toString()));
}
