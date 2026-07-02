import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_performance/firebase_performance.dart';

import 'http_transport.dart';

typedef HttpRequestPerformanceMetricFactory =
    HttpRequestPerformanceMetric? Function(String url, HttpMethod method);
typedef HttpRequestPerformanceMetricUrlFilter = bool Function(Uri uri);

abstract class HttpRequestPerformanceMetric {
  set httpResponseCode(int? value);
  set requestPayloadSize(int? value);
  set responseContentType(String? value);
  set responsePayloadSize(int? value);

  Future<void> start();
  Future<void> stop();
}

class IoHttpTransport implements HttpTransport {
  IoHttpTransport({
    HttpClient? client,
    String? proxy,
    HttpRequestPerformanceMetricFactory? performanceMetricFactory,
    HttpRequestPerformanceMetricUrlFilter? performanceMetricUrlFilter,
  }) : _client = client ?? createProxyAwareHttpClient(proxy),
       _performanceMetricFactory =
           performanceMetricFactory ?? createFirebasePerformanceMetric,
       _performanceMetricUrlFilter =
           performanceMetricUrlFilter ?? isBusinessPerformanceMetricUrl;

  final HttpClient _client;
  final HttpRequestPerformanceMetricFactory _performanceMetricFactory;
  final HttpRequestPerformanceMetricUrlFilter _performanceMetricUrlFilter;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final metric = await _startPerformanceMetric(request);
    try {
      final httpRequest = await _client
          .openUrl(request.method, request.uri)
          .timeout(Duration(milliseconds: request.timeoutMs));

      request.headers.forEach((key, value) {
        httpRequest.headers.set(key, value);
      });

      if (request.bodyBytes != null) {
        httpRequest.add(request.bodyBytes!);
      }

      final httpResponse = await httpRequest.close().timeout(
        Duration(milliseconds: request.timeoutMs),
      );

      final headers = <String, String>{};
      httpResponse.headers.forEach((name, values) {
        headers[name] = values.join(',');
      });

      final body = await utf8
          .decodeStream(httpResponse)
          .timeout(Duration(milliseconds: request.timeoutMs));

      final response = TransportResponse(
        statusCode: httpResponse.statusCode,
        headers: headers,
        body: body,
        responsePayloadSizeBytes:
            responsePayloadSizeFromHeaders(headers) ??
            nonNegativeContentLength(httpResponse.contentLength),
      );
      recordPerformanceMetricResponse(metric, response);
      return response;
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

class _FirebaseHttpRequestPerformanceMetric
    implements HttpRequestPerformanceMetric {
  _FirebaseHttpRequestPerformanceMetric(this._metric);

  final HttpMetric _metric;

  @override
  set httpResponseCode(int? value) {
    _metric.httpResponseCode = value;
  }

  @override
  set requestPayloadSize(int? value) {
    _metric.requestPayloadSize = value;
  }

  @override
  set responseContentType(String? value) {
    _metric.responseContentType = value;
  }

  @override
  set responsePayloadSize(int? value) {
    _metric.responsePayloadSize = value;
  }

  @override
  Future<void> start() {
    return _metric.start();
  }

  @override
  Future<void> stop() {
    return _metric.stop();
  }
}

HttpRequestPerformanceMetric createFirebasePerformanceMetric(
  String url,
  HttpMethod method,
) {
  return _FirebaseHttpRequestPerformanceMetric(
    FirebasePerformance.instance.newHttpMetric(url, method),
  );
}

HttpClient createProxyAwareHttpClient(String? proxy) {
  final client = HttpClient();
  final proxyAddress = _normalizeProxyAddress(proxy);
  if (proxyAddress != null) {
    client.findProxy = (_) => 'PROXY $proxyAddress; DIRECT';
    if (!const bool.fromEnvironment('dart.vm.product')) {
      client.badCertificateCallback = (_, __, ___) => true;
    }
  }
  return client;
}

String? _normalizeProxyAddress(String? proxy) {
  final raw = proxy?.trim();
  if (raw == null || raw.isEmpty) return null;
  final parsed = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
  if (parsed == null || parsed.host.trim().isEmpty || !parsed.hasPort) {
    return raw;
  }
  return '${parsed.host}:${parsed.port}';
}

HttpMethod? firebaseHttpMethodFor(String method) {
  switch (method.trim().toUpperCase()) {
    case 'CONNECT':
      return HttpMethod.Connect;
    case 'DELETE':
      return HttpMethod.Delete;
    case 'GET':
      return HttpMethod.Get;
    case 'HEAD':
      return HttpMethod.Head;
    case 'OPTIONS':
      return HttpMethod.Options;
    case 'PATCH':
      return HttpMethod.Patch;
    case 'POST':
      return HttpMethod.Post;
    case 'PUT':
      return HttpMethod.Put;
    case 'TRACE':
      return HttpMethod.Trace;
  }
  return null;
}

String firebaseMetricUrl(Uri uri) {
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : 0,
    path: uri.path.isEmpty ? '/' : uri.path,
  ).toString();
}

bool isBusinessPerformanceMetricUrl(Uri uri) {
  switch (uri.host.toLowerCase()) {
    case 'api.worldo.ai':
    case 'dev.hushie.ai':
      return true;
  }
  return false;
}

void recordPerformanceMetricResponse(
  HttpRequestPerformanceMetric? metric,
  TransportResponse response,
) {
  if (metric == null) return;
  try {
    metric.httpResponseCode = response.statusCode;
    metric.responseContentType = headerValue(response.headers, 'content-type');
    metric.responsePayloadSize =
        response.responsePayloadSizeBytes ?? utf8.encode(response.body).length;
  } catch (_) {}
}

Future<void> stopPerformanceMetric(HttpRequestPerformanceMetric? metric) async {
  if (metric == null) return;
  try {
    await metric.stop();
  } catch (_) {}
}

String? headerValue(Map<String, String> headers, String name) {
  final normalizedName = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == normalizedName) {
      return entry.value;
    }
  }
  return null;
}

int? responsePayloadSizeFromHeaders(Map<String, String> headers) {
  final raw = headerValue(headers, 'content-length')?.trim();
  if (raw == null || raw.isEmpty) return null;
  final value = int.tryParse(raw);
  return nonNegativeContentLength(value);
}

int? nonNegativeContentLength(int? value) {
  if (value == null || value < 0) return null;
  return value;
}
