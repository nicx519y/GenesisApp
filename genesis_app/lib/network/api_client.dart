import 'dart:convert';

import '../app/telemetry/genesis_telemetry.dart';
import 'api_exception.dart';
import 'http_transport.dart';
import 'io_http_transport.dart';

class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.data,
    required this.uri,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final Object? data;
  final Uri uri;
}

typedef ApiResponseProcessor = Object? Function(ApiResponse response);
typedef RequestHeaderProvider = Future<Map<String, String>> Function();
typedef ApiRequestSender =
    Future<TransportResponse> Function(TransportRequest request);
typedef ApiRequestInterceptor =
    Future<TransportResponse> Function(
      TransportRequest request,
      ApiRequestSender send,
    );

class ApiClient {
  ApiClient({
    required String baseUrl,
    Map<String, String>? defaultHeaders,
    ApiResponseProcessor? responseProcessor,
    RequestHeaderProvider? requestHeaderProvider,
    ApiRequestInterceptor? requestInterceptor,
    HttpTransport? transport,
    int timeoutMs = 15000,
  }) : _baseUri = Uri.parse(baseUrl),
       _defaultHeaders = Map<String, String>.from(defaultHeaders ?? const {}),
       _responseProcessor = responseProcessor ?? defaultResponseProcessor,
       _requestHeaderProvider = requestHeaderProvider,
       _requestInterceptor = requestInterceptor,
       _transport = transport ?? IoHttpTransport(),
       _timeoutMs = timeoutMs;

  final Uri _baseUri;
  final Map<String, String> _defaultHeaders;
  final ApiResponseProcessor _responseProcessor;
  final RequestHeaderProvider? _requestHeaderProvider;
  final ApiRequestInterceptor? _requestInterceptor;
  final HttpTransport _transport;
  final int _timeoutMs;

  ApiClient copyWith({
    String? baseUrl,
    Map<String, String>? defaultHeaders,
    ApiResponseProcessor? responseProcessor,
    RequestHeaderProvider? requestHeaderProvider,
    ApiRequestInterceptor? requestInterceptor,
    HttpTransport? transport,
    int? timeoutMs,
  }) {
    return ApiClient(
      baseUrl: baseUrl ?? _baseUri.toString(),
      defaultHeaders: defaultHeaders ?? _defaultHeaders,
      responseProcessor: responseProcessor ?? _responseProcessor,
      requestHeaderProvider: requestHeaderProvider ?? _requestHeaderProvider,
      requestInterceptor: requestInterceptor ?? _requestInterceptor,
      transport: transport ?? _transport,
      timeoutMs: timeoutMs ?? _timeoutMs,
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, Object?>? query,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
  }) {
    return request<T>(
      'GET',
      path,
      query: query,
      headers: headers,
      responseProcessor: responseProcessor,
    );
  }

