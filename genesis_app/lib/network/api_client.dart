import 'dart:async';
import 'dart:convert';

import '../app/telemetry/genesis_telemetry.dart';
import 'api_exception.dart';
import 'genesis_http_transport_pool.dart';
import 'http_transport.dart';
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
       _transport = transport ?? GenesisHttpTransportRegistry.current,
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
    final collectRequest = _BusinessApiCollectRequest.maybeStart(uri);

    late final TransportRequest request;
    var requestPreparationFailureReason = 'request_headers';
    try {
      final runtimeHeaders = await _resolveRequestHeaders();
      final mergedHeaders = <String, String>{
        ..._defaultHeaders,
        ...runtimeHeaders,
        ...?headers,
      };
      requestPreparationFailureReason = 'request_body';
      final prepared = _prepareBody(body, mergedHeaders);

      request = TransportRequest(
        method: method,
        uri: uri,
        headers: mergedHeaders,
        bodyBytes: prepared.bodyBytes,
        timeoutMs: _timeoutMs,
        decodeResponseBody: responseType != ApiResponseType.bytes,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancellationToken: cancellationToken,
      );
    } on NetworkRequestCancelledException catch (error) {
      stopwatch.stop();
      collectRequest?.failure(
        'cancelled',
        duration: stopwatch.elapsed,
        error: error,
      );
      rethrow;
    } on ApiException catch (error) {
      stopwatch.stop();
      collectRequest?.failure(
        _businessApiFailureReason(error),
        duration: stopwatch.elapsed,
        error: error,
      );
      rethrow;
    } catch (error) {
      stopwatch.stop();
      collectRequest?.failure(
        requestPreparationFailureReason,
        duration: stopwatch.elapsed,
        error: error,
      );
      rethrow;
    }

    TransportResponse transportResponse;
    late Stopwatch attemptStopwatch;
    var attempt = 1;
    var retryCount = 0;
    while (true) {
      attemptStopwatch = Stopwatch()..start();
      try {
        final interceptor = _requestInterceptor;
        transportResponse = interceptor == null
            ? await _send(request)
            : await interceptor(request, _send);
        break;
      } on NetworkRequestCancelledException catch (e) {
        attemptStopwatch.stop();
        stopwatch.stop();
        collectRequest?.failure(
          'cancelled',
          duration: attemptStopwatch.elapsed,
          error: e,
        );
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
          attemptStopwatch.stop();
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
        attemptStopwatch.stop();
        stopwatch.stop();
        collectRequest?.failure(
          _businessApiFailureReason(error),
          duration: attemptStopwatch.elapsed,
          error: error,
        );
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
          attemptStopwatch.stop();
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
        attemptStopwatch.stop();
        stopwatch.stop();
        collectRequest?.failure(
          _businessApiFailureReason(apiError),
          duration: attemptStopwatch.elapsed,
          error: apiError,
        );
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
    final isSuccessfulStatus =
        transportResponse.statusCode >= 200 &&
        transportResponse.statusCode < 300;
    final responseBody =
        responseType == ApiResponseType.bytes &&
            !isSuccessfulStatus &&
            transportResponse.body.isEmpty &&
            bodyBytes.isNotEmpty
        ? utf8.decode(bodyBytes, allowMalformed: true)
        : transportResponse.body;
    final decoded = _decodeResponseData(
      responseType: responseType,
      body: responseBody,
      bodyBytes: bodyBytes,
    );
    final apiResponse = ApiResponse(
      statusCode: transportResponse.statusCode,
      headers: transportResponse.headers,
      body: responseBody,
      bodyBytes: bodyBytes,
      data: decoded,
      uri: uri,
    );
    collectRequest?.inspectResponse(
      response: apiResponse,
      responseType: responseType,
      duration: attemptStopwatch.elapsed,
    );

    final processor = responseProcessor ?? _responseProcessor;
    try {
      final processed = processor(apiResponse);
      attemptStopwatch.stop();
      stopwatch.stop();
      collectRequest?.success(attempt, duration: attemptStopwatch.elapsed);
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
      attemptStopwatch.stop();
      stopwatch.stop();
      collectRequest?.failure(
        _businessApiFailureReason(error, response: apiResponse),
        duration: attemptStopwatch.elapsed,
        error: error,
        response: apiResponse,
      );
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

class _BusinessApiCollectRequest {
  _BusinessApiCollectRequest._({required this.path, required this.requestId});

  static _BusinessApiCollectRequest? maybeStart(Uri uri) {
    if (!uri.path.startsWith('/api/')) return null;
    if (_businessApiCollectExcludedPaths.contains(uri.path)) return null;
    try {
      final request = _BusinessApiCollectRequest._(
        path: uri.path,
        requestId: newCollectEventId(),
      );
      request._record(action: 'api_request_start', object3: '', object4: '');
      return request;
    } catch (_) {
      // Telemetry must never prevent the business request from running.
      return null;
    }
  }

  final String path;
  final String requestId;
  bool _terminalRecorded = false;

  void success(int attempt, {required Duration duration}) {
    if (_terminalRecorded) return;
    _terminalRecorded = true;
    _record(
      action: 'api_request_success',
      object3: 'attempt_$attempt',
      object4: duration.inMilliseconds.toString(),
    );
  }

  void failure(
    String reason, {
    required Duration duration,
    Object? error,
    ApiResponse? response,
    String? errorMessage,
  }) {
    if (_terminalRecorded) return;
    _terminalRecorded = true;
    _record(
      action: 'api_request_failed',
      object3: reason,
      object4: duration.inMilliseconds.toString(),
      extData: _apiRequestFailureExtData(
        reason: reason,
        error: error,
        response: response,
        errorMessage: errorMessage,
      ),
    );
  }

  void inspectResponse({
    required ApiResponse response,
    required ApiResponseType responseType,
    required Duration duration,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      failure(
        'http_${response.statusCode}',
        duration: duration,
        response: response,
      );
      return;
    }
    if (_isMalformedJsonResponse(responseType, response.body)) {
      failure(
        'decode',
        duration: duration,
        response: response,
        errorMessage: 'Response body is not valid JSON.',
      );
      return;
    }
    final errNo = _apiErrNo(response.data);
    if (errNo != null && errNo != 0) {
      failure('business_$errNo', duration: duration, response: response);
    }
  }

  void _record({
    required String action,
    required String object3,
    required String object4,
    String extData = '',
  }) {
    try {
      GenesisTelemetry.collectLog(
        actionType: 'event',
        action: action,
        object1: path,
        object2: requestId,
        object3: object3,
        object4: object4,
        extData: extData,
      );
    } catch (_) {
      // Telemetry must never change the business request result.
    }
  }
}

const Set<String> _businessApiCollectExcludedPaths = <String>{
  '/api/v1/message/unread',
  '/api/v1/direct_message/conversations',
  '/api/v1/direct_message/list',
};

bool _isMalformedJsonResponse(ApiResponseType responseType, String body) {
  if (responseType != ApiResponseType.json || body.trim().isEmpty) return false;
  try {
    jsonDecode(body);
    return false;
  } catch (_) {
    return true;
  }
}

String _businessApiFailureReason(Object error, {ApiResponse? response}) {
  if (error is NetworkRequestCancelledException) return 'cancelled';
  if (error is! ApiException) return 'response';

  switch (error.transportErrorKind) {
    case TransportErrorKind.timeout:
      return 'timeout';
    case TransportErrorKind.connection:
      return 'connection';
    case TransportErrorKind.badCertificate:
      return 'bad_certificate';
    case TransportErrorKind.cancelled:
      return 'cancelled';
    case TransportErrorKind.unknown:
    case null:
      break;
  }

  switch (error.kind) {
    case ApiExceptionKind.timeout:
      return 'timeout';
    case ApiExceptionKind.httpStatus:
      final statusCode = error.statusCode ?? response?.statusCode;
      return statusCode == null ? 'http_status' : 'http_$statusCode';
    case ApiExceptionKind.business:
      final errNo = error.code ?? _apiErrNo(response?.data);
      return errNo == null ? 'business' : 'business_$errNo';
    case ApiExceptionKind.response:
      return 'response';
    case ApiExceptionKind.gatewayAuth:
      return 'gateway_auth';
    case ApiExceptionKind.cancelled:
      return 'cancelled';
    case ApiExceptionKind.transport:
      return _unknownTransportFailureReason(error);
    case ApiExceptionKind.unknown:
      return 'api_unknown';
  }
}

String _apiRequestFailureExtData({
  required String reason,
  Object? error,
  ApiResponse? response,
  String? errorMessage,
}) {
  try {
    final apiError = error is ApiException ? error : null;
    final cause = apiError?.error;
    final causeText = cause == null ? '' : _safeRawErrorText(cause);
    final responseErrorCode = _apiErrNo(response?.data);
    final responseErrorMessage = _responseErrorMessage(response?.data);
    final resolvedMessage = errorMessage?.trim().isNotEmpty == true
        ? errorMessage!
        : apiError?.message.trim().isNotEmpty == true
        ? apiError!.message
        : error != null
        ? _safeRawErrorText(error)
        : responseErrorMessage;
    final nativeErrorCode = cause == null
        ? null
        : _errorCode(causeText, 'quicDetailedErrorCode') ??
              _errorCode(causeText, 'errorCode') ??
              _errorCode(causeText, 'code');

    final details = <String, Object?>{
      'error_type': _apiFailureErrorType(reason, error),
      if (apiError?.code ?? responseErrorCode case final code?)
        'error_code': code,
      if (apiError?.statusCode ?? response?.statusCode case final statusCode?)
        'status_code': statusCode,
      if (resolvedMessage != null && resolvedMessage.trim().isNotEmpty)
        'error_message': _sanitizeErrorMessage(resolvedMessage),
      if (error != null) 'exception_type': error.runtimeType.toString(),
      if (apiError != null) 'exception_kind': apiError.kind.name,
      if (apiError?.transportErrorKind case final transportKind?)
        'transport_error_kind': transportKind.name,
      if (cause != null) 'native_error_type': cause.runtimeType.toString(),
      if (nativeErrorCode != null) 'native_error_code': nativeErrorCode,
      if (causeText.trim().isNotEmpty)
        'native_error_message': _sanitizeErrorMessage(causeText),
    };
    return jsonEncode(details);
  } catch (_) {
    return '{"error_type":"ext_data_build_failed"}';
  }
}

String _apiFailureErrorType(String reason, Object? error) {
  if (error is ApiException) return error.kind.name;
  if (reason.startsWith('business_')) return 'business';
  if (reason.startsWith('http_')) return 'http_status';
  if (reason == 'decode') return 'response_decode';
  if (reason.startsWith('request_')) return 'request_prepare';
  if (reason == 'cancelled') return 'cancelled';
  if (reason == 'response') return 'response';
  return 'transport';
}

String? _responseErrorMessage(Object? data) {
  if (data is! Map) return null;
  for (final key in <String>[
    'err_msg',
    'errMsg',
    'err_str',
    'errStr',
    'error',
    'message',
    'detail',
  ]) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value;
    if (value is num || value is bool) return value.toString();
  }
  return null;
}

String _sanitizeErrorMessage(String input) {
  var value = input.trim().replaceAll(RegExp(r'[\r\n\t]+'), ' ');
  value = value.replaceAll(
    RegExp(r'https?://[^\s,\])}]+', caseSensitive: false),
    '<url>',
  );
  value = value.replaceAll(
    RegExp(r'\bbearer\s+[^\s,;}]+', caseSensitive: false),
    'Bearer <redacted>',
  );
  value = value.replaceAllMapped(
    RegExp(
      r'\b(authorization|access[_-]?token|refresh[_-]?token|id[_-]?token|password|secret|cookie)\b\s*[:=]\s*[^\s,;}]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=<redacted>',
  );
  value = value.replaceAll(
    RegExp(r'\b[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\b'),
    '<redacted-jwt>',
  );
  const maxLength = 1024;
  return value.length <= maxLength ? value : value.substring(0, maxLength);
}

String _unknownTransportFailureReason(ApiException error) {
  final cause = error.error;
  if (cause == null) return 'transport_unknown';

  final type = cause.runtimeType.toString().toLowerCase();
  final text = _safeErrorText(cause);
  final signature = '$type $text';

  final mentionsHttpProtocol =
      signature.contains('http/2') ||
      signature.contains('http2') ||
      signature.contains('http/3') ||
      signature.contains('http3');
  final describesProtocolFailure =
      signature.contains('protocol') ||
      signature.contains('negotiat') ||
      signature.contains('requires http') ||
      signature.contains('not support');
  if (mentionsHttpProtocol && describesProtocolFailure) {
    return 'http_protocol';
  }

  if (signature.contains('quic')) {
    final code = _errorCode(text, 'quicDetailedErrorCode');
    return code == null ? 'http3_quic' : 'http3_quic_$code';
  }

  if (signature.contains('cronet') ||
      signature.contains('networkclientexception') ||
      signature.contains('callbackexception')) {
    final code = _errorCode(text, 'errorCode');
    return code == null ? 'cronet' : 'cronet_$code';
  }

  if (signature.contains('nserrorclientexception')) {
    final code = _errorCode(text, 'code');
    return code == null ? 'ios_network' : 'ios_network_$code';
  }

  if (signature.contains('dioexception')) {
    if (signature.contains('[connection error]')) return 'dio_connection';
    if (signature.contains('[bad response]')) return 'dio_response';
    return 'dio_unknown';
  }

  if (signature.contains('clientexception')) return 'http_client';
  if (cause is StateError ||
      cause is ArgumentError ||
      cause is UnsupportedError) {
    return 'transport_internal';
  }
  return 'transport_unknown';
}

String? _errorCode(String text, String field) {
  final match = RegExp(
    '${RegExp.escape(field)}=(-?\\d+)',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(1);
}

String _safeErrorText(Object error) {
  return _safeRawErrorText(error).toLowerCase();
}

String _safeRawErrorText(Object error) {
  try {
    return error.toString();
  } catch (_) {
    return '';
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
  final text = _safeErrorText(error);
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
