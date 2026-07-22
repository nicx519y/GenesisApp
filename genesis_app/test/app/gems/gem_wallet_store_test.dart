import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';

void main() {
  test('refresh publishes the exact server balance', () async {
    final store = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 980),
      readUid: () async => 'u_user',
    );
    addTearDown(store.dispose);

    await store.refresh();

    expect(store.state.value.ownerUid, 'u_user');
    expect(store.state.value.balance, 980);
    expect(store.state.value.isRefreshing, isFalse);
    expect(store.state.value.lastError, isNull);
  });

  test('failed refresh retains the last successful balance', () async {
    var shouldFail = false;
    final store = GemWalletStore(
      loadWallet: () async {
        if (shouldFail) throw StateError('offline');
        return const GemWallet(balance: 430);
      },
      readUid: () async => 'u_user',
    );
    addTearDown(store.dispose);

    await store.refresh();
    shouldFail = true;
    await store.refresh();

    expect(store.state.value.balance, 430);
    expect(store.state.value.lastError, isA<StateError>());
  });

  test('concurrent refresh calls share one wallet request', () async {
    var requestCount = 0;
    final response = Completer<GemWallet>();
    final store = GemWalletStore(
      loadWallet: () {
        requestCount += 1;
        return response.future;
      },
      readUid: () async => 'u_user',
    );
    addTearDown(store.dispose);

    final first = store.refresh();
    final second = store.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(requestCount, 1);
    response.complete(const GemWallet(balance: 980));
    await Future.wait<void>([first, second]);
    expect(store.state.value.balance, 980);
  });

  test('an old account response is ignored after reset', () async {
    var uid = 'u_first';
    final response = Completer<GemWallet>();
    final store = GemWalletStore(
      loadWallet: () => response.future,
      readUid: () async => uid,
    );
    addTearDown(store.dispose);

    final refresh = store.refresh();
    await Future<void>.delayed(Duration.zero);

    uid = 'u_second';
    store.reset();
    response.complete(const GemWallet(balance: 430));
    await refresh;

    expect(store.state.value.ownerUid, isNull);
    expect(store.state.value.balance, isNull);
  });

  test('refresh ignores an in-flight response after dispose', () async {
    final response = Completer<GemWallet>();
    final store = GemWalletStore(
      loadWallet: () => response.future,
      readUid: () async => 'u_user',
    );

    final refresh = store.refresh();
    await Future<void>.delayed(Duration.zero);
    store.dispose();
    response.complete(const GemWallet(balance: 980));

    await expectLater(refresh, completes);
    store.dispose();
  });

  test('refresh after dispose is a no-op', () async {
    final store = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 980),
      readUid: () async => 'u_user',
    );
    store.dispose();

    await expectLater(store.refresh(), completes);
  });
}
