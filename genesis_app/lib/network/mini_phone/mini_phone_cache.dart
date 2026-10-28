import 'dart:convert';

import 'mini_phone_models.dart';

/// A scope is immutable even when its owning screen changes accounts.
class MiniPhoneCacheScope {
  const MiniPhoneCacheScope(this.environment, this.ownerUid, this.worldId);
  final String environment, ownerUid, worldId;
  String get key => jsonEncode([environment, ownerUid, worldId]);
}

class MiniPhoneReadIntent {
  const MiniPhoneReadIntent(this.revision, this.throughId);
  final int revision, throughId;
  Map<String, dynamic> toJson() => {
    'revision': revision,
    'through_id': throughId,
  };
  factory MiniPhoneReadIntent.fromJson(Map<String, dynamic> json) =>
      MiniPhoneReadIntent(json['revision'] as int, json['through_id'] as int);
}

/// Synchronous projection shared by all phone screens. Network data must pass
/// through this reducer before a frozen snapshot is committed to storage.
class MiniPhoneCache {
  final messages = <int, PhoneMessage>{};
  final unreadRevisions = <int, int>{};
  final readThrough = <int, int>{};
  final readRevisions = <int, int>{};
  final pendingReads = <int, MiniPhoneReadIntent>{};
  final sessionCounts = <int, int>{};
  final sessionCountThrough = <int, int>{};
  final sessionRevisions = <int, int>{};
  final seenEvents = <String>{};
  final deliveredIds = <int>{};
  final bindings = <String, int>{};
  // Transport attempts share one stable local bubble identity.
  final retryRoots = <String, String>{};
  List<PhoneSession> sessions = [];
  int revision = 0, unknownUnread = 0;
  bool hasHomeBaseline = false;

  int get unreadCount => unknownUnread + unreadRevisions.length;
  List<PhoneMessage> get unreadMessages => [
    for (final id in unreadRevisions.keys)
      if (messages[id] != null) messages[id]!,
  ]..sort((a, b) => b.id.compareTo(a.id));

  List<PhoneMessage> history(int sessionId) =>
      messages.values.where((m) => m.sessionId == sessionId).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  bool _received(PhoneMessage m, String uid) =>
      !(m.senderType == 'user' && m.senderId == uid);
  bool _locallyRead(PhoneMessage m) => m.id <= (readThrough[m.sessionId] ?? 0);
  static bool _terminal(String? status) =>
      status == 'completed' || status == 'failed';

  void merge(Iterable<PhoneMessage> incoming) {
    for (final m in incoming) {
      final previous = messages[m.id];
      messages[m.id] =
          previous != null &&
              _terminal(previous.replyStatus) &&
              !_terminal(m.replyStatus)
          ? PhoneMessage.withReplyState(
              m,
              previous.replyStatus,
              previous.failure,
              failureCode: previous.failureCode,
            )
          : m;
    }
  }

  void delivered(Iterable<PhoneMessage> incoming, String uid) {
    final stamp = ++revision;
    for (final m in incoming) {
      if (deliveredIds.add(m.id) &&
          !unreadRevisions.containsKey(m.id) &&
          _received(m, uid) &&
          !_locallyRead(m)) {
        unreadRevisions[m.id] = stamp;
        // A session snapshot may already count this delivery before its WS
        // arrives. Add its inbox row, without counting it twice on that session.
        if (m.id > (sessionCountThrough[m.sessionId] ?? 0)) {
          sessionCounts[m.sessionId] = (sessionCounts[m.sessionId] ?? 0) + 1;
        }
        sessionRevisions[m.sessionId] = stamp;
      }
    }
    merge(incoming);
    for (final id in incoming.map((m) => m.sessionId).toSet()) {
      final known = unreadMessages.where((m) => m.sessionId == id).length;
      if (known > (sessionCounts[id] ?? 0)) sessionCounts[id] = known;
    }
  }

