import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'http_transport.dart';
import 'io_http_transport.dart';

class DioHttpTransport implements HttpTransport {
  DioHttpTransport({
    Dio? dio,
    String? proxy,
    HttpRequestPerformanceMetricFactory? performanceMetricFactory,
    HttpRequestPerformanceMetricUrlFilter? performanceMetricUrlFilter,
  }) : _dio = dio ?? _createDio(proxy),
       _performanceMetricFactory =
           performanceMetricFactory ?? createFirebasePerformanceMetric,
       _performanceMetricUrlFilter =
           performanceMetricUrlFilter ?? isBusinessPerformanceMetricUrl;

  final Dio _dio;
  final HttpRequestPerformanceMetricFactory _performanceMetricFactory;
  final HttpRequestPerformanceMetricUrlFilter _performanceMetricUrlFilter;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final metric = await _startPerformanceMetric(request);
    try {
      final timeout = Duration(milliseconds: request.timeoutMs);
      final response = await _dio.request<Object?>(
        request.uri.toString(),
        data: request.bodyBytes,
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
      final bodyBytes = _responseBodyBytes(response.data);
      final transportResponse = TransportResponse(
        statusCode: response.statusCode ?? 0,
        headers: headers,
        body: utf8.decode(bodyBytes),
        responsePayloadSizeBytes:
            responsePayloadSizeFromHeaders(headers) ?? bodyBytes.length,
      );
      recordPerformanceMetricResponse(metric, transportResponse);
      return transportResponse;
    } finally {
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

Dio _createDio(String? proxy) {
  final dio = Dio();
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => createProxyAwareHttpClient(proxy),
  );
  return dio;
}

List<int> _responseBodyBytes(Object? data) {
  if (data == null) return const <int>[];
  if (data is List<int>) return data;
  if (data is String) return utf8.encode(data);
  if (data is Iterable<int>) return data.toList(growable: false);
  return utf8.encode(data.toString());
}
