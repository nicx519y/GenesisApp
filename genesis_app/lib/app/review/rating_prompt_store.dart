import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Local, per-identity eligibility. Only acknowledged user messages are recorded.
class RatingPromptStore {
  static final instance = RatingPromptStore();
  final changes = ValueNotifier<int>(0);
  Future<void>? _queue;
  static String key(String owner) => 'rating_prompt_v1:$owner';
  static String rewardClaimedKey(String owner) =>
      'rating_reward_claimed_v1:$owner';

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = (_queue ?? Future<void>.value()).then((_) => work());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _queue = tail;
    return result.whenComplete(() {
      if (identical(_queue, tail)) _queue = null;
    });
  }

  Map<String, dynamic> _read(SharedPreferences prefs, String owner) {
    final raw = prefs.getString(key(owner));
    if (raw == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _save(
    SharedPreferences prefs,
    String owner,
    Map<String, dynamic> state,
  ) async {
    if (!await prefs.setString(key(owner), jsonEncode(state))) {
      throw StateError('Rating prompt state could not be saved');
    }
  }

  Future<void> recordMessage({
    required Future<String> owner,
    required int threshold,
    required String messageId,
  }) {
    if (threshold <= 0 || messageId.isEmpty) return Future<void>.value();
    // Enqueue before awaiting identity/storage so page-exit checks cannot overtake it.
    return _serial(() async {
      final id = await owner;
      if (id.trim().isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final state = _read(prefs, id);
      if (state['shown'] == true || state['pending'] == true) return;
      final seen = List<String>.from(state['messages'] as List? ?? const []);
      if (seen.contains(messageId)) return;
      seen.add(messageId);
      state['messages'] = seen;
      state['count'] = (state['count'] as int? ?? 0) + 1;
      if ((state['count'] as int) >= threshold) state['pending'] = true;
      await _save(prefs, id, state);
      changes.value++;
    });
  }

  Future<bool> takePending(String owner, int threshold) => _serial(() async {
    if (threshold <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final state = _read(prefs, owner);
    if (state['shown'] == true ||
        (state['pending'] != true &&
            (state['count'] as int? ?? 0) < threshold)) {
      return false;
    }
    state['shown'] = true;
    state['pending'] = false;
    // No further counting after presentation; discard the deduplication history.
    state.remove('messages');
    await _save(prefs, owner, state);
    return true;
  });

  /// Debug-only caller: restart automatic eligibility for this identity only.
  Future<void> reset(String owner) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(key(owner))) {
      throw StateError('Rating prompt state could not be reset');
    }
    if (!await prefs.remove(rewardClaimedKey(owner))) {
      throw StateError('Rating reward display state could not be reset');
    }
  });

  Future<void> restorePending(String owner) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final state = _read(prefs, owner);
    // A debug reset may have invalidated an earlier presentation reservation.
    if (state['shown'] != true) return;
    state['shown'] = false;
    state['pending'] = true;
    await _save(prefs, owner, state);
  });
}
