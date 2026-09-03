import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/startup/initial_landing_page_resolver.dart';
import 'package:genesis_flutter_android/pages/origin/origin_feed_cache_store.dart';

void main() {
  test(
    'signed-out launch opens Worldo and reports anonymous cache hit',
    () async {
      String? worldoOwnerUid;

      final decision = await resolveInitialLandingPage(
        loadSession: () async => null,
        loadHomeCache: (_) async => throw StateError('must not load Home'),
        loadWorldoCache: (ownerUid) async {
          worldoOwnerUid = ownerUid;
          return <String, dynamic>{'list': <Object>[]};
        },
      );

      expect(decision.index, 1);
      expect(decision.page, 'worldo');
      expect(decision.reason, 'no_session_worldo_cache_hit');
      expect(worldoOwnerUid, OriginFeedCacheStore.anonymousOwnerUid);
    },
  );

  test('signed-out launch reports Worldo cache miss', () async {
    final decision = await resolveInitialLandingPage(
      loadSession: () async => null,
      loadHomeCache: (_) async => null,
      loadWorldoCache: (_) async => null,
    );

    expect(decision.index, 1);
    expect(decision.page, 'worldo');
    expect(decision.reason, 'no_session_worldo_cache_miss');
  });

  test('signed-in launch with My Worlds content opens Home', () async {
    final decision = await resolveInitialLandingPage(
      loadSession: () async => (uid: 'u_1', authToken: 'token'),
      loadHomeCache: (ownerUid) async {
        expect(ownerUid, 'u_1');
        return <String, dynamic>{
          'list': <Object>['world'],
        };
      },
      loadWorldoCache: (_) async => null,
    );

    expect(decision.index, 0);
    expect(decision.page, 'home');
    expect(decision.reason, 'session_home_cache_hit');
  });

  test('signed-in launch accepts positive string Home total', () async {
    final decision = await resolveInitialLandingPage(
      loadSession: () async => (uid: 'u_1', authToken: 'token'),
      loadHomeCache: (_) async => <String, dynamic>{
        'list': <Object>[],
        'total': '2',
      },
      loadWorldoCache: (_) async => null,
    );

    expect(decision.index, 0);
    expect(decision.reason, 'session_home_cache_hit');
  });

  test(
    'signed-in launch falls back to cached Worldo when Home is empty',
    () async {
      final decision = await resolveInitialLandingPage(
        loadSession: () async => (uid: 'u_1', authToken: 'token'),
        loadHomeCache: (_) async => <String, dynamic>{
          'list': <Object>[],
          'total': 0,
        },
        loadWorldoCache: (ownerUid) async {
          expect(ownerUid, 'u_1');
          return <String, dynamic>{'list': <Object>[]};
        },
      );

      expect(decision.index, 1);
      expect(decision.page, 'worldo');
      expect(decision.reason, 'session_home_miss_worldo_cache_hit');
    },
  );

  test('signed-in launch reports all caches missing', () async {
    final decision = await resolveInitialLandingPage(
      loadSession: () async => (uid: 'u_1', authToken: 'token'),
      loadHomeCache: (_) async => null,
      loadWorldoCache: (_) async => null,
    );

    expect(decision.index, 1);
    expect(decision.page, 'worldo');
    expect(decision.reason, 'session_all_cache_miss');
  });

  test('session failure opens Worldo without reading caches', () async {
    var cacheLoads = 0;

    final decision = await resolveInitialLandingPage(
      loadSession: () async => throw StateError('session unavailable'),
      loadHomeCache: (_) async {
        cacheLoads += 1;
        return null;
      },
      loadWorldoCache: (_) async {
        cacheLoads += 1;
        return null;
      },
    );

    expect(decision.index, 1);
    expect(decision.page, 'worldo');
    expect(decision.reason, 'session_error');
    expect(cacheLoads, 0);
  });

  test('cache timeout is treated as a cache miss', () async {
    final decision = await resolveInitialLandingPage(
      loadSession: () async => (uid: 'u_1', authToken: 'token'),
      loadHomeCache: (_) => Future<Map<String, dynamic>?>.delayed(
        const Duration(milliseconds: 20),
        () => <String, dynamic>{'total': 1},
      ),
      loadWorldoCache: (_) async => null,
      timeout: const Duration(milliseconds: 1),
    );

    expect(decision.index, 1);
    expect(decision.reason, 'session_all_cache_miss');
  });
}
