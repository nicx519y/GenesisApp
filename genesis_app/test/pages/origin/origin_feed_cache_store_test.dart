import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/origin/origin_feed_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores For you first page per owner', () async {
    const aliceStore = OriginFeedCacheStore(ownerUid: 'u_alice');
    const bobStore = OriginFeedCacheStore(ownerUid: 'u_bob');

    await aliceStore.saveForYouFirstPage(<String, dynamic>{
      'list': <Map<String, Object?>>[
        <String, Object?>{'oid': 'o_alice'},
      ],
      'total': 1,
    });
    await bobStore.saveForYouFirstPage(<String, dynamic>{
      'list': <Map<String, Object?>>[
        <String, Object?>{'oid': 'o_bob'},
      ],
      'total': 1,
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
      'total': 1,
    });

    expect(
      ((await anonymousStore.loadForYouFirstPage())!['list'] as List)
          .first['oid'],
      'o_guest',
    );
  });

  test('returns null for invalid cached json', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      '${OriginFeedCacheStore.storageKey}.u_alice.foryou.page_1': 'not json',
    });
    const store = OriginFeedCacheStore(ownerUid: 'u_alice');

    expect(await store.loadForYouFirstPage(), isNull);
  });
}
