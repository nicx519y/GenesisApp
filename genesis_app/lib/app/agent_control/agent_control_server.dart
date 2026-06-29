import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../bootstrap/service_registry.dart';
import 'agent_control_models.dart';
import 'agent_control_registry.dart';
import 'agent_control_status.dart';

class AgentControlServer {
  AgentControlServer({AgentControlRegistry? registry})
    : _registry = registry ?? AgentControlRegistry();

  static const _host = '127.0.0.1';

  final AgentControlRegistry _registry;
  HttpServer? _server;
  String? _token;
  bool _tokenConfigured = false;
  AppServices? _services;
  final List<String> _recentEvents = <String>[];

  bool get isRunning => _server != null;

  Future<void> start(AppServices services) async {
    await stop(updateStatus: false);
    _services = services;
    final config = services.config;
    if (!config.agentControlEnabled) {
      agentControlStatus.value = const AgentControlStatus.disabled();
      return;
    }
    final port = config.agentControlPort <= 0
        ? _defaultAgentControlPort
        : config.agentControlPort;
    _tokenConfigured = config.agentControlToken.trim().isNotEmpty;
    _token = _tokenConfigured
        ? config.agentControlToken.trim()
        : _generateToken();
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _publishStatus(running: true, port: port);
      unawaited(_serve(_server!));
      _addEvent('listening $_host:$port');
      debugPrint('[AgentControl] listening on $_host:$port');
    } catch (error) {
      _server = null;
      _publishStatus(running: false, port: port, lastError: error.toString());
      debugPrint('[AgentControl] failed to listen on $_host:$port: $error');
    }
  }

  Future<void> stop({bool updateStatus = true, bool force = false}) async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: force);
    }
    if (updateStatus) {
      agentControlStatus.value = const AgentControlStatus.disabled();
    }
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handle(request));
      }
    } catch (error) {
      if (identical(_server, server)) {
        _publishStatus(
          running: false,
          port: server.port,
          lastError: error.toString(),
        );
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _writeJson(request.response, {
          'ok': true,
          'status': agentControlStatus.value.label,
        });
        return;
      }
      if (request.uri.path != '/rpc') {
        await _writeJson(request.response, {
          'ok': false,
          'error': 'not_found',
        }, statusCode: HttpStatus.notFound);
        return;
      }
      if (request.method != 'POST') {
        await _writeJson(request.response, {
          'ok': false,
          'error': 'method_not_allowed',
        }, statusCode: HttpStatus.methodNotAllowed);
        return;
      }
      if (!_isAuthorized(request)) {
        await _writeJson(request.response, {
          'ok': false,
          'error': 'unauthorized',
        }, statusCode: HttpStatus.unauthorized);
        return;
      }
      final rawBody = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(rawBody);
      final controlRequest = AgentControlRequest.fromJson(decoded);
      final services = _services;
      if (services == null) {
        throw const AgentControlException(
          code: 'services_unavailable',
          message: 'App services are not available.',
        );
      }
      final response = await _registry.execute(
        controlRequest,
        AgentControlContext(services: services),
      );
      _addEvent('${controlRequest.method} ${response.ok ? 'ok' : 'failed'}');
      await _writeJson(request.response, response.toJson());
    } on AgentControlException catch (error) {
      await _writeJson(request.response, {
        'ok': false,
        'error': error.toJson(),
      });
    } catch (error) {
      await _writeJson(request.response, {
        'ok': false,
        'error': {'code': 'bad_request', 'message': error.toString()},
      }, statusCode: HttpStatus.badRequest);
    }
  }

  bool _isAuthorized(HttpRequest request) {
    final token = _token;
    if (token == null || token.isEmpty) return false;
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    if (authorization == 'Bearer $token') return true;
    return request.headers.value('x-genesis-agent-token') == token;
  }

  Future<void> _writeJson(
    HttpResponse response,
    Object body, {
    int statusCode = HttpStatus.ok,
  }) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  void _addEvent(String event) {
    _recentEvents.insert(0, event);
    if (_recentEvents.length > 5) {
      _recentEvents.removeRange(5, _recentEvents.length);
    }
    final current = agentControlStatus.value;
    agentControlStatus.value = current.copyWith(
      recentEvents: List<String>.unmodifiable(_recentEvents),
      lastError: current.lastError,
    );
  }

  void _publishStatus({
    required bool running,
    required int port,
    String? lastError,
  }) {
    agentControlStatus.value = AgentControlStatus(
      enabled: true,
      running: running,
      host: _host,
      port: port,
      tokenConfigured: _tokenConfigured,
      tokenPreview: _previewToken(_token),
      lastError: lastError,
      recentEvents: List<String>.unmodifiable(_recentEvents),
    );
  }
}

const _defaultAgentControlPort = 17317;

String _generateToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

String? _previewToken(String? token) {
  final value = token?.trim() ?? '';
  if (value.isEmpty) return null;
  if (value.length <= 8) return '****';
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}
