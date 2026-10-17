import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The plugin's platform fake lets these tests exercise real persistence failures.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/network/models/miniphone_info.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_store.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_wallpaper_controller.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_memory_cache.dart';

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences() : super.empty();
  bool fail = false;
  bool returnFalse = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (fail) {
      if (returnFalse) return false;
      throw PlatformException(code: 'disk-unavailable');
    }
    return super.setValue(type, key, value);
  }
}

class _FailingSession extends MemoryUserSessionStore {
  bool fail = false;
  @override
  Future<String?> readUid() async {
    if (fail) throw PlatformException(code: 'account-unavailable');
    return super.readUid();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FailingPreferences prefs;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = _FailingPreferences();
    SharedPreferencesStorePlatform.instance = prefs;
  });

  for (final returnsFalse in [false, true]) {
    test(
      'journal failure ($returnsFalse) blocks send and preserves retry ID',
      () async {
        final b = PhoneBackend(), s = b.store();
        addTearDown(s.dispose);
        await s.ready;
        prefs
          ..returnFalse = returnsFalse
          ..fail = true;
        expect(await s.write('dm', 'c', 'Keep my draft'), isFalse);
        expect(b.calls('dm/send'), isEmpty);
        final request = s.pending['dm:c']!;
        expect(request.content, 'Keep my draft');
        expect(request.uncertain, isTrue);
        expect(s.errors['journal'], contains('save phone requests'));
        expect(s.busy, isNot(contains('dm:c')));
        await s.writesSaved;

        prefs.fail = false;
        expect(await s.write('dm', 'c', 'Keep my draft', retry: true), isTrue);
        expect(s.pending['dm:c']!.id, request.id);
        expect(b.calls('dm/send'), hasLength(1));
        expect(s.errors.containsKey('journal'), isFalse);
        await s.writesSaved;
      },
    );
  }

  test(
    'saving a rejected request cannot throw again from the catch block',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      b.respond = (r) {
        if (!r.uri.path.endsWith('/dm/send')) return null;
        prefs.fail = true;
        return {'err_no': 2061, 'err_msg': 'Permission denied', 'data': {}};
      };
      expect(await s.write('dm', 'c', 'Retain this'), isFalse);
      expect(s.errors['dm:c'], 'Permission denied');
      expect(s.errors['journal'], isNotNull);
      expect(s.pending['dm:c']!.rejected, isTrue);
      expect(s.pending['dm:c']!.content, 'Retain this');
      await s.writesSaved;
    },
  );

  test('journal failure does not interrupt reply recovery backoff', () async {
    final b = PhoneBackend(), s = b.store();
    addTearDown(s.dispose);
    await s.ready;
    await s.refreshSessions();
    final recoveredTwice = Completer<void>();
    b.respond = (r) {
      if (r.uri.path.endsWith('/messages') &&
          b.calls('messages').length >= 2 &&
          !recoveredTwice.isCompleted) {
        recoveredTwice.complete();
      }
      return null;
    };
    expect(await s.write('dm', 'c', 'Waiting'), isTrue);
    prefs.fail = true;
    await recoveredTwice.future.timeout(const Duration(seconds: 5));
    expect(s.errors['journal'], isNotNull);
    await s.writesSaved;
  });

  test(
    'identity failure settles both readiness futures and retries on resume',
    () async {
      final b = PhoneBackend();
      var fail = true;
      var reads = 0;
      final s = MiniPhoneStore(
        api: b.api,
        worldId: 'w',
        namespace: 'identity-regression',
        cacheStorage: MemoryMiniPhoneCacheStorage(),
        readUid: () async {
          reads++;
          if (fail) throw PlatformException(code: 'account-unavailable');
          return 'u';
        },
        loadWorld: () async => WorldDetail.fromJson({'name': 'World'}),
        accountRevision: b.revision,
      );
      addTearDown(s.dispose);
      await Future.wait([
        s.ready,
        s.localReady,
      ]).timeout(const Duration(seconds: 2));
      expect(s.errors['identity'], isNotNull);
      expect(b.requests, isEmpty);
      expect(await s.write('dm', 'c', 'Not signed in yet'), isFalse);

      fail = false;
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await s.retryInitialization();
      await s.localReady;
      expect(reads, 2);
      expect(s.uid, 'u');
      expect(s.errors.containsKey('identity'), isFalse);
      expect(b.calls('home'), isNotEmpty);
    },
  );

  test(
    'wallpaper identity failures preserve draft and remain retryable',
    () async {
      final session = _FailingSession();
      await session.saveUid('u');
      var saves = 0;
      final controller = MiniPhoneWallpaperController(
        worldId: 'w',
        sessionStore: session,
        load: () async => const MiniphoneInfo(
          backgroundImage: 'https://cdn.example/old.png',
          wallpapers: [],
        ),
        save: (_) async {
          saves++;
        },
        upload: (_, _) async => 'https://cdn.example/upload.png',
      );
      addTearDown(controller.dispose);
      session.fail = true;
      await controller.refresh();
      expect(controller.loadError, contains('account'));
      session.fail = false;
      await controller.refresh();
      controller.select('https://cdn.example/new.png');
      session.fail = true;
      await controller.refresh();
      expect(await controller.apply(), isFalse);
      expect(controller.draftImage, 'https://cdn.example/new.png');
      expect(controller.backgroundImage, 'https://cdn.example/old.png');
      expect(saves, 0);
      expect(controller.saving, isFalse);
      session.fail = false;
      expect(await controller.apply(), isTrue);
      expect(saves, 1);
      expect(controller.loadError, isNull);
    },
  );
}
