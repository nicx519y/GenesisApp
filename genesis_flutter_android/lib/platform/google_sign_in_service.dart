import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  GoogleSignInService._();
  static const MethodChannel _deviceChannel = MethodChannel('com.genesis.ai/device');

  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '314141017139-qelkem0r1i1dnj1u3fg9e71fl5iotb2t.apps.googleusercontent.com',
  );
  static Future<void>? _initializeFuture;

  static Future<void> _ensureInitialized() {
    final pending = _initializeFuture;
    if (pending != null) return pending;
    final init = GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );
    _initializeFuture = init;
    return init;
  }

  static Future<String> signInAndGetIdToken() async {
    debugPrint('[Auth][GoogleSignInService] signInAndGetIdToken start');
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint('[Auth][GoogleSignInService] unsupported platform');
      throw const _GoogleSignInFailure('当前平台不支持 Google 登录');
    }
    if (_serverClientId.trim().isEmpty) {
      debugPrint('[Auth][GoogleSignInService] missing GOOGLE_SERVER_CLIENT_ID');
      throw const _GoogleSignInFailure(
        '缺少 GOOGLE_SERVER_CLIENT_ID 配置，请在运行参数中传入 --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com',
      );
    }
    await _printAndroidSignInDiagnostics();

    debugPrint('[Auth][GoogleSignInService] initializing GoogleSignIn');
    await _ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      debugPrint(
        '[Auth][GoogleSignInService] GoogleSignIn does not support authenticate on this client',
      );
      throw const _GoogleSignInFailure('当前端不支持直接拉起 Google 登录');
    }
    debugPrint('[Auth][GoogleSignInService] launching authenticate');
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const <String>['openid', 'email', 'profile'],
    );

    final idToken = account.authentication.idToken?.trim() ?? '';
    if (idToken.isEmpty) {
      debugPrint('[Auth][GoogleSignInService] idToken empty after authenticate');
      throw const _GoogleSignInFailure(
        'Google 未返回 idToken，请确认 OAuth Web Client ID 配置正确',
      );
    }
    debugPrint(
      '[Auth][GoogleSignInService] signInAndGetIdToken success length=${idToken.length}',
    );
    return idToken;
  }

  static Future<void> _printAndroidSignInDiagnostics() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final raw = await _deviceChannel.invokeMethod<Object>('getSignInDiagnostics');
      debugPrint('[Auth][GoogleSignInService] android signIn diagnostics: $raw');
    } catch (e) {
      debugPrint('[Auth][GoogleSignInService] diagnostics unavailable: $e');
    }
  }
}

class _GoogleSignInFailure implements Exception {
  const _GoogleSignInFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
