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
  Future<void> _lifecycle = Future<void>.value();

  bool get isRunning => _server != null;

  Future<void> start(AppServices services) {
    return _scheduleLifecycle(() => _startNow(services));
  }

  Future<void> _startNow(AppServices services) async {
    await _stopNow(updateStatus: false);
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
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: true,
      );
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

  Future<void> stop({bool updateStatus = true, bool force = false}) {
    return _scheduleLifecycle(
      () => _stopNow(updateStatus: updateStatus, force: force),
    );
  }

  Future<void> _stopNow({bool updateStatus = true, bool force = false}) async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: force);
    }
    if (updateStatus) {
      agentControlStatus.value = const AgentControlStatus.disabled();
    }
  }

  Future<void> _scheduleLifecycle(Future<void> Function() operation) {
    final scheduled = _lifecycle.then((_) => operation());
    _lifecycle = scheduled.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return scheduled;
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
      if (request.uri.path == '/worldo/assets') {
        await _handleWorldoAsset(request);
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

  Future<void> _handleWorldoAsset(HttpRequest request) async {
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
    final services = _services;
    if (services == null) {
      throw const AgentControlException(
        code: 'services_unavailable',
        message: 'App services are not available.',
      );
    }
    final contentType =
        request.headers.contentType?.mimeType.toLowerCase() ?? '';
    if (!_worldoAssetContentTypes.contains(contentType)) {
      throw const AgentControlException(
        code: 'unsupported_media_type',
        message: 'Only PNG, JPEG, and WebP images are allowed.',
      );
    }
    if (request.contentLength > _maxWorldoAssetBytes) {
      throw const AgentControlException(
        code: 'asset_too_large',
        message: 'Image exceeds the 25 MB upload limit.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      if (bytes.length + chunk.length > _maxWorldoAssetBytes) {
        throw const AgentControlException(
          code: 'asset_too_large',
          message: 'Image exceeds the 25 MB upload limit.',
        );
      }
      bytes.addAll(chunk);
    }
    final validation = validateWorldoAssetForTesting(bytes, contentType);
    if (validation != null) {
      throw AgentControlException(code: 'invalid_asset', message: validation);
    }
    final requestedName = request.headers.value('x-worldo-filename') ?? '';
    final filename = _safeWorldoAssetFilename(requestedName, contentType);
    final uploaded = await services.api.v1.upload.image(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    _addEvent('worldo.assets ok');
    await _writeJson(request.response, {'ok': true, 'result': uploaded});
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

const int _maxWorldoAssetBytes = 25 * 1024 * 1024;
const Set<String> _worldoAssetContentTypes = {
  'image/png',
  'image/jpeg',
  'image/webp',
};

@visibleForTesting
String? validateWorldoAssetForTesting(List<int> bytes, String contentType) {
  if (bytes.isEmpty) return 'Image body is empty.';
  final isPng =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
  final isJpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final isWebp =
      bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
  final valid = switch (contentType) {
    'image/png' => isPng,
    'image/jpeg' => isJpeg,
    'image/webp' => isWebp,
    _ => false,
  };
  return valid ? null : 'Image bytes do not match the declared content type.';
}

String _safeWorldoAssetFilename(String input, String contentType) {
  final basename = input
      .trim()
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final stem = basename.replaceFirst(RegExp(r'\.[^.]*$'), '').trim();
  final extension = switch (contentType) {
    'image/png' => '.png',
    'image/webp' => '.webp',
    _ => '.jpg',
  };
  return '${stem.isEmpty ? 'worldo-asset' : stem}$extension';
}
