import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_store.dart';

import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_memory_cache.dart';

class _WorldSocketSnapshot implements WorldChatroomService {
  _WorldSocketSnapshot(bool connected)
    : state = WorldChatroomState(connected: connected, joining: true);

  @override
  final WorldChatroomState state;
  @override
  bool get isDisposed => false;
  @override
  Stream<ChatroomPhoneEvent> get phoneEvents => const Stream.empty();
  @override
  Stream<WorldChatroomState> get states => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected World socket operation: ${invocation.memberName}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final hasNetwork in [false, true]) {
    for (final connected in [false, true]) {
      test(
        'DM reads system network before socket network=$hasNetwork connected=$connected',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          addTearDown(() {
            debugDefaultTargetPlatformOverride = null;
            messenger.setMockMethodCallHandler(
              GenesisMethodChannels.device,
              null,
            );
          });
          final checks = <String>[];
          messenger.setMockMethodCallHandler(GenesisMethodChannels.device, (
            call,
          ) async {
            expect(call.method, GenesisMethodChannels.getNetworkAvailability);
            checks.add('network');
            return hasNetwork;
          });
          final backend = PhoneBackend();
          final store = MiniPhoneStore(
            api: backend.api,
            worldId: 'w',
            namespace: 'native-order-$hasNetwork-$connected',
            cacheStorage: MemoryMiniPhoneCacheStorage(),
            readUid: () async => 'u',
            loadWorld: () async => WorldDetail.fromJson({'world_id': 'w'}),
            accountRevision: backend.revision,
            chatConnectionReady: () {
              checks.add('socket');
              return connected;
            },
          );
          addTearDown(store.dispose);
          await store.ready;
          expect(
            await store.write('dm', 'c', 'Keep original draft'),
            hasNetwork && connected,
          );
          expect(checks, hasNetwork ? ['network', 'socket'] : ['network']);
          expect(
            store.errors['dm:c'],
            !hasNetwork
                ? 'Network unavailable. Check network.'
                : !connected
                ? 'Could not connect to this chat'
                : null,
          );
          expect(
            backend.calls('dm/send'),
            hasLength(hasNetwork && connected ? 1 : 0),
          );
          if (!hasNetwork || !connected) {
            expect(store.pending, isEmpty);
            expect(store.outgoingDm('c'), isEmpty);
          }
        },
      );
    }
  }

  for (final connected in [false, true]) {
    test(
      'DM uses the attached World socket connected=$connected without joining',
      () async {
        final backend = PhoneBackend();
        final store = MiniPhoneStore(
          api: backend.api,
          worldId: 'w',
          namespace: 'attached-world-$connected',
          cacheStorage: MemoryMiniPhoneCacheStorage(),
          readUid: () async => 'u',
          loadWorld: () async => WorldDetail.fromJson({'world_id': 'w'}),
          accountRevision: backend.revision,
          networkAvailabilityCheck: () async => true,
        );
        addTearDown(store.dispose);
        await store.ready;
        store.attach(_WorldSocketSnapshot(connected));
        expect(await store.write('dm', 'c', 'Hello'), connected);
        expect(backend.calls('dm/send'), hasLength(connected ? 1 : 0));
        expect(
          store.errors['dm:c'],
          connected ? isNull : 'Could not connect to this chat',
        );
      },
    );
  }

  test(
    'DM network preflight blocks duplicate sends until it completes',
    () async {
      final backend = PhoneBackend();
      final network = Completer<bool>();
      var checks = 0;
      final store = backend.store(
        networkAvailabilityCheck: () {
          checks++;
          return network.future;
        },
      );
      addTearDown(store.dispose);
      await store.ready;
      final first = store.write('dm', 'c', 'First draft');
      await Future<void>.delayed(Duration.zero);
      expect(store.busy, contains('dm:c'));
      expect(await store.write('dm', 'c', 'Duplicate draft'), isFalse);
      expect(checks, 1);
      network.complete(false);
      expect(await first, isFalse);
      expect(store.errors['dm:c'], 'Network unavailable. Check network.');
      expect(store.busy, isNot(contains('dm:c')));
      expect(store.pending, isEmpty);
      expect(backend.calls('dm/send'), isEmpty);
    },
  );

  test('account change discards a late DM preflight result', () async {
    final backend = PhoneBackend();
    final network = Completer<bool>();
    final store = backend.store(networkAvailabilityCheck: () => network.future);
    addTearDown(store.dispose);
    await store.ready;
    final first = store.write('dm', 'c', 'Old account draft');
    await Future<void>.delayed(Duration.zero);
    backend.uid = 'replacement-user';
    backend.revision.value++;
    await store.ready;
    network.complete(false);
    expect(await first, isFalse);
    expect(store.errors['dm:c'], isNull);
    expect(store.busy, isNot(contains('dm:c')));
    expect(store.pending, isEmpty);
    expect(backend.calls('dm/send'), isEmpty);
  });
}
