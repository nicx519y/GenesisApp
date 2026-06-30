import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/home/home_feed_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores feed cache per uid and feed kind', () async {
    const aliceStore = HomeFeedCacheStore(ownerUid: 'u_alice');
    const bobStore = HomeFeedCacheStore(ownerUid: 'u_bob');

    await aliceStore.save(HomeFeedCacheKind.myWorlds, <String, dynamic>{
      'list': <Map<String, Object>>[
        <String, Object>{'wid': 'w_alice'},
      ],
      'total': 1,
    });
    await aliceStore.save(HomeFeedCacheKind.popular, <String, dynamic>{
      'list': <Map<String, Object>>[
        <String, Object>{'oid': 'o_alice'},
      ],
      'total': 1,
    });
    await bobStore.save(HomeFeedCacheKind.myWorlds, <String, dynamic>{
      'list': <Map<String, Object>>[
        <String, Object>{'wid': 'w_bob'},
      ],
      'total': 1,
    });

    expect(
      ((await aliceStore.load(HomeFeedCacheKind.myWorlds))!['list'] as List)
          .first['wid'],
      'w_alice',
    );
    expect(
      ((await aliceStore.load(HomeFeedCacheKind.popular))!['list'] as List)
          .first['oid'],
      'o_alice',
    );
    expect(
      ((await bobStore.load(HomeFeedCacheKind.myWorlds))!['list'] as List)
          .first['wid'],
      'w_bob',
    );
  });

  test('uses anonymous owner for empty uid', () async {
    const emptyOwnerStore = HomeFeedCacheStore();
    const anonymousStore = HomeFeedCacheStore(
      ownerUid: HomeFeedCacheStore.anonymousOwnerUid,
    );

    await emptyOwnerStore.save(HomeFeedCacheKind.popular, <String, dynamic>{
      'list': <Map<String, Object>>[
        <String, Object>{'oid': 'o_guest'},
      ],
      'total': 1,
    });

    expect(
      ((await anonymousStore.load(HomeFeedCacheKind.popular))!['list'] as List)
          .first['oid'],
      'o_guest',
    );
  });

  test('returns null for invalid cached json', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      '${HomeFeedCacheStore.storageKey}.u_alice.popular': 'not json',
    });
    const store = HomeFeedCacheStore(ownerUid: 'u_alice');

    expect(await store.load(HomeFeedCacheKind.popular), isNull);
  });
}
