import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/user_membership_status_store.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
Map<String, dynamic> profile(String uid, Object? status, {Object? deleted}) => {
  'user': {'uid': uid, 'membership_status': status, 'deleted': deleted},
};

void main() {
  test('only a matching active target profile grants membership', () async {
    final responses = <String, Map<String, dynamic>>{
      'active': profile('active', 1),
      'never': profile('never', 0),
      'expired': profile('expired', 2),
      'missing': profile('missing', null),
      'string': profile('string', '1'),
      'mismatch': profile('another', 1),
      'deleted': profile('deleted', 1, deleted: true),
    };
    final store = UserMembershipStatusStore(
      loadUser: (uid) async => responses[uid]!,
    );
    addTearDown(store.dispose);
    for (final uid in responses.keys) {
      store.watch(uid);
    }
    await flush();
    for (final uid in responses.keys) {
      expect(store.isActive(uid), uid == 'active', reason: uid);
    }
  });

  test(
    'duplicate names in different places share one UID lookup and cache',
    () async {
      int requests = 0;
      final response = Completer<Map<String, dynamic>>();
      final store = UserMembershipStatusStore(
        loadUser: (_) {
          requests++;
          return response.future;
        },
      );
      addTearDown(store.dispose);
      store.watch('u');
      store.watch('u');
      expect(requests, 1);
      expect(store.isActive('u'), isFalse);
      response.complete(profile('u', 1));
      await flush();
      store.unwatch('u');
      store.unwatch('u');
      store.watch('u');
      expect(requests, 1);
      expect(store.isActive('u'), isTrue);
    },
  );

  test(
    'cache expiry refreshes membership; failure hides a previously active badge',
    () async {
      var now = DateTime(2026);
      Object? status = 1;
      bool fail = false;
      final store = UserMembershipStatusStore(
        now: () => now,
        loadUser: (uid) async {
          if (fail) throw StateError('offline');
          return profile(uid, status);
        },
      );
      addTearDown(store.dispose);
      store.watch('u');
      await flush();
      expect(store.isActive('u'), isTrue);
      now = now.add(const Duration(seconds: 31));
      expect(store.isActive('u'), isFalse);
      status = 2;
      store.refreshWatched();
      await flush();
      expect(store.isActive('u'), isFalse);
      now = now.add(const Duration(seconds: 31));
      status = 1;
      store.refreshWatched();
      await flush();
      expect(store.isActive('u'), isTrue);
      now = now.add(const Duration(seconds: 31));
      fail = true;
      store.refreshWatched();
      await flush();
      expect(store.isActive('u'), isFalse);
    },
  );

  test(
    'session reset rejects late responses and checks the target again',
    () async {
      final calls = <Completer<Map<String, dynamic>>>[];
      final store = UserMembershipStatusStore(
        loadUser: (_) {
          final pending = Completer<Map<String, dynamic>>();
          calls.add(pending);
          return pending.future;
        },
      );
      addTearDown(store.dispose);
      store.watch('u');
      store.reset();
      calls.first.complete(profile('u', 1));
      await flush();
      expect(store.isActive('u'), isFalse);
      expect(calls.length, 2);
      calls.last.complete(profile('u', 2));
      await flush();
      expect(store.isActive('u'), isFalse);
    },
  );

  test(
    'limits concurrent requests and ignores responses after disposal',
    () async {
      final calls = <String, Completer<Map<String, dynamic>>>{};
      final store = UserMembershipStatusStore(
        loadUser: (uid) {
          final pending = Completer<Map<String, dynamic>>();
          calls[uid] = pending;
          return pending.future;
        },
      );
      for (var i = 0; i < 8; i++) {
        store.watch('$i');
      }
      expect(calls.length, 4);
      calls['0']!.complete(profile('0', 1));
      await flush();
      expect(calls.length, 5);
      store.dispose();
      for (final entry in calls.entries) {
        if (!entry.value.isCompleted) {
          entry.value.complete(profile(entry.key, 1));
        }
      }
      await flush();
      expect(calls.length, 5);
    },
  );
}
