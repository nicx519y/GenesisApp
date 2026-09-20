part of 'world_chatroom_service.dart';

Object locationMessageRetentionKey(WorldChatroomMessage message) =>
    message.globalMessageId > 0
    ? ('global', message.globalMessageId)
    : message.clientMsgId.isNotEmpty
    ? ('client', message.clientMsgId)
    : (
        'stream',
        message.locationId,
        message.conversationRoundId,
        message.senderId,
      );

extension WorldChatroomRetention on WorldChatroomService {
  List<WorldChatroomMessage> _retainedWorldIndex(
    List<WorldChatroomMessage> messages,
    Map<String, List<WorldChatroomMessage>> queues,
  ) {
    final retained = {
      for (final queue in queues.values)
        for (final message in queue) locationMessageRetentionKey(message),
    };
    return messages
        .where(
          (message) =>
              !queues.containsKey(message.locationId) ||
              !_shouldStoreMessageInLocationQueue(message) ||
              retained.contains(locationMessageRetentionKey(message)),
        )
        .toList(growable: false);
  }

  void retainMessageWindow({
    required Object owner,
    required String locationId,
    required Set<Object> protectedKeys,
    Object? focus,
  }) {
    _retentionLeases[owner] = (
      location: locationId,
      keys: Set.of(protectedKeys),
      focus: focus,
    );
    _scheduleRetention();
  }

  void releaseMessageWindow(Object owner) {
    _retentionLeases.remove(owner);
    _scheduleRetention();
  }

  void _scheduleRetention() {
    if (_retentionScheduled || _disposed) return;
    _retentionScheduled = true;
    scheduleMicrotask(() {
      _retentionScheduled = false;
      if (_disposed) return;
      final queues = {..._state.messagesByLocation};
      var changed = false;
      for (final location in queues.keys.toList()) {
        final before = queues[location]!;
        final after = _retainLocationMessages(location, before);
        if (after.length != before.length) {
          queues[location] = after;
          changed = true;
        }
      }
      if (changed) {
        _setState(
          _state.copyWith(
            messagesByLocation: queues,
            worldMessages: _retainedWorldIndex(_state.worldMessages, queues),
          ),
        );
      }
    });
  }

  List<({int lower, int upper})> cacheEvictionGaps(String location) {
    final ids =
        (_state.messagesByLocation[location] ?? const <WorldChatroomMessage>[])
            .map((m) => m.locationMessageId)
            .where((id) => id > 0)
            .toSet()
            .toList()
          ..sort();
    return [
      for (var i = 1; i < ids.length; i++)
        if (ids[i] > ids[i - 1] + 1 &&
            isCacheEvictionGap(location, ids[i - 1], ids[i]))
          (lower: ids[i - 1], upper: ids[i]),
    ];
  }

  bool isCacheEvictionGap(String location, int lower, int upper) =>
      (_cacheEvictedRanges[location] ?? const []).any(
        (r) => r.last > lower && r.first < upper,
      );

  List<WorldChatroomMessage> _retainLocationMessages(
    String location,
    List<WorldChatroomMessage> messages, {
    Set<Object> incoming = const {},
  }) {
    // A reloaded ID is no longer an eviction marker. Otherwise a later real
    // deletion/gap at the same ID could be mistaken for memory eviction.
    final evicted = _cacheEvictedRanges[location];
    if (evicted != null && evicted.isNotEmpty) {
      final loaded =
          messages
              .map((m) => m.locationMessageId)
              .where((id) => id > 0)
              .toSet()
              .toList()
            ..sort();
      final remaining = <({int first, int last})>[];
      for (final range in evicted) {
        var first = range.first;
        for (final id in loaded) {
          if (id < first) continue;
          if (id > range.last) break;
          if (id > first) remaining.add((first: first, last: id - 1));
          first = id + 1;
        }
        if (first <= range.last) {
          remaining.add((first: first, last: range.last));
        }
      }
      _cacheEvictedRanges[location] = remaining;
    }
    final leases = _retentionLeases.values.where(
      (lease) => lease.location == location,
    );
    final keys = <Object>{
      ...incoming,
      for (final lease in leases) ...lease.keys,
      for (final message in messages)
        if (message.streaming) locationMessageRetentionKey(message),
    };
    final selected = _retentionPolicy.select(
      messages,
      identity: locationMessageRetentionKey,
      protected: keys,
      focus: leases.map((l) => l.focus).whereType<Object>().firstOrNull,
    );
    if (identical(selected, messages)) return messages;
    final retained = selected.map(locationMessageRetentionKey).toSet();
    final removed =
        messages
            .where((m) => !retained.contains(locationMessageRetentionKey(m)))
            .map((m) => m.locationMessageId)
            .where((id) => id > 0)
            .toList()
          ..sort();
    final ranges = [
      ...?_cacheEvictedRanges[location],
      for (final id in removed) (first: id, last: id),
    ]..sort((a, b) => a.first.compareTo(b.first));
    final merged = <({int first, int last})>[];
    for (final range in ranges) {
      if (merged.isNotEmpty && range.first <= merged.last.last + 1) {
        final previous = merged.removeLast();
        merged.add((
          first: previous.first,
          last: math.max(previous.last, range.last),
        ));
      } else {
        merged.add(range);
      }
    }
    _cacheEvictedRanges[location] = merged;
    return selected;
  }
}
