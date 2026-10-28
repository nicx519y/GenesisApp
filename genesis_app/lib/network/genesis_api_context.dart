part of 'genesis_api.dart';

abstract class _GenesisApiContext {
  Future<String> _ensureUid();

  GemBalanceAlertHandler? onGemBalanceAlert;

  _GenesisApiContext({
    ApiClient? apiClient,
    ApiClient? gatewayApiClient,
    ApiClient? healthClient,
    ApiClient? chatroomHttpClient,
    HttpTransport? transport,
    bool? useMock,
    PlatformConfig? platformConfig,
    String? gatewayApiBaseUrl,
    String? chatroomHttpBaseUrl,
    DeviceIdService? deviceIdService,
    UserSessionStore? sessionStore,
    IdentityAuthService? identityAuthService,
    RequestHeaderProvider? appHeaderProvider,
    AppLanguageController? languageController,
    GatewayRequestInterceptor? gatewayRequestInterceptor,
    Future<void> Function(String message)? onSessionExpired,
    void Function(String message)? onChatroomMessageMutationError,
  }) {
    final resolvedPlatformConfig =
        platformConfig ?? const DefaultPlatformConfig();
    _languageController = languageController;
    _deviceIdService = deviceIdService ?? const NativeDeviceIdService();
    _sessionStore = sessionStore ?? NativeUserSessionStore();
    _identityAuthService =
        identityAuthService ??
        ProviderIdentityAuthService(sessionStore: _sessionStore);
    _appHeaderProvider =
        appHeaderProvider ?? AppRequestHeaderProvider().headers;
    _onSessionExpired = onSessionExpired;
    _onChatroomMessageMutationError = onChatroomMessageMutationError;
    final resolvedTransport = _resolveTransport(
      transport: transport,
      useMock: useMock,
    );
    final gatewayInterceptor = gatewayRequestInterceptor?.call;

    _apiClient =
        apiClient ??
        ApiClient(
          baseUrl: _normalizeBaseUrl(resolvedPlatformConfig.apiBaseUrl),
          defaultHeaders: {
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          requestHeaderProvider: _runtimeRequestHeaders,
          requestInterceptor: gatewayInterceptor,
          transport: resolvedTransport,
          retryPolicy: ApiRetryPolicy.safe,
          responseProcessor: _processGenesisResponse,
        );
    final ungatedGatewayClient =
        gatewayApiClient ??
        ApiClient(
          baseUrl: _normalizeBaseUrl(
            gatewayApiBaseUrl ?? GenesisApi.defaultGatewayApiBaseUrl,
          ),
          defaultHeaders: {
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          requestHeaderProvider: _runtimeRequestHeaders,
          requestInterceptor: gatewayInterceptor,
          transport: resolvedTransport,
          responseProcessor: _processGenesisResponse,
        );
    _healthClient = healthClient ?? ungatedGatewayClient;
    _chatroomHttpClient =
        chatroomHttpClient ??
        ApiClient(
          baseUrl: _normalizeBaseUrl(
            chatroomHttpBaseUrl ?? GenesisApi.defaultChatroomHttpBaseUrl,
          ),
          defaultHeaders: const {
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          requestHeaderProvider: _runtimeRequestHeaders,
          requestInterceptor: LocationChatDebugHttp.wrapChatroomHttpInterceptor(
            gatewayInterceptor,
          ),
          transport: resolvedTransport,
          responseProcessor: _processGenesisResponse,
        );
    v1 = GenesisV1Api(
      _apiClient,
      currentUserInfoSessionProvider: _readCurrentUserInfoSession,
      languageController: languageController,
    );
    v2 = GenesisV2Api(_apiClient);
    chatroomHttp = ChatroomHttpApi(_chatroomHttpClient);
    miniPhone = MiniPhoneApi(_chatroomHttpClient);
  }

  late final ApiClient _apiClient;
  late final ApiClient _healthClient;
  late final ApiClient _chatroomHttpClient;
  late final GenesisV1Api v1;
  late final GenesisV2Api v2;
  late final ChatroomHttpApi chatroomHttp;
  late final MiniPhoneApi miniPhone;
  late final DeviceIdService _deviceIdService;
  late final AppLanguageController? _languageController;
  late final UserSessionStore _sessionStore;
  late final IdentityAuthService _identityAuthService;
  late final RequestHeaderProvider _appHeaderProvider;
  late final Future<void> Function(String message)? _onSessionExpired;
  late final void Function(String message)? _onChatroomMessageMutationError;

  Future<Map<String, String>> _runtimeRequestHeaders() async {
    final headers = <String, String>{...await _safeAppHeaders()};

    final authToken = await _readHeaderValue(_sessionStore.readAuthToken);
    if (authToken != null) {
      headers['authorization'] = authToken.toLowerCase().startsWith('bearer ')
          ? authToken
          : 'Bearer $authToken';
    }
    return headers;
  }

  Future<({String uid, String authToken})?>
  _readCurrentUserInfoSession() async {
    final session = await _sessionStore.readCompleteSession();
    if (session == null) return null;
    return (uid: session.uid, authToken: session.authToken);
  }

  Future<Map<String, String>> _safeAppHeaders() async {
    try {
      return stripLegacyAppPublicHeaders(await _appHeaderProvider());
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<String?> _readHeaderValue(Future<String?> Function() read) async {
    try {
      final value = (await read())?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Object? _processGenesisResponse(ApiResponse response) {
    final data = _defaultGenesisProcessor(response);
    _throwIfSessionExpired(response);
    final envelope = response.data;
    if (envelope is Map && isGemBalanceFailureCode(envelope['err_no'])) {
      onGemBalanceAlert?.call(
        GemBalanceAlert(
          kind: GemBalanceAlertKind.insufficient,
          message: asString(envelope['err_msg']),
          analyticsTrigger: response.uri.path == '/api/v1/world/tick'
              ? 'tick_no_balance'
              : null,
        ),
        response.requestAuthorization,
      );
      // Preserve the envelope: callers still handle rejection and drafts.
      return data;
    }
    if (_isChatroomReplyActionResponse(response.uri)) {
      final envelope = response.data;
      if (envelope is Map &&
          envelope['err_no'] is int &&
          envelope['err_no'] != 0) {
        // Session expiry has already taken the global sign-out path above.
        // Keep the envelope intact so ChatroomHttpApi still throws its business
        // exception, allowing the service to refresh history for 2011 / 2013.
        final quotaFailure =
            envelope['err_no'] == 2030 &&
            (response.uri.pathSegments.last == 'inspiration' ||
                response.uri.pathSegments.last == 'batch');
        if (!quotaFailure) {
          _onChatroomMessageMutationError?.call(asString(envelope['err_msg']));
        }
      }
      return data;
    }
    return data;
  }

  bool _isChatroomReplyActionResponse(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 8 ||
        segments[0] != 'aitown-chat' ||
        segments[1] != 'api' ||
        segments[2] != 'v1' ||
        segments[3] != 'worlds' ||
        segments[5] != 'locations') {
      return false;
    }
    if (segments.length == 8 && segments[7] == 'inspiration') return true;
    return segments.length == 9 &&
        segments[7] == 'llm-messages' &&
        const {'batch', 'cards', 'select'}.contains(segments[8]);
  }

  void _throwIfSessionExpired(ApiResponse response) {
    final data = response.data;
    if (data is! Map) return;
    final map = asJsonMap(data);
    final errNoRaw = map.containsKey('err_no') ? map['err_no'] : map['errNo'];
    final errNo = asInt(errNoRaw);
    if (errNo != 10001) return;

    const message = 'Your account is logged in on another device.';
    final handler = _onSessionExpired;
    if (handler != null) {
      unawaited(_notifyCurrentSessionExpired(response, handler, message));
    }
    throw ApiException(
      message: message,
      serverErrMsg: serverErrorMessageFromResponse(map),
      code: errNo,
      statusCode: response.statusCode,
      responseBody: response.body,
      responseHeaders: response.headers,
      uri: response.uri,
      kind: ApiExceptionKind.business,
    );
  }

  Future<void> _notifyCurrentSessionExpired(
    ApiResponse response,
    Future<void> Function(String message) handler,
    String message,
  ) async {
    // Explicit session termination must never be treated as a forced logout,
    // even if its response races the local credential removal.
    if (const {
      '/api/v1/user/logout',
      '/api/v1/user/delete',
    }.contains(response.uri.path)) {
      return;
    }
    final requestToken = _authorizationToken(response.requestAuthorization);
    if (requestToken.isEmpty) return;

    CompleteUserSession? session;
    try {
      session = await _sessionStore.readCompleteSession();
    } catch (_) {
      // Without a readable current session, ownership cannot be established.
      return;
    }
    if (session == null ||
        _authorizationToken(session.authToken) != requestToken) {
      return;
    }
    // Guests, explicit sign-out and a previous account's in-flight responses
    // still receive their business error, but cannot clear/navigate/toast the
    // current session. Only its own rejected credential invokes the handler.
    await handler(message);
  }

  String _authorizationToken(String? value) => (value ?? '')
      .trim()
      .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
      .trim();
}
