import 'package:flutter/foundation.dart';

import '../../network/models/gem_wallet.dart';

typedef GemWalletLoader = Future<GemWallet> Function();
typedef GemWalletUidReader = Future<String?> Function();

@immutable
class GemWalletState {
  const GemWalletState({
    this.ownerUid,
    this.balance,
    this.isRefreshing = false,
    this.updatedAt,
    this.lastError,
  });

  final String? ownerUid;
  final int? balance;
  final bool isRefreshing;
  final DateTime? updatedAt;
  final Object? lastError;

  bool get hasWalletBalance => balance != null;
}

class GemWalletStore {
  GemWalletStore({required this.loadWallet, required this.readUid});

  final GemWalletLoader loadWallet;
  final GemWalletUidReader readUid;
  final ValueNotifier<GemWalletState> _state = ValueNotifier<GemWalletState>(
    const GemWalletState(),
  );

  ValueListenable<GemWalletState> get state => _state;

  int _requestGeneration = 0;

  Future<void> refresh() async {
    final uid = await _readCurrentUid();
    if (uid.isEmpty || uid.startsWith('guest_')) {
      reset();
      return;
    }

    final requestGeneration = ++_requestGeneration;
    final current = _state.value;
    final retainedBalance = current.ownerUid == uid ? current.balance : null;
    final retainedUpdatedAt = current.ownerUid == uid
        ? current.updatedAt
        : null;
    _state.value = GemWalletState(
      ownerUid: uid,
      balance: retainedBalance,
      isRefreshing: true,
      updatedAt: retainedUpdatedAt,
    );

    try {
      final wallet = await loadWallet();
      final currentUid = await _readCurrentUid();
      if (requestGeneration != _requestGeneration) return;
      if (currentUid != uid) {
        reset();
        return;
      }
      _state.value = GemWalletState(
        ownerUid: uid,
        balance: wallet.balance,
        updatedAt: DateTime.now(),
      );
    } catch (error) {
      if (requestGeneration != _requestGeneration) return;
      final currentUid = await _readCurrentUid();
      if (requestGeneration != _requestGeneration) return;
      if (currentUid != uid) {
        reset();
        return;
      }
      _state.value = GemWalletState(
        ownerUid: uid,
        balance: retainedBalance,
        updatedAt: retainedUpdatedAt,
        lastError: error,
      );
    }
  }

  Future<void> refreshAfterEntitlementGranted() => refresh();

  void reset() {
    _requestGeneration += 1;
    _state.value = const GemWalletState();
  }

  void dispose() {
    _requestGeneration += 1;
    _state.dispose();
  }

  Future<String> _readCurrentUid() async {
    try {
      return (await readUid())?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }
}