  Future<T> post<T>(
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
  }) {
    return request<T>(
      'POST',
      path,
      query: query,
      body: body,
      headers: headers,
      responseProcessor: responseProcessor,
    );
  }

  Future<T> put<T>(
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
  }) {
    return request<T>(
      'PUT',
      path,
      query: query,
      body: body,
      headers: headers,
      responseProcessor: responseProcessor,
    );
  }

  Future<T> delete<T>(
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
  }) {
    return request<T>(
      'DELETE',
      path,
      query: query,
      body: body,
      headers: headers,
      responseProcessor: responseProcessor,
    );
  }

  Future<T> request<T>(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
  }) async {
    final stopwatch = Stopwatch()..start();
    final uri = _resolveUri(path, query);
    final runtimeHeaders = await _resolveRequestHeaders();
    final mergedHeaders = <String, String>{
      ..._defaultHeaders,
      ...runtimeHeaders,
      ...?headers,
    };

    final prepared = _prepareBody(body, mergedHeaders);

    final request = TransportRequest(
      method: method,
      uri: uri,
      headers: mergedHeaders,
      bodyBytes: prepared.bodyBytes,
      timeoutMs: _timeoutMs,
    );

    TransportResponse transportResponse;
    try {
      final interceptor = _requestInterceptor;
      transportResponse = interceptor == null
          ? await _send(request)
          : await interceptor(request, _send);
    } on ApiException {
      stopwatch.stop();
      _recordHttpTelemetry(
        request: request,
        duration: stopwatch.elapsed,
        outcome: 'api_exception',
      );
      rethrow;
    } catch (e) {
      stopwatch.stop();
      _recordHttpTelemetry(
        request: request,
        duration: stopwatch.elapsed,
        outcome: 'transport_exception',
        errorType: e.runtimeType.toString(),
      );
      throw ApiException(message: 'Request failed', error: e, uri: uri);
    }

    final decoded = _tryDecodeJson(transportResponse.body);
    final apiResponse = ApiResponse(
      statusCode: transportResponse.statusCode,
      headers: transportResponse.headers,
      body: transportResponse.body,
      data: decoded,
      uri: uri,
    );

    final processor = responseProcessor ?? _responseProcessor;
    try {
      final processed = processor(apiResponse);
      stopwatch.stop();
      _recordHttpTelemetry(
        request: request,
        response: apiResponse,
        duration: stopwatch.elapsed,
        outcome: 'success',
      );
      return processed as T;
    } on Object catch (error) {
      stopwatch.stop();
      _recordHttpTelemetry(
        request: request,
        response: apiResponse,
        duration: stopwatch.elapsed,
        outcome: 'response_exception',
        errorType: error.runtimeType.toString(),
      );
      rethrow;
    }
  }

  static Object? defaultResponseProcessor(ApiResponse response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok) return response.data;
    throw ApiException(
      message: 'Something went wrong',
      statusCode: response.statusCode,
      responseBody: response.body,
      responseHeaders: response.headers,
      uri: response.uri,
    );
  }

  Future<Map<String, String>> _resolveRequestHeaders() async {
    final provider = _requestHeaderProvider;
    if (provider == null) return const <String, String>{};
    final headers = await provider();
    return {
      for (final entry in headers.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key: entry.value,
    };
  }

  Future<TransportResponse> _send(TransportRequest request) {
    return _transport.send(request);
  }

  Uri _resolveUri(String path, Map<String, Object?>? query) {
    final resolved = _baseUri.resolve(path);
    if (query == null || query.isEmpty) return resolved;

    final qp = <String, String>{
      ...resolved.queryParameters,
      for (final e in query.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return resolved.replace(queryParameters: qp);
  }
}

void _recordHttpTelemetry({
  required TransportRequest request,
  required Duration duration,
  required String outcome,
  ApiResponse? response,
  String? errorType,
}) {
  GenesisTelemetry.event(
    'http_request',
    category: 'network.http',
    data: <String, Object?>{
      'method': request.method.toUpperCase(),
      'host': request.uri.host,
      'path': request.uri.path,
      'status_code': response?.statusCode,
      'duration_ms': duration.inMilliseconds,
      'timeout_ms': request.timeoutMs,
      'outcome': outcome,
      'request_family': _requestFamily(request.uri),
      'api_err_no': _apiErrNo(response?.data),
      'error_type': errorType,
    },
  );
}

String _requestFamily(Uri uri) {
  final path = uri.path;
  if (path.startsWith('/aitown-chat/')) return 'chatroom';
  if (path.startsWith('/apix/')) return 'gateway_auth';
  if (path.startsWith('/api/')) return 'business_api';
  return 'other';
}

int? _apiErrNo(Object? data) {
  if (data is! Map) return null;
  final raw = data.containsKey('err_no') ? data['err_no'] : data['errNo'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

Object? _tryDecodeJson(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return input;
  try {
    return jsonDecode(trimmed);
  } catch (_) {
    return input;
  }
}

class _PreparedBody {
  const _PreparedBody({required this.bodyBytes});

  final List<int>? bodyBytes;
}

_PreparedBody _prepareBody(Object? body, Map<String, String> headers) {
  if (body == null) return const _PreparedBody(bodyBytes: null);

  if (body is List<int>) return _PreparedBody(bodyBytes: body);

  if (body is String) {
    return _PreparedBody(bodyBytes: utf8.encode(body));
  }

  if (body is Map || body is List) {
    headers.putIfAbsent('content-type', () => 'application/json');
    return _PreparedBody(bodyBytes: utf8.encode(jsonEncode(body)));
  }

  headers.putIfAbsent('content-type', () => 'text/plain; charset=utf-8');
  return _PreparedBody(bodyBytes: utf8.encode(body.toString()));
}
