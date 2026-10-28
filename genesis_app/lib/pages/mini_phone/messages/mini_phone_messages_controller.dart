import '../../../l10n/genesis_l10n.dart';
import 'dart:async';
import 'dart:convert';
import '../../../network/mini_phone/mini_phone_api.dart';
import '../../../network/mini_phone/mini_phone_cache.dart';
import '../../../network/mini_phone/mini_phone_cache_storage.dart';
import '../state/mini_phone_requests.dart';
import '../state/mini_phone_write.dart';

/// Durable DM projection, history, read receipts and correlated reply state.
class MiniPhoneMessagesController {
  MiniPhoneMessagesController({
    required this.api,
    required this.worldId,
    required this.requests,
    required this.cacheStorage,
    required this.pending,
    required this.people,
    required this.person,
    required this.isHydrated,
    required this.saveJournal,
    required this.refreshSummary,
    required this.scheduleReplyRecovery,
  });
  final MiniPhoneApi api;
  final String worldId;
  final MiniPhoneRequests requests;
  final MiniPhoneCacheStorage cacheStorage;
  final Map<String, PhoneWrite> pending;
  final Map<String, PhonePerson> people;
  final PhonePerson Function(String id, {int type}) person;
  final bool Function() isHydrated;
  final Future<bool> Function() saveJournal;
  final Future<bool> Function({int? preserveAfterRevision}) refreshSummary;
  final void Function() scheduleReplyRecovery;
  bool cacheCanSave = false;
  bool unreadSessionsOnly = false;
  String? activeCharId;
  String? get uid => requests.uid;
  bool get foreground => requests.foreground;
  bool get phoneVisible => requests.phoneVisible;
  Map<String, int> get pages => requests.pages;
  Map<String, bool> get hasMore => requests.hasMore;
  Map<String, String> get errors => requests.errors;
  Set<String> get busy => requests.busy;
  Future<bool> load<T>(
    String key,
    Future<T> Function() fetch,
    void Function(T) apply, {
    String requestKey = '',
    bool deduplicate = true,
    bool allowBackground = false,
  }) => requests.load(
    key,
    fetch,
    apply,
    requestKey: requestKey,
    deduplicate: deduplicate,
    allowBackground: allowBackground,
  );
  MiniPhoneCache cache = MiniPhoneCache();
  MiniPhoneCacheScope? cacheScope;
  static final _storageWriteQueues = Expando<Map<String, Future<void>>>();
  Map<String, Future<void>> get cacheWrites =>
      _storageWriteQueues[cacheStorage] ??= <String, Future<void>>{};
  Future<void> get cacheSaved => cacheScope == null
      ? Future<void>.value()
      : cacheWrites[cacheScope!.key] ?? Future<void>.value();
  List<PhoneMessage> get unreadMessages => cache.unreadMessages;
  int get dmUnreadCount => cache.unreadCount;
  Future<bool> persistCache() {
    final scope = cacheScope, g = requests.generation;
    if (scope == null || !cacheCanSave) return Future.value(false);
    cache.sessions = sessions;
    cache.bindings.addAll(sessionByChar);
    cache.prune(
      protectedRequests: {
        for (final w in pending.values)
          if (w.kind == 'dm' && !w.rejected) w.id,
      },
    );
    final snapshot = cache.toJson();
    final result = (cacheWrites[scope.key] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          try {
            await cacheStorage.save(scope, snapshot);
            if (requests.isCurrent(g) && errors.remove('cache') != null) {
              requests.notify();
            }
            return true;
          } catch (_) {
            if (requests.isCurrent(g)) {
              errors['cache'] = GenesisL10n.current.miniPhoneSaveMessagesFailed;
              requests.notify();
            }
            return false;
          }
        });
    cacheWrites[scope.key] = result.then((_) {});
    return result;
  }

  void restoreCacheProjection() {
    sessions = cache.sessions;
    for (final session in sessions) {
      rememberSession(session);
    }
    sessionByChar.addAll(cache.bindings);
    for (final id in cache.messages.values.map((m) => m.sessionId).toSet()) {
      final all = cache.history(id);
      messages[id] = all.skip((all.length - 50).clamp(0, all.length)).toList();
      hasMore['messages:$id'] = true;
      for (final m in all) {
        if (m.senderType == 'char') sessionByChar[m.senderId] = id;
      }
    }
  }

  int _sessionUnread(PhoneSession session) =>
      cache.sessionCounts[sessionFor(session.person.id) ?? session.id] ??
      session.unreadCount;
  final drafts = <String, String>{};
  List<PhoneSession> sessions = [];

  /// Only server-listed sessions create rows; cached deliveries update recency.
  List<MiniPhoneConversation> get conversations {
    final byChar = {for (final s in sessions) s.person.id: s};
    final rows = <MiniPhoneConversation>[];
    for (final session in byChar.values) {
      final p = people[session.person.id] ?? session.person;
      final unreadCount = _sessionUnread(session);
      if (unreadSessionsOnly && unreadCount == 0) continue;
      final id = sessionFor(p.id);
      PhoneMessage? latest = session.lastMessage;
      for (final m in [...cache.history(id ?? 0), ...?messages[id]]) {
        if (latest == null || _compareMessageRecency(m, latest) > 0) latest = m;
      }
      rows.add(MiniPhoneConversation(p, unreadCount, latest));
    }
    final originalOrder = {
      for (var i = 0; i < rows.length; i++) rows[i].person.id: i,
    };
    rows.sort((a, b) {
      final aMessage = a.lastMessage, bMessage = b.lastMessage;
      if (aMessage == null && bMessage != null) return 1;
      if (aMessage != null && bMessage == null) return -1;
      if (aMessage != null && bMessage != null) {
        final recency = _compareMessageRecency(bMessage, aMessage);
        if (recency != 0) return recency;
      }
      return originalOrder[a.person.id]!.compareTo(originalOrder[b.person.id]!);
    });
    return rows;
  }

  static int _compareMessageRecency(PhoneMessage a, PhoneMessage b) {
    final aTime = DateTime.tryParse(a.deliveredAt);
    final bTime = DateTime.tryParse(b.deliveredAt);
    if (aTime != null && bTime != null) {
      final timeOrder = aTime.compareTo(bTime);
      if (timeOrder != 0) return timeOrder;
    } else if (aTime != null) {
      return 1;
    } else if (bTime != null) {
      return -1;
    }
    return a.id.compareTo(b.id);
  }

  final sessionByChar = <String, int>{};
  final peerByChar = <String, String>{};
  final knownSessionChars = <String>{};
  final replyStates = <String, ({String status, String? failure})>{};
  final appliedReplyTerminals = <String>{};
  bool isPlayerChat(String charId) => (peerByChar[charId] ?? '').isNotEmpty;
  PhonePerson personForMessage(PhoneMessage message) {
    if (message.senderType == 'char') return person(message.senderId);
    for (final entry in peerByChar.entries) {
      if (entry.value == message.senderId) return person(entry.key);
    }
    return person(message.senderId, type: 1);
  }

  String? charForMessage(PhoneMessage message) {
    for (final entry in sessionByChar.entries) {
      if (entry.value == message.sessionId) return entry.key;
    }
    if (message.senderType == 'char') return message.senderId;
    for (final entry in peerByChar.entries) {
      if (entry.value == message.senderId) return entry.key;
    }
    return null;
  }

  final messages = <int, List<PhoneMessage>>{};
  // Presentation only: never insert temporary IDs into server history/counts.
  final outgoing = <String, PhoneWrite>{};
  Iterable<PhoneWrite> outgoingDm(String charId) =>
      outgoing.values.where((w) => w.target == charId);
  final replyFailures = <String, String>{};
  // One-shot presentation, separate from the retained message failure state.
  // Terminal request deduplication prevents history refreshes from requeueing it.
  final replyFailureNotices = <String, ({String requestId, String message})>{};
  Future<bool> refreshSessions({bool next = false}) {
    const key = 'sessions';
    final revision = cache.revision;
    final pn = next ? (pages[key] ?? 1) + 1 : 1;
    return load(
      key,
      () => api.sessions(worldId, pn: pn, unreadOnly: unreadSessionsOnly),
      (page) {
        cache.mergeSessions(page.list, next: next, requestedRevision: revision);
        sessions = cache.sessions;
        for (final s in page.list) {
          rememberSession(s);
        }
        pages[key] = pn;
        hasMore[key] = page.hasMore;
        unawaited(persistCache());
      },
      requestKey: '$pn:$unreadSessionsOnly',
    );
  }

  void rememberSession(PhoneSession session) {
    knownSessionChars.add(session.person.id);
    peerByChar[session.person.id] = session.peerUid;
    if (session.id > 0) sessionByChar[session.person.id] = session.id;
    people[session.person.id] = session.person;
  }

  int? sessionFor(String charId) => sessionByChar[charId];
  List<PhoneMessage> history(String charId) =>
      messages[sessionFor(charId)] ?? const [];
  bool unresolved(String key) =>
      pending[key] != null && !pending[key]!.rejected;
  PhoneWrite? waiting(String charId) =>
      unresolved('dm:$charId') ? pending['dm:$charId'] : null;
  bool _terminal(String? state) => state == 'completed' || state == 'failed';

  /// Server delivery/terminal evidence can arrive before the send HTTP returns.
  /// Retire only this request, so its late HTTP cleanup cannot own the next send.
  void finishPendingDm(PhoneWrite write) {
    if (!identical(pending[write.key], write)) return;
    write
      ..accepted = true
      ..uncertain = false
      ..rejected = false;
    pending.remove(write.key);
    busy.remove(write.key);
  }

  void applyReplyState(
    String requestId,
    String status,
    String? failure,
    int sessionId,
  ) {
    final previous = replyStates[requestId];
    if (_terminal(previous?.status) &&
        appliedReplyTerminals.contains(requestId)) {
      return;
    }
    final state =
        _terminal(previous?.status) ||
            previous?.status == 'generating' && status == 'pending'
        ? previous!
        : (status: status, failure: failure);
    replyStates[requestId] = state;
    String? charId;
    for (final entry in sessionByChar.entries) {
      if (entry.value == sessionId) charId = entry.key;
    }
    for (final w in pending.values.toList()) {
      if (w.kind == 'dm' && w.id == requestId) charId = w.target;
    }
    if (charId == null || isPlayerChat(charId)) return;
    sessionByChar[charId] = sessionId;
    final key = 'dm:$charId';
    final write = pending[key];
    if (_terminal(state.status)) {
      appliedReplyTerminals.add(requestId);
      if (write?.id == requestId) finishPendingDm(write!);
      if (state.status == 'failed' &&
          (write == null || write.id == requestId)) {
        replyFailures[charId] =
            state.failure ?? GenesisL10n.current.miniPhoneReplyFailed;
        replyFailureNotices[charId] = (
          requestId: requestId,
          message: replyFailures[charId]!,
        );
      }
    } else {
      final source = messages[sessionId]
          ?.where(
            (m) =>
                m.senderType == 'user' &&
                m.senderId == uid &&
                m.requestId == requestId,
          )
          .firstOrNull;
      if (write?.id == requestId) {
        write!
          ..accepted = true
          ..uncertain = false
          ..rejected = false;
      } else if (write == null && source != null) {
        pending[key] = PhoneWrite(requestId, 'dm', charId, source.content)
          ..accepted = true;
      }
    }
  }

  void mergeMessages(int id, List<PhoneMessage> incoming) {
    final all = <int, PhoneMessage>{
      for (final m in messages[id] ?? <PhoneMessage>[]) m.id: m,
    };
    for (final m in incoming) {
      final old = all[m.id];
      final state = replyStates[m.requestId];
      final preserve = _terminal(state?.status)
          ? state
          : _terminal(old?.replyStatus)
          ? (status: old!.replyStatus!, failure: old.failure)
          : null;
      all[m.id] =
          preserve != null && m.senderType == 'user' && m.senderId == uid
          ? PhoneMessage.withReplyState(m, preserve.status, preserve.failure)
          : m;
      if (m.senderType == 'char') sessionByChar[m.senderId] = id;
      if (m.senderType == 'user' && m.senderId == uid && m.requestId != null) {
        outgoing.remove(m.requestId);
        for (final w in pending.values.toList()) {
          if (w.id == m.requestId && w.kind == 'dm') {
            sessionByChar[w.target] = id;
            w.accepted = true;
            w.rejected = false;
            if (isPlayerChat(w.target)) finishPendingDm(w);
          }
        }
      }
    }
    cache.merge(all.values);
    messages[id] = [for (final id in all.keys) cache.messages[id]!]
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final m in messages[id]!) {
      if (m.senderType == 'user' &&
          m.senderId == uid &&
          m.requestId != null &&
          m.replyStatus != null) {
        applyReplyState(m.requestId!, m.replyStatus!, m.failure, id);
      }
    }
    cache.merge(messages[id]!);
    unawaited(persistCache());
    scheduleReplyRecovery();
  }

  Future<bool> _resolveSession(String charId) async {
    if (sessionFor(charId) != null ||
        knownSessionChars.contains(charId) && !unresolved('dm:$charId')) {
      return true;
    }
    final g = requests.generation;
    return load(
      'session:$charId',
      () async {
        var pn = 1;
        while (requests.isCurrent(g) && foreground) {
          // Discovery must include read sessions, regardless of the list filter.
          final page = await api.sessions(worldId, pn: pn, unreadOnly: false);
          for (final session in page.list) {
            if (session.person.id == charId) return session;
          }
          if (!page.hasMore) return null;
          pn = page.pn + 1;
        }
        return null;
      },
      (session) {
        if (session != null) {
          rememberSession(session);
        }
      },
    );
  }

  Future<bool> refreshMessages(String charId, {bool next = false}) async {
    final generation = requests.generation;
    final journalBefore = jsonEncode(
      pending.values.map((w) => w.toJson()).toList(),
    );
    if (!foreground) return false;
    if (!await _resolveSession(charId) ||
        !requests.isCurrent(generation) ||
        !foreground) {
      return false;
    }
    final id = sessionFor(charId);
    if (id == null) return true;
    if (next && (messages[id]?.isNotEmpty ?? false)) {
      final before = messages[id]!.first.id;
      final scope = cacheScope;
      var cached = cache.history(id).where((m) => m.id < before).toList();
      if (scope != null && cacheCanSave) {
        try {
          await cacheSaved;
          final stored = await cacheStorage.loadBefore(scope, id, before, 50);
          if (!requests.isCurrent(generation)) return false;
          final byId = {
            for (final m in [...stored, ...cached]) m.id: m,
          };
          cached = byId.values.toList();
        } catch (_) {
          if (!requests.isCurrent(generation)) return false;
          errors['cache'] =
              GenesisL10n.current.miniPhoneLoadSavedMessagesFailed;
        }
      }
      if (cached.isNotEmpty) {
        cached.sort((a, b) => b.id.compareTo(a.id));
        mergeMessages(id, cached.take(50).toList());
        hasMore['messages:$id'] = true;
        requests.notify();
        return true;
      }
    }
    final key = 'messages:$id',
        pn = next ? (pages['messages:$id'] ?? 1) + 1 : 1;
    final known = messages[id]?.map((m) => m.id).toSet() ?? <int>{};
    final g = requests.generation;
    final ok = await load(
      key,
      () async {
        var page = await api.messages(worldId, id, pn: pn);
        final recovered = <PhoneMessage>[...page.list];
        if (next && known.isNotEmpty) {
          final oldest = known.reduce((a, b) => a < b ? a : b);
          while (page.hasMore &&
              !page.list.any((m) => m.id < oldest) &&
              requests.isCurrent(g) &&
              foreground) {
            page = await api.messages(worldId, id, pn: page.pn + 1);
            recovered.addAll(page.list);
          }
        }
        // Recover a missed run of messages, not just the newest ten bubbles.
        while (!next &&
            known.isNotEmpty &&
            page.hasMore &&
            !page.list.any((m) => known.contains(m.id)) &&
            requests.isCurrent(g) &&
            foreground) {
          page = await api.messages(worldId, id, pn: page.pn + 1);
          recovered.addAll(page.list);
        }
        return PhonePage(recovered, page.total, page.pn, page.rn);
      },
      (page) {
        mergeMessages(id, page.list);
        pages[key] = page.pn;
        final oldest = messages[id]?.firstOrNull?.id;
        hasMore[key] =
            page.hasMore ||
            oldest != null && cache.history(id).any((m) => m.id < oldest);
      },
      requestKey: '$pn:$next',
    );
    if (ok &&
        requests.isCurrent(generation) &&
        journalBefore !=
            jsonEncode(pending.values.map((w) => w.toJson()).toList())) {
      unawaited(saveJournal());
    }
    if (!requests.isCurrent(generation)) return false;
    if (ok && !next && activeCharId == charId && foreground && phoneVisible) {
      await markSessionRead(id);
    }
    return ok;
  }

  final reads = <int, Future<void>>{};
  Future<void> markSessionRead(int id, {bool newDelivery = false}) {
    if (id <= 0 || !isHydrated()) return Future<void>.value();
    final boundary = cache.history(id).lastOrNull?.id ?? 0;
    final previous = cache.readThrough[id];
    if (previous != null &&
        boundary <= previous &&
        (cache.sessionCounts[id] ?? 0) == 0) {
      return _syncRead(id);
    }
    cache.markRead(id);
    sessions = [
      for (final s in sessions)
        s.id == id ? PhoneSession.withUnreadCount(s, 0) : s,
    ];
    final saved = persistCache();
    requests.notify();
    return _syncRead(id, saved: saved);
  }

  Future<void> _syncRead(int id, {Future<bool>? saved}) {
    if (!foreground) return Future.value();
    final existing = reads[id];
    if (existing != null) return existing;
    final g = requests.generation;
    return reads[id] =
        (() async {
          if (saved != null && !await saved) return;
          while (requests.isCurrent(g) && foreground) {
            final intent = cache.pendingReads[id];
            if (intent == null) break;
            // Durable before submission: reopening can retry an interrupted receipt.
            if (!await persistCache() ||
                !requests.isCurrent(g) ||
                !foreground) {
              return;
            }
            final ok = await load(
              'read:$id',
              () => api.readSession(id),
              (_) {},
            );
            if (!requests.isCurrent(g) || !ok) break;
            cache.acknowledgeRead(id, intent.revision);
            await persistCache();
            if (!requests.isCurrent(g)) return;
            await refreshSummary(preserveAfterRevision: intent.revision);
            if (!requests.isCurrent(g)) return;
          }
        })().whenComplete(() {
          if (requests.isCurrent(g)) reads.remove(id);
        });
  }

  Future<void> retryPendingReads() async {
    final g = requests.generation;
    for (final id in cache.pendingReads.keys.toList()) {
      if (!requests.isCurrent(g) || !foreground) return;
      await _syncRead(id);
    }
  }
}

class MiniPhoneConversation {
  const MiniPhoneConversation(this.person, this.unreadCount, this.lastMessage);
  final PhonePerson person;
  final int unreadCount;
  final PhoneMessage? lastMessage;
}