  void rebaseHome(PhoneHome home, String uid, int requestedRevision) {
    final concurrent = {
      for (final entry in unreadRevisions.entries)
        if (entry.value > requestedRevision) entry.key: entry.value,
    };
    final baseline = <int, PhoneMessage>{
      for (final m in home.messages)
        if (_received(m, uid)) m.id: m,
    };
    merge(home.messages);
    deliveredIds.addAll(baseline.keys);
    unreadRevisions.clear();
    for (final m in baseline.values) {
      if (_locallyRead(m)) continue;
      final readRevision = readRevisions[m.sessionId] ?? 0;
      if (readRevision > requestedRevision &&
          (concurrent[m.id] ?? 0) <= readRevision) {
        // Reading an empty cached conversation can race its first Home load.
        final boundary = readThrough[m.sessionId] ?? 0;
        if (m.id > boundary) readThrough[m.sessionId] = m.id;
        final intent = pendingReads[m.sessionId];
        if (intent != null && m.id > intent.throughId) {
          pendingReads[m.sessionId] = MiniPhoneReadIntent(
            intent.revision,
            m.id,
          );
        }
        continue;
      }
      unreadRevisions[m.id] = requestedRevision;
    }
    for (final entry in concurrent.entries) {
      final m = messages[entry.key];
      if (m != null && !_locallyRead(m)) {
        unreadRevisions[entry.key] = entry.value;
      }
    }
    unknownUnread = (home.dmUnread - baseline.length).clamp(0, home.dmUnread);
    hasHomeBaseline = true;
    final knownCounts = <int, int>{};
    for (final m in unreadMessages) {
      knownCounts[m.sessionId] = (knownCounts[m.sessionId] ?? 0) + 1;
    }
    for (final id in {...sessionCounts.keys, ...knownCounts.keys}) {
      final count = knownCounts[id] ?? 0;
      if (unknownUnread == 0 || pendingReads.containsKey(id)) {
        sessionCounts[id] = count;
      } else if (count > (sessionCounts[id] ?? 0)) {
        sessionCounts[id] = count;
      }
    }
  }

  MiniPhoneReadIntent markRead(int id) {
    final stamp = ++revision;
    var boundary = readThrough[id] ?? 0;
    for (final m in messages.values.where((m) => m.sessionId == id)) {
      unreadRevisions.remove(m.id);
      if (m.id > boundary) boundary = m.id;
    }
    readThrough[id] = boundary;
    readRevisions[id] = stamp;
    sessionRevisions[id] = stamp;
    sessionCounts[id] = 0;
    return pendingReads[id] = MiniPhoneReadIntent(stamp, boundary);
  }

  void acknowledgeRead(int id, int sentRevision) {
    if (pendingReads[id]?.revision == sentRevision) pendingReads.remove(id);
  }

  void mergeSessions(
    List<PhoneSession> incoming, {
    required bool next,
    required int requestedRevision,
  }) {
    final merged = <(String, String), PhoneSession>{
      if (next)
        for (final s in sessions) s.key: s,
      for (final s in incoming) s.key: s,
    };
    sessions = merged.values.toList();
    for (final s in incoming) {
      if (s.id <= 0) continue;
      bindings[s.person.id] = s.id;
      if ((sessionRevisions[s.id] ?? 0) <= requestedRevision &&
          !pendingReads.containsKey(s.id)) {
        final last = s.lastMessage;
        sessionCountThrough[s.id] = last?.id ?? 0;
        final known = unreadMessages.where((m) => m.sessionId == s.id).length;
        sessionCounts[s.id] = last != null && _locallyRead(last)
            ? known
            : s.unreadCount < known
            ? known
            : s.unreadCount;
      }
      if (s.lastMessage != null) merge([s.lastMessage!]);
    }
  }

  bool acceptEvent(String eventId) {
    if (!seenEvents.add(eventId)) return false;
    while (seenEvents.length > 2000) {
      seenEvents.remove(seenEvents.first);
    }
    return true;
  }

