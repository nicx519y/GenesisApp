import '../../utils/entity_deleted.dart';
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

typedef UserMembershipLoader =
    Future<Map<String, dynamic>> Function(String uid);

/// Public target-user membership, independent of the signed-in user's wallet.
/// Unknown, failed, mismatched and deleted profiles never grant a badge.
class UserMembershipStatusStore extends ChangeNotifier {
  UserMembershipStatusStore({
    required this.loadUser,
    this.cacheDuration = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final UserMembershipLoader loadUser;
  final Duration cacheDuration;
  final DateTime Function() _now;
  final _entries = <String, _Entry>{};
  final _queue = Queue<String>();
  Timer? _timer;
  int _running = 0;
  int _generation = 0;
  bool _disposed = false;

  bool isActive(String uid) {
    final entry = _entries[uid.trim()];
    final checkedAt = entry?.checkedAt;
    return entry?.status == 1 &&
        checkedAt != null &&
        _now().difference(checkedAt) < cacheDuration;
  }

  void watch(String uid) {
    uid = uid.trim();
    if (uid.isEmpty || _disposed) return;
    final entry = _entries.putIfAbsent(uid, _Entry.new);
    entry.watchers++;
    _enqueue(uid);
    _timer ??= Timer.periodic(cacheDuration, (_) => refreshWatched());
  }

  void unwatch(String uid) {
    final entry = _entries[uid.trim()];
    if (entry != null && entry.watchers > 0) entry.watchers--;
    if (!_entries.values.any((e) => e.watchers > 0)) {
      _timer?.cancel();
      _timer = null;
    }
    if (_entries.length > 256) {
      final removable = _entries.keys.where((key) {
        final value = _entries[key]!;
        return value.watchers == 0 && !value.pending;
      }).toList();
      for (final key in removable.take(_entries.length - 256)) {
        _entries.remove(key);
      }
    }
  }

  void refreshWatched() {
    if (_disposed) return;
    for (final item in _entries.entries.toList()) {
      if (item.value.watchers > 0) _enqueue(item.key);
    }
  }

  void reset() {
    if (_disposed) return;
    _generation++;
    for (final entry in _entries.values) {
      entry.status = null;
      entry.checkedAt = null;
    }
    notifyListeners();
    refreshWatched();
  }

  void _enqueue(String uid) {
    final entry = _entries[uid]!;
    if (entry.pending || _disposed) return;
    final checkedAt = entry.checkedAt;
    if (checkedAt != null && _now().difference(checkedAt) < cacheDuration) {
      return;
    }
    entry.pending = true;
    _queue.add(uid);
    _drain();
  }

  void _drain() {
    while (!_disposed && _running < 4 && _queue.isNotEmpty) {
      final uid = _queue.removeFirst();
      _running++;
      unawaited(_load(uid));
    }
  }

  Future<void> _load(String uid) async {
    final generation = _generation;
    int? status;
    try {
      final response = await loadUser(uid);
      final user = response['user'];
      if (user is Map &&
          user['uid'] == uid &&
          !entityDeleted(user['deleted'])) {
        final value = user['membership_status'];
        if (value is int && const [0, 1, 2].contains(value)) status = value;
      }
    } catch (_) {
      // A failed lookup is unknown, not proof of membership.
    }
    if (_disposed) return;
    final entry = _entries[uid]!;
    entry.pending = false;
    _running--;
    if (generation == _generation) {
      entry.status = status;
      entry.checkedAt = _now();
      notifyListeners();
    } else if (entry.watchers > 0) {
      _enqueue(uid);
    }
    _drain();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _queue.clear();
    super.dispose();
  }
}

class _Entry {
  int watchers = 0;
  int? status;
  DateTime? checkedAt;
  bool pending = false;
}
