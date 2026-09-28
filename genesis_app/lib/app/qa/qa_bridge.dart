import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../platform/session/user_session_store.dart';

bool qaBridgeAllowed({
  required bool debug,
  required String? flavor,
  required bool enabled,
}) => debug && flavor == 'internal' && enabled;

/// Only the internal debug test installation exposes this interface. Observations
/// come from the same service instance handed to GenesisApp.
class QaBridge {
  QaBridge(
    this.store, {
    required this.token,
    required this.buildId,
    this.operations = const {},
  });
  final Map<String, Future<Object?> Function(Map<String, dynamic>, bool)>
  operations;
  final UserSessionStore store;
  final String token;
  final String buildId;
  final String resource = 'session-${Random.secure().nextInt(1 << 32)}';
  final Completer<void> _resume = Completer<void>();
  HttpServer? _server;
  bool _prepared = false;
  bool started = false;
  bool _busy = false;
  static QaBridge? current;
  static const interfaceVersion = 1;
  static const interfaces = [
    'session.local.prepare',
    'session.local.read',
    'session.local.cleanup',
    'app.startup.resume',
    'app.startup.continue',
    'app.started.read',
  ];

  static Future<void> beforeStartup(
    UserSessionStore store, {
    Map<String, Future<Object?> Function(Map<String, dynamic>, bool)>
        operations =
        const {},
  }) async {
    if (!qaBridgeAllowed(
      debug: kDebugMode,
      flavor: appFlavor,
      enabled: const bool.fromEnvironment('GENESIS_QA_BRIDGE'),
    )) {
      return;
    }
    const token = String.fromEnvironment('GENESIS_QA_BRIDGE_TOKEN');
    const build = String.fromEnvironment('GENESIS_QA_BUILD_ID');
    if (token.length < 32 || build.isEmpty) {
      throw StateError('QA bridge requires a run token and build identity');
    }
    final bridge = QaBridge(
      store,
      token: token,
      buildId: build,
      operations: operations,
    );
    current = bridge;
    await bridge.listen();
    try {
      await bridge.waitForStartup(
        hold: const bool.fromEnvironment(
          'GENESIS_QA_HOLD_STARTUP',
          defaultValue: true,
        ),
      );
    } catch (_) {
      await bridge.close();
      rethrow; // Never continue a test whose preparation was not completed.
    }
  }

  /// Contract tests pause before launch for positive/negative fixtures. A Case
  /// session follows normal App startup without preparing or clearing identity.
  Future<void> waitForStartup({required bool hold}) async {
    if (!hold && !_resume.isCompleted) _resume.complete();
    await _resume.future.timeout(const Duration(minutes: 3));
  }

  Future<void> listen({int port = 18765}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handle);
  }

  int get port => _server!.port;
  Future<void> close() async {
    await _server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    try {
      if (request.method != 'POST' ||
          request.uri.path != '/qa' ||
          request.headers.value('authorization') != 'Bearer $token') {
        response.statusCode = HttpStatus.forbidden;
        response.write(jsonEncode({'error': 'Unavailable'}));
        return;
      }
      if (_busy) {
        response.statusCode = HttpStatus.conflict;
        response.write(
          jsonEncode({'error': 'Another QA operation is running'}),
        );
        return;
      }
      _busy = true;
      try {
        final bytes = <int>[];
        await for (final chunk in request) {
          bytes.addAll(chunk);
          if (bytes.length > 8192) {
            throw const FormatException('Request too large');
          }
        }
        final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final id = data['interface'];
        final parameters = data['parameters'] as Map<String, dynamic>? ?? {};
        if (data['buildId'] != buildId || data['requestId'] is! String) {
          throw StateError('Build or request mismatch');
        }
        if (data['resource'] != null && data['resource'] != resource) {
          throw StateError('Wrong service instance');
        }
        Object? actual;
        switch (id) {
          case 'session.local.prepare':
            if (_resume.isCompleted || started) {
              throw StateError(
                'Session preparation is only allowed before startup',
              );
            }
            if (const String.fromEnvironment('GENESIS_API_ENV') != 'mock') {
              throw StateError('State preparation requires mock environment');
            }
            final uid = parameters['uid'];
            if (uid != null &&
                (uid is! String || !uid.startsWith('qa_test_'))) {
              throw ArgumentError('Only QA test identities are accepted');
            }
            await store.clearUid();
            if (uid != null) await store.saveUid(uid as String);
            _prepared = true;
            actual = await store.readLoginUid();
            break;
          case 'session.local.read':
            actual = await store.readLoginUid();
            break;
          case 'session.local.cleanup':
            if (const String.fromEnvironment('GENESIS_API_ENV') != 'mock') {
              throw StateError('Cleanup requires mock environment');
            }
            await store.clearUid();
            actual = await store.readLoginUid();
            break;
          case 'app.startup.resume':
            if (!_prepared) throw StateError('Session has not been prepared');
            if (!_resume.isCompleted) _resume.complete();
            actual = true;
            break;
          case 'app.startup.continue':
            // Release the instrumentation barrier for a fresh Case session.
            // Contract fixtures must not be carried into a business run.
            if (_prepared) {
              throw StateError('Case startup cannot reuse prepared fixtures');
            }
            if (!_resume.isCompleted) _resume.complete();
            actual = true;
            break;
          case 'app.started.read':
            actual = started;
            break;
          case 'manifest':
            actual = {
              'version': interfaceVersion,
              'interfaces': [...interfaces, ...operations.keys],
              'prepared': _prepared,
              'started': started,
            };
            break;
          default:
            final handler = operations[id];
            if (handler == null) throw ArgumentError('Unknown QA interface');
            if (_prepared) {
              throw StateError(
                'Case fixture cannot reuse contract preparation',
              );
            }
            actual = await handler(parameters, _resume.isCompleted || started);
        }
        response.write(
          jsonEncode({
            'requestId': data['requestId'],
            'buildId': buildId,
            'resource': resource,
            'interface': id,
            'actual': actual,
          }),
        );
      } finally {
        _busy = false;
      }
    } catch (e) {
      response.statusCode = HttpStatus.badRequest;
      response.write(jsonEncode({'error': e.toString()}));
    } finally {
      await response.close();
    }
  }
}
