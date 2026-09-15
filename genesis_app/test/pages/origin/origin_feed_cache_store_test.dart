import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/origin/origin_feed_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('remembers the displayed gender separately for each owner', () async {
    const guest = OriginFeedCacheStore();
    const alice = OriginFeedCacheStore(ownerUid: 'u_alice');
    const bob = OriginFeedCacheStore(ownerUid: 'u_bob');
    expect(await guest.loadLastConfirmedGender(), isNull);
    await guest.saveLastConfirmedGender('Male');
    await alice.saveLastConfirmedGender('Female');
    expect(
      await const OriginFeedCacheStore().loadLastConfirmedGender(),
      'Male',
    );
    expect(await alice.loadLastConfirmedGender(), 'Female');
    expect(await bob.loadLastConfirmedGender(), isNull);
    await alice.saveLastConfirmedGender(null);
    expect(await alice.loadLastConfirmedGender(), '');
    expect(await guest.loadLastConfirmedGender(), 'Male');
    await alice.saveLastConfirmedGender('Non_binary');
    expect(await alice.loadLastConfirmedGender(), 'Non_binary');
  });

  test('ignores an invalid cached gender', () async {
    const store = OriginFeedCacheStore(ownerUid: 'u_alice');
    for (final value in <Object>['Unknown', 3]) {
      SharedPreferences.setMockInitialValues({
        'origin_feed_gender_v1.u_alice': value,
      });
      expect(await store.loadLastConfirmedGender(), isNull);
    }
  });

  test(
    'manual choice is persistent and separate from the automatic hint',
    () async {
      const alice = OriginFeedCacheStore(ownerUid: 'u_alice');
      const bob = OriginFeedCacheStore(ownerUid: 'u_bob');
      const guest = OriginFeedCacheStore();
      await alice.saveLastConfirmedGender('Male');
      expect(await alice.loadManualGender(), isNull);
      for (final gender in ['', 'Male', 'Female', 'Non_binary']) {
        await alice.saveManualGender(gender);
        await alice.saveLastConfirmedGender('Female');
        expect(
          await const OriginFeedCacheStore(
            ownerUid: 'u_alice',
          ).loadManualGender(),
          gender,
        );
        expect(await bob.loadManualGender(), isNull);
        expect(await guest.loadManualGender(), isNull);
      }
      await guest.saveManualGender('');
      expect(await const OriginFeedCacheStore().loadManualGender(), '');
    },
  );

  test('invalid manual choice does not override automatic targeting', () async {
    SharedPreferences.setMockInitialValues({
      'origin_feed_manual_gender_v1.u_alice': 'invalid',
    });
    expect(
      await const OriginFeedCacheStore(ownerUid: 'u_alice').loadManualGender(),
      isNull,
    );
  });

  test('stores For you first page per owner', () async {
    const aliceStore = OriginFeedCacheStore(ownerUid: 'u_alice');
    const bobStore = OriginFeedCacheStore(ownerUid: 'u_bob');

    await aliceStore.saveForYouFirstPage(<String, dynamic>{
      'list': <Map<String, Object?>>[
        <String, Object?>{'oid': 'o_alice'},
      ],
      'rn': 10,
      'next_score': 10,
      'has_more': true,
    });
    await bobStore.saveForYouFirstPage(<String, dynamic>{
      'list': <Map<String, Object?>>[
        <String, Object?>{'oid': 'o_bob'},
      ],
      'rn': 10,
      'next_score': 20,
      'has_more': false,
    });

    expect(
      ((await aliceStore.loadForYouFirstPage())!['list'] as List).first['oid'],
      'o_alice',
    );
    expect(
      ((await bobStore.loadForYouFirstPage())!['list'] as List).first['oid'],
      'o_bob',
    );
  });

  test('uses an anonymous owner for an empty uid', () async {
    const emptyOwnerStore = OriginFeedCacheStore();
    const anonymousStore = OriginFeedCacheStore(
      ownerUid: OriginFeedCacheStore.anonymousOwnerUid,
    );

    await emptyOwnerStore.saveForYouFirstPage(<String, dynamic>{
      'list': <Map<String, Object?>>[
        <String, Object?>{'oid': 'o_guest'},
      ],
      'rn': 10,
      'next_score': 10,
      'has_more': false,
    });

    expect(
      ((await anonymousStore.loadForYouFirstPage())!['list'] as List)
          .first['oid'],
      'o_guest',
    );
  });

  test(
    'separates gender-filtered pages from each other and old caches',
    () async {
      const unfiltered = OriginFeedCacheStore(ownerUid: 'u_alice');
      const male = OriginFeedCacheStore(ownerUid: 'u_alice', gender: 'Male');
      const female = OriginFeedCacheStore(
        ownerUid: 'u_alice',
        gender: 'Female',
      );
      await unfiltered.saveForYouFirstPage({'next_score': 10});
      expect(await male.loadForYouFirstPage(), isNull);
      expect(await female.loadForYouFirstPage(), isNull);

      await male.saveForYouFirstPage({'next_score': 20});
      await female.saveForYouFirstPage({'next_score': 30});
      expect((await unfiltered.loadForYouFirstPage())!['next_score'], 10);
      expect((await male.loadForYouFirstPage())!['next_score'], 20);
      expect((await female.loadForYouFirstPage())!['next_score'], 30);
    },
  );

  test('returns null for invalid cached json', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      '${OriginFeedCacheStore.storageKey}.u_alice.foryou.page_1': 'not json',
    });
    const store = OriginFeedCacheStore(ownerUid: 'u_alice');

    expect(await store.loadForYouFirstPage(), isNull);
  });

  test('does not read the legacy page-number cache key', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'origin_feed_cache_v1.u_alice.foryou.page_1': '{"list":[]}',
    });
    const store = OriginFeedCacheStore(ownerUid: 'u_alice');

    expect(await store.loadForYouFirstPage(), isNull);
  });
}
