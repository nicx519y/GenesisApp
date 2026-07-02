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
    request.cancellationToken?.throwIfCancelled();
    final metric = await _startPerformanceMetric(request);
    HttpClientRequest? httpRequest;
    void Function()? removeCancelListener;
    try {
      httpRequest = await _client
          .openUrl(request.method, request.uri)
          .timeout(Duration(milliseconds: request.timeoutMs));
      removeCancelListener = request.cancellationToken?.addCancelListener(() {
        httpRequest?.abort(const NetworkRequestCancelledException());
      });
      request.cancellationToken?.throwIfCancelled();
      final openedRequest = httpRequest;

      request.headers.forEach((key, value) {
        openedRequest.headers.set(key, value);
      });

      if (request.bodyBytes != null) {
        openedRequest.add(request.bodyBytes!);
        request.onSendProgress?.call(
          request.bodyBytes!.length,
          request.bodyBytes!.length,
        );
      }

      final httpResponse = await openedRequest.close().timeout(
        Duration(milliseconds: request.timeoutMs),
      );
      request.cancellationToken?.throwIfCancelled();

      final headers = <String, String>{};
      httpResponse.headers.forEach((name, values) {
        headers[name] = values.join(',');
      });

      final bodyBytes = await _readResponseBytes(
        httpResponse,
        timeout: Duration(milliseconds: request.timeoutMs),
        onReceiveProgress: request.onReceiveProgress,
        cancellationToken: request.cancellationToken,
      );
      final body = utf8.decode(bodyBytes, allowMalformed: true);

      final response = TransportResponse(
        statusCode: httpResponse.statusCode,
        headers: headers,
        body: body,
        bodyBytes: bodyBytes,
        responsePayloadSizeBytes:
            responsePayloadSizeFromHeaders(headers) ??
            nonNegativeContentLength(httpResponse.contentLength) ??
            bodyBytes.length,
      );
      recordPerformanceMetricResponse(metric, response);
      return response;
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

Future<List<int>> _readResponseBytes(
  HttpClientResponse response, {
  required Duration timeout,
  required NetworkProgressCallback? onReceiveProgress,
  required NetworkCancellationToken? cancellationToken,
}) async {
  final out = <int>[];
  final totalBytes = nonNegativeContentLength(response.contentLength) ?? -1;
  await for (final chunk in response.timeout(timeout)) {
    cancellationToken?.throwIfCancelled();
    out.addAll(chunk);
    onReceiveProgress?.call(out.length, totalBytes);
  }
  cancellationToken?.throwIfCancelled();
  return out;
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
  final path = uri.path.isEmpty ? '/' : uri.path;
  if (uri.hasPort) {
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: path,
    ).toString();
  }
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    path: path,
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
        response.responsePayloadSizeBytes ??
        (response.bodyBytes.isEmpty
            ? utf8.encode(response.body).length
            : response.bodyBytes.length);
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
