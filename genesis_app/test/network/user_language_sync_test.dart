import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/v1/user_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'login fetches current-account language and logout preserves it',
    () async {
      final languages = AppLanguageController();
      final paths = <String>[];
      final api = GenesisApi(
        sessionStore: MemoryUserSessionStore(),
        languageController: languages,
        appHeaderProvider: () async => {
          'x-setting-language': languages.settingLanguage ?? 'en-US',
        },
        transport: _Transport((request) async {
          paths.add(request.uri.path);
          if (request.uri.path.endsWith('/user/oauth/google')) {
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body:
                  '{"err_no":0,"err_msg":"succ","data":{"token":"token","user":{"uid":"me"}}}',
            );
          }
          if (request.uri.path.endsWith('/user/info')) return _profile('zh_TW');
          if (request.uri.path.endsWith('/user/logout')) {
            expect(request.headers['x-setting-language'], 'zh_TW');
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body: '{"err_no":0,"err_msg":"succ","data":{}}',
            );
          }
          throw StateError('Unexpected request');
        }),
      );
      await api.loginWithGoogle(idToken: 'provider-token');
      expect(paths.map((path) => path.split('/').last), ['google', 'info']);
      expect(languages.settingLanguage, 'zh_TW');
      await api.logout();
      expect(languages.settingLanguage, 'zh_TW');
    },
  );

  for (final language in ['en', '', 'zh_TW']) {
    test('current user info applies nonempty language: $language', () async {
      final languages = AppLanguageController();
      languages.applyConfigLanguage(
        'zh_TW',
        requestRevision: languages.revision,
      );
      final api = UserV1Api(
        ApiClient(
          baseUrl: 'https://example.test/api/',
          transport: _Transport((_) async => _profile(language)),
        ),
        currentUserInfoSessionProvider: () async =>
            (uid: 'me', authToken: 'token'),
        languageController: languages,
      );
      await api.info();
      expect(languages.settingLanguage, language.isEmpty ? 'zh_TW' : language);
    });
  }

  test('other user language does not change local setting', () async {
    final languages = AppLanguageController();
    languages.applyConfigLanguage('en', requestRevision: languages.revision);
    final api = UserV1Api(
      ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _Transport(
          (_) async => _profile('zh_TW', uid: 'other', isSelf: false),
        ),
      ),
      currentUserInfoSessionProvider: () async =>
          (uid: 'me', authToken: 'token'),
      languageController: languages,
    );
    await api.info(uid: 'other');
    expect(languages.settingLanguage, 'en');
  });

  test('logout during profile fetch preserves current language', () async {
    final languages = AppLanguageController();
    languages.applyConfigLanguage('en', requestRevision: languages.revision);
    CurrentUserInfoSession? session = (uid: 'me', authToken: 'token');
    final response = Completer<TransportResponse>();
    final sent = Completer<void>();
    final api = UserV1Api(
      ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _Transport((_) {
          sent.complete();
          return response.future;
        }),
      ),
      currentUserInfoSessionProvider: () async => session,
      languageController: languages,
    );
    final fetch = api.info();
    await sent.future;
    session = null;
    response.complete(_profile('zh_TW'));
    await fetch;
    expect(languages.settingLanguage, 'en');
  });

  test(
    'profile started during manual save cannot overwrite saved language',
    () async {
      final languages = AppLanguageController();
      languages.applyConfigLanguage('en', requestRevision: languages.revision);
      final saved = Completer<void>();
      final switching = languages.select(
        const Locale('zh', 'TW'),
        saveLanguage: (_) => saved.future,
      );
      final response = Completer<TransportResponse>();
      final sent = Completer<void>();
      final api = UserV1Api(
        ApiClient(
          baseUrl: 'https://example.test/api/',
          transport: _Transport((_) {
            sent.complete();
            return response.future;
          }),
        ),
        currentUserInfoSessionProvider: () async =>
            (uid: 'me', authToken: 'token'),
        languageController: languages,
      );
      final fetch = api.info();
      await sent.future;
      saved.complete();
      await switching;
      response.complete(_profile('en'));
      await fetch;
      expect(languages.settingLanguage, 'zh_TW');
    },
  );
}

TransportResponse _profile(
  String language, {
  String uid = 'me',
  bool isSelf = true,
}) => TransportResponse(
  statusCode: 200,
  headers: const {'content-type': 'application/json'},
  body: jsonEncode({
    'err_no': 0,
    'err_msg': 'succ',
    'data': {
      'user': {'uid': uid, 'language': language},
      'relation': {'is_self': isSelf},
    },
  }),
);

class _Transport implements HttpTransport {
  const _Transport(this.callback);
  final Future<TransportResponse> Function(TransportRequest) callback;
  @override
  Future<TransportResponse> send(TransportRequest request) => callback(request);
}
