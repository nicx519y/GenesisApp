import 'dart:async';
import 'dart:convert';

import '../app/telemetry/genesis_telemetry.dart';
import 'api_exception.dart';
import 'http_transport.dart';
import 'io_http_transport.dart';
import 'multipart_body.dart';

class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.bodyBytes,
    required this.data,
    required this.uri,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final List<int> bodyBytes;
  final Object? data;
  final Uri uri;
}

enum ApiResponseType { json, text, bytes }

typedef ApiResponseProcessor = Object? Function(ApiResponse response);
typedef RequestHeaderProvider = Future<Map<String, String>> Function();
typedef ApiRequestSender =
    Future<TransportResponse> Function(TransportRequest request);
typedef ApiRequestInterceptor =
    Future<TransportResponse> Function(
      TransportRequest request,
      ApiRequestSender send,
    );

class ApiRetryPolicy {
  const ApiRetryPolicy({
    this.maxAttempts = 1,
    this.methods = const <String>{'GET', 'HEAD'},
    this.exceptionKinds = const <ApiExceptionKind>{
      ApiExceptionKind.transport,
      ApiExceptionKind.timeout,
    },
    this.transportErrorKinds = const <TransportErrorKind>{
      TransportErrorKind.timeout,
      TransportErrorKind.connection,
    },
  });

  static const ApiRetryPolicy none = ApiRetryPolicy(
    maxAttempts: 1,
    methods: <String>{},
    exceptionKinds: <ApiExceptionKind>{},
    transportErrorKinds: <TransportErrorKind>{},
  );

  static const ApiRetryPolicy safe = ApiRetryPolicy(maxAttempts: 2);

  final int maxAttempts;
  final Set<String> methods;
  final Set<ApiExceptionKind> exceptionKinds;
  final Set<TransportErrorKind> transportErrorKinds;

  bool shouldRetry({
    required TransportRequest request,
    required ApiException error,
    required int attempt,
  }) {
    if (attempt >= _effectiveMaxAttempts) return false;
    if (!methods.contains(request.method.trim().toUpperCase())) return false;
    if (!exceptionKinds.contains(error.kind)) return false;
    final transportKind = error.transportErrorKind;
    if (transportKind != null && !transportErrorKinds.contains(transportKind)) {
      return false;
    }
    return true;
  }