  /// Exempt inbox, unsettled requests and the most recent delivery from eviction.
  void prune({Set<String> protectedRequests = const {}, int limit = 1000}) {
    final groups = <int, List<PhoneMessage>>{};
    for (final m in messages.values) {
      (groups[m.sessionId] ??= []).add(m);
    }
    for (final group in groups.values) {
      group.sort((a, b) => b.id.compareTo(a.id));
      final latest = group.reduce((a, b) {
        final at = DateTime.tryParse(a.deliveredAt);
        final bt = DateTime.tryParse(b.deliveredAt);
        return bt != null && (at == null || bt.isAfter(at)) ? b : a;
      }).id;
      var ordinary = 0;
      for (final m in group) {
        if (unreadRevisions.containsKey(m.id) ||
            m.id == latest ||
            protectedRequests.contains(m.requestId) ||
            m.replyStatus == 'pending' ||
            m.replyStatus == 'generating') {
          continue;
        }
        if (++ordinary > limit) {
          messages.remove(m.id);
          if (_locallyRead(m)) deliveredIds.remove(m.id);
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'messages': messages.values.map((m) => m.toJson()).toList(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'unread': {for (final e in unreadRevisions.entries) '${e.key}': e.value},
    'read_through': {for (final e in readThrough.entries) '${e.key}': e.value},
    'read_revisions': {
      for (final e in readRevisions.entries) '${e.key}': e.value,
    },
    'pending_reads': {
      for (final e in pendingReads.entries) '${e.key}': e.value.toJson(),
    },
    'session_counts': {
      for (final e in sessionCounts.entries) '${e.key}': e.value,
    },
    'session_count_through': {
      for (final e in sessionCountThrough.entries) '${e.key}': e.value,
    },
    'session_revisions': {
      for (final e in sessionRevisions.entries) '${e.key}': e.value,
    },
    'bindings': Map<String, int>.of(bindings),
    'retry_roots': Map<String, String>.of(retryRoots),
    'events': seenEvents.toList(),
    'delivered_ids': deliveredIds.toList(),
    'revision': revision,
    'unknown_unread': unknownUnread,
    'home_baseline': hasHomeBaseline,
  };

  MiniPhoneCache();
  factory MiniPhoneCache.fromJson(Map<String, dynamic> json) {
    final cache = MiniPhoneCache();
    cache.merge(phoneList(json['messages'] ?? [], PhoneMessage.fromJson));
    for (final e in phoneMap(json['retry_roots'] ?? {}).entries) {
      cache.retryRoots[e.key] = e.value as String;
    }
    cache.sessions = phoneList(
      json['sessions'] ?? [],
      PhoneSession.fromJson,
    ).toList();
    void restore(String key, Map<int, int> target) {
      for (final e in phoneMap(json[key] ?? {}).entries) {
        target[int.parse(e.key)] = e.value as int;
      }
    }

    restore('unread', cache.unreadRevisions);
    restore('read_through', cache.readThrough);
    restore('read_revisions', cache.readRevisions);
    restore('session_counts', cache.sessionCounts);
    restore('session_count_through', cache.sessionCountThrough);
    restore('session_revisions', cache.sessionRevisions);
    for (final e in phoneMap(json['pending_reads'] ?? {}).entries) {
      cache.pendingReads[int.parse(e.key)] = MiniPhoneReadIntent.fromJson(
        phoneMap(e.value),
      );
    }
    for (final e in phoneMap(json['bindings'] ?? {}).entries) {
      cache.bindings[e.key] = e.value as int;
    }
    cache.seenEvents.addAll((json['events'] as List? ?? []).cast<String>());
    cache.deliveredIds.addAll(
      (json['delivered_ids'] as List? ?? []).cast<int>(),
    );
    cache.revision = json['revision'] as int? ?? 0;
    cache.unknownUnread = json['unknown_unread'] as int? ?? 0;
    cache.hasHomeBaseline = json['home_baseline'] == true;
    return cache;
  }
}
