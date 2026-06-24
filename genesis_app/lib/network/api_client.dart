import 'dart:convert';

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
      rethrow;
    } catch (e) {
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
    final processed = processor(apiResponse);
    return processed as T;
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