  int get _effectiveMaxAttempts => maxAttempts < 1 ? 1 : maxAttempts;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    Map<String, String>? defaultHeaders,
    ApiResponseProcessor? responseProcessor,
    RequestHeaderProvider? requestHeaderProvider,
    ApiRequestInterceptor? requestInterceptor,
    HttpTransport? transport,
    int timeoutMs = 15000,
    ApiRetryPolicy retryPolicy = ApiRetryPolicy.none,
  }) : _baseUri = Uri.parse(baseUrl),
       _defaultHeaders = Map<String, String>.from(defaultHeaders ?? const {}),
       _responseProcessor = responseProcessor ?? defaultResponseProcessor,
       _requestHeaderProvider = requestHeaderProvider,
       _requestInterceptor = requestInterceptor,
       _transport = transport ?? IoHttpTransport(),
       _timeoutMs = timeoutMs,
       _retryPolicy = retryPolicy;

  final Uri _baseUri;
  final Map<String, String> _defaultHeaders;
  final ApiResponseProcessor _responseProcessor;
  final RequestHeaderProvider? _requestHeaderProvider;
  final ApiRequestInterceptor? _requestInterceptor;
  final HttpTransport _transport;
  final int _timeoutMs;
  final ApiRetryPolicy _retryPolicy;

  ApiClient copyWith({
    String? baseUrl,
    Map<String, String>? defaultHeaders,
    ApiResponseProcessor? responseProcessor,
    RequestHeaderProvider? requestHeaderProvider,
    ApiRequestInterceptor? requestInterceptor,
    HttpTransport? transport,
    int? timeoutMs,
    ApiRetryPolicy? retryPolicy,
  }) {
    return ApiClient(
      baseUrl: baseUrl ?? _baseUri.toString(),
      defaultHeaders: defaultHeaders ?? _defaultHeaders,
      responseProcessor: responseProcessor ?? _responseProcessor,
      requestHeaderProvider: requestHeaderProvider ?? _requestHeaderProvider,
      requestInterceptor: requestInterceptor ?? _requestInterceptor,
      transport: transport ?? _transport,
      timeoutMs: timeoutMs ?? _timeoutMs,
      retryPolicy: retryPolicy ?? _retryPolicy,
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, Object?>? query,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
    NetworkProgressCallback? onSendProgress,
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancellationToken? cancellationToken,
  }) {
    return request<T>(
      'GET',
      path,
      query: query,
      headers: headers,
      responseProcessor: responseProcessor,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<List<int>> getBytes(
    String path, {
    Map<String, Object?>? query,
    Map<String, String>? headers,
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancellationToken? cancellationToken,
  }) {
    return request<List<int>>(
      'GET',
      path,
      query: query,
      headers: headers,
      responseType: ApiResponseType.bytes,
      onReceiveProgress: onReceiveProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<String> getText(
    String path, {
    Map<String, Object?>? query,
    Map<String, String>? headers,
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancellationToken? cancellationToken,
  }) {
    return request<String>(
      'GET',
      path,
      query: query,
      headers: headers,
      responseType: ApiResponseType.text,
      onReceiveProgress: onReceiveProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<List<int>> downloadBytes(
    String path, {
    Map<String, Object?>? query,
    Map<String, String>? headers,
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancellationToken? cancellationToken,
  }) {
    return getBytes(
      path,
      query: query,
      headers: headers,
      onReceiveProgress: onReceiveProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<T> post<T>(
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
    NetworkProgressCallback? onSendProgress,
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancellationToken? cancellationToken,
  }) {
    return request<T>(
      'POST',
      path,
      query: query,
      body: body,
      headers: headers,
      responseProcessor: responseProcessor,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<T> put<T>(
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
    NetworkProgressCallback? onSendProgress,
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancellationToken? cancellationToken,
  }) {
    return request<T>(
      'PUT',
      path,
      query: query,
      body: body,
      headers: headers,
      responseProcessor: responseProcessor,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<T> delete<T>(
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
    NetworkProgressCallback? onSendProgress,
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancellationToken? cancellationToken,
  }) {
    return request<T>(
      'DELETE',
      path,
      query: query,
      body: body,
      headers: headers,
      responseProcessor: responseProcessor,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<T> request<T>(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    ApiResponseProcessor? responseProcessor,
    NetworkProgressCallback? onSendProgress,
    NetworkProgressCallback? onReceiveProgress,
    NetworkCancellationToken? cancellationToken,
    ApiResponseType responseType = ApiResponseType.json,
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
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      cancellationToken: cancellationToken,
    );

    TransportResponse transportResponse;
    var attempt = 1;
    var retryCount = 0;
    while (true) {
      try {
        final interceptor = _requestInterceptor;
        transportResponse = interceptor == null
            ? await _send(request)
            : await interceptor(request, _send);
        break;
      } on NetworkRequestCancelledException catch (e) {
        stopwatch.stop();
        _recordHttpTelemetry(
          request: request,
          duration: stopwatch.elapsed,
          outcome: 'cancelled',
          errorType: e.runtimeType.toString(),
          errorKind: ApiExceptionKind.cancelled,
          attemptCount: attempt,
          retryCount: retryCount,
        );
        rethrow;
      } on ApiException catch (error) {
        if (_retryPolicy.shouldRetry(
          request: request,
          error: error,
          attempt: attempt,
        )) {
          retryCount += 1;
          _recordHttpRetryTelemetry(
            request: request,
            attempt: attempt,
            retryCount: retryCount,
            error: error,
          );
          attempt += 1;
          continue;
        }
        stopwatch.stop();
        _recordHttpTelemetry(
          request: request,
          duration: stopwatch.elapsed,
          outcome: 'api_exception',
          errorType: error.runtimeType.toString(),
          errorKind: error.kind,
          transportErrorKind: error.transportErrorKind,
          retryable: error.retryable,
          attemptCount: attempt,
          retryCount: retryCount,
        );
        rethrow;
      } catch (error) {
        final apiError = _transportApiException(error, uri);
        if (_retryPolicy.shouldRetry(
          request: request,
          error: apiError,
          attempt: attempt,
        )) {
          retryCount += 1;
          _recordHttpRetryTelemetry(
            request: request,
            attempt: attempt,
            retryCount: retryCount,
            error: apiError,
          );
          attempt += 1;
          continue;
        }
        stopwatch.stop();
        _recordHttpTelemetry(
          request: request,
          duration: stopwatch.elapsed,
          outcome: 'transport_exception',
          errorType: error.runtimeType.toString(),
          errorKind: apiError.kind,
          transportErrorKind: apiError.transportErrorKind,
          retryable: apiError.retryable,
          attemptCount: attempt,
          retryCount: retryCount,
        );
        throw apiError;
      }
    }

    final bodyBytes = transportResponse.bodyBytes.isEmpty
        ? utf8.encode(transportResponse.body)
        : transportResponse.bodyBytes;
    final decoded = _decodeResponseData(
      responseType: responseType,
      body: transportResponse.body,
      bodyBytes: bodyBytes,
    );
    final apiResponse = ApiResponse(
      statusCode: transportResponse.statusCode,
      headers: transportResponse.headers,
      body: transportResponse.body,
      bodyBytes: bodyBytes,
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
        attemptCount: attempt,
        retryCount: retryCount,
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
        errorKind: error is ApiException
            ? error.kind
            : ApiExceptionKind.response,
        transportErrorKind: error is ApiException
            ? error.transportErrorKind
            : null,
        retryable: error is ApiException ? error.retryable : false,
        attemptCount: attempt,
        retryCount: retryCount,
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
      kind: ApiExceptionKind.httpStatus,
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
  ApiExceptionKind? errorKind,
  TransportErrorKind? transportErrorKind,
  bool retryable = false,
  int attemptCount = 1,
  int retryCount = 0,
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
      'error_kind': errorKind?.name,
      'transport_error_kind': transportErrorKind?.name,
      'retryable': retryable,
      'attempt_count': attemptCount,
      'retry_count': retryCount,
    },
  );
}

void _recordHttpRetryTelemetry({
  required TransportRequest request,
  required int attempt,
  required int retryCount,
  required ApiException error,
}) {
  GenesisTelemetry.event(
    'http_request_retry',
    category: 'network.http',
    data: <String, Object?>{
      'method': request.method.toUpperCase(),
      'host': request.uri.host,
      'path': request.uri.path,
      'request_family': _requestFamily(request.uri),
      'attempt': attempt,
      'retry_count': retryCount,
      'error_kind': error.kind.name,
      'transport_error_kind': error.transportErrorKind?.name,
      'error_type': error.error?.runtimeType.toString(),
    },
    level: GenesisTelemetryLevel.warning,
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

Object? _decodeResponseData({
  required ApiResponseType responseType,
  required String body,
  required List<int> bodyBytes,
}) {
  switch (responseType) {
    case ApiResponseType.json:
      return _tryDecodeJson(body);
    case ApiResponseType.text:
      return body;
    case ApiResponseType.bytes:
      return bodyBytes;
  }
}

ApiException _transportApiException(Object error, Uri uri) {
  final transportKind = _transportErrorKind(error);
  return ApiException(
    message: 'Request failed',
    error: error,
    uri: uri,
    kind: transportKind == TransportErrorKind.timeout
        ? ApiExceptionKind.timeout
        : ApiExceptionKind.transport,
    transportErrorKind: transportKind,
    retryable:
        transportKind == TransportErrorKind.timeout ||
        transportKind == TransportErrorKind.connection,
  );
}

TransportErrorKind _transportErrorKind(Object error) {
  if (error is TimeoutException) return TransportErrorKind.timeout;
  final text = error.toString().toLowerCase();
  if (text.contains('timeout')) return TransportErrorKind.timeout;
  if (text.contains('cancel')) return TransportErrorKind.cancelled;
  if (text.contains('certificate') || text.contains('handshake')) {
    return TransportErrorKind.badCertificate;
  }
  if (text.contains('socketexception') ||
      text.contains('connection reset') ||
      text.contains('connection refused') ||
      text.contains('connection closed') ||
      text.contains('broken pipe') ||
      text.contains('network is unreachable') ||
      text.contains('failed host lookup')) {
    return TransportErrorKind.connection;
  }
  return TransportErrorKind.unknown;
}

class _PreparedBody {
  const _PreparedBody({required this.bodyBytes});

  final List<int>? bodyBytes;
}

_PreparedBody _prepareBody(Object? body, Map<String, String> headers) {
  if (body == null) return const _PreparedBody(bodyBytes: null);

  if (body is MultipartBody) {
    headers['content-type'] = body.contentType;
    return _PreparedBody(bodyBytes: body.toBytes());
  }

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
