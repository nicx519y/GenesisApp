import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_store.dart';

import 'mini_phone_chat_backend.dart';
import 'mini_phone_memory_cache.dart';

/// Entry fixtures use the same observable data source as a live World.
class TestMiniPhoneUnreadStore extends MiniPhoneStore {
  TestMiniPhoneUnreadStore() : this._(PhoneBackend());

  TestMiniPhoneUnreadStore._(PhoneBackend backend)
    : _backend = backend,
      super(
        api: backend.api,
        worldId: 'w',
        namespace: 'entry-test',
        readUid: () async => null,
        loadWorld: () async => WorldDetail.fromJson({}),
        accountRevision: backend.revision,
        cacheStorage: MemoryMiniPhoneCacheStorage(),
      );

  final PhoneBackend _backend;

  @override
  void dispose() {
    super.dispose();
    _backend.revision.dispose();
  }
}
