import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../network/api_exception.dart';
import '../../network/mini_phone/mini_phone_api.dart';
import '../../network/mini_phone/mini_phone_cache.dart';
import '../../network/mini_phone/mini_phone_cache_storage.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/world.dart';
import '../../network/models/user.dart';
import '../../utils/genesis_image_resource.dart';

/// One world/account's phone, backed by a durable local inbox and server data.
class MiniPhoneStore extends ChangeNotifier with WidgetsBindingObserver {
  MiniPhoneStore({
    required this.api,
    required this.worldId,
    required this.namespace,
    required this.readUid,
    required this.loadWorld,
    required this.accountRevision,
    this.loadUser,
    MiniPhoneCacheStorage? cacheStorage,
  }) : cacheStorage = cacheStorage ?? SqliteMiniPhoneCacheStorage.instance {
    accountRevision.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    ready = _initialize();
  }
  final MiniPhoneApi api;
  final MiniPhoneCacheStorage cacheStorage;
  MiniPhoneCache _cache = MiniPhoneCache();
  MiniPhoneCacheScope? _cacheScope;
  Completer<void> _localReady = Completer<void>();
  Future<void> get localReady => _localReady.future;
  bool _hydrated = false, _cacheCanSave = false;
  final _earlyEvents = <ChatroomPhoneEvent>[];
  static final _storageWriteQueues = Expando<Map<String, Future<void>>>();
  Map<String, Future<void>> get _cacheWrites =>
      _storageWriteQueues[cacheStorage] ??= <String, Future<void>>{};
  Future<void> get cacheSaved => _cacheScope == null
      ? Future<void>.value()
      : _cacheWrites[_cacheScope!.key] ?? Future<void>.value();
  List<PhoneMessage> get unreadMessages => _cache.unreadMessages;
  int get dmUnreadCount => _cache.unreadCount;
  int get totalUnreadCount => dmUnreadCount + home.postUnread;
  String? get latestUnreadCharId => unreadMessages.isEmpty
      ? unread.charId
      : charForMessage(unreadMessages.first);

  Future<bool> _persistCache() {
    final scope = _cacheScope, g = _generation;
    if (scope == null || !_cacheCanSave) return Future.value(false);
    _cache.sessions = sessions;
    _cache.bindings.addAll(_sessionByChar);
    _cache.prune(
      protectedRequests: {
        for (final w in pending.values)
          if (w.kind == 'dm' && !w.rejected) w.id,
      },
    );
    final snapshot = _cache.toJson();
    final result = (_cacheWrites[scope.key] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          try {
            await cacheStorage.save(scope, snapshot);
            if (_current(g) && errors.remove('cache') != null) _notify();
            return true;
          } catch (_) {
            if (_current(g)) {
              errors['cache'] =
                  'Unable to save messages on this device. Please try again.';
              _notify();
            }
            return false;
          }
        });
    _cacheWrites[scope.key] = result.then((_) {});
    return result;
  }

  void _restoreCacheProjection() {
    sessions = _cache.sessions;
    for (final session in sessions) {
      _rememberSession(session);
    }
    _sessionByChar.addAll(_cache.bindings);
    for (final id in _cache.messages.values.map((m) => m.sessionId).toSet()) {
      final all = _cache.history(id);
      messages[id] = all.skip((all.length - 50).clamp(0, all.length)).toList();
      hasMore['messages:$id'] = true;
      for (final m in all) {
        if (m.senderType == 'char') _sessionByChar[m.senderId] = id;
      }
    }
  }

  int _sessionUnread(PhoneSession session) =>
      _cache.sessionCounts[sessionFor(session.person.id) ?? session.id] ??
      session.unreadCount;
  final String worldId, namespace;
  final Future<String?> Function() readUid;
  final Future<WorldDetail> Function() loadWorld;
  final Future<User> Function(String)? loadUser;
  final Listenable accountRevision;
  late Future<void> ready;
  String? uid;
  bool _disposed = false, foreground = true, phoneVisible = false;
  int _generation = 0;
  int get accountGeneration => _generation;
  String? activeCharId;
  int? activePostId;
  bool notificationsVisible = false, postsVisible = false, albumVisible = false;
  bool unreadSessionsOnly = false, unreadNotificationsOnly = true;
  bool _postReadOnLoad = false;
  String? _authorFilter;
  String? get authorFilter => _authorFilter;
  set authorFilter(String? charId) {
    final value = charId == '' ? null : charId;
    if (_authorFilter == value) return;
    _authorFilter = value;
    // Invalidate in-flight pages before another author's first page starts.
    _versions['posts'] = (_versions['posts'] ?? 0) + 1;
    posts = [];
    pages.remove('posts');
    hasMore.remove('posts');
    errors.remove('posts');
    busy.remove('posts');
  }

  PhoneHome home = const PhoneHome();
  PhoneUnread unread = const PhoneUnread(0, null);
  String worldName = '', currentTime = '';
  String get clockTime =>
      RegExp(
        r'\b(?:[01]?\d|2[0-3]):[0-5]\d\b',
      ).firstMatch(currentTime)?.group(0) ??
      '';
  String get worldDay =>
      RegExp(
        r'Day\s+\d+',
        caseSensitive: false,
      ).firstMatch(currentTime)?.group(0) ??
      '';
  final people = <String, PhonePerson>{};
  final users = <String, PhonePerson>{};
  final playerCharIds = <String>{};
  List<String> postAuthorIds = [];
  Iterable<PhonePerson> get authors =>
      postAuthorIds.map((id) => people[id] ?? PhonePerson(id, id, ''));
  Iterable<PhonePerson> get contacts =>
      people.values.where((p) => !playerCharIds.contains(p.id));
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
      for (final m in [..._cache.history(id ?? 0), ...?messages[id]]) {
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

  List<PhonePost> posts = [];
  List<PhoneAlbumAsset> album = [];
  PhonePage<PhoneNotification>? notifications;
  final messages = <int, List<PhoneMessage>>{};
  final details = <int, PhonePostDetail>{};
  final comments = <int, List<PhoneComment>>{};
  final pages = <String, int>{};
  final hasMore = <String, bool>{};
  final errors = <String, String>{};
  final busy = <String>{};
  final _versions = <String, int>{};
  final _sessionByChar = <String, int>{};
  final _peerByChar = <String, String>{};
  final _knownSessionChars = <String>{};
  final _replyStates = <String, ({String status, String? failure})>{};
  final _appliedReplyTerminals = <String>{};
  bool isPlayerChat(String charId) => (_peerByChar[charId] ?? '').isNotEmpty;
  PhonePerson personForMessage(PhoneMessage message) {
    if (message.senderType == 'char') return person(message.senderId);
    for (final entry in _peerByChar.entries) {
      if (entry.value == message.senderId) return person(entry.key);
    }
    return person(message.senderId, type: 1);
  }

  String? charForMessage(PhoneMessage message) {
    for (final entry in _sessionByChar.entries) {
      if (entry.value == message.sessionId) return entry.key;
    }
    if (message.senderType == 'char') return message.senderId;
    for (final entry in _peerByChar.entries) {
      if (entry.value == message.senderId) return entry.key;
    }
    return null;
  }

  final pending = <String, PhoneWrite>{};
  // Presentation only: never insert temporary IDs into server history/counts.
  final _outgoingDm = <String, PhoneWrite>{};
  Iterable<PhoneWrite> outgoingDm(String charId) =>
      _outgoingDm.values.where((w) => w.target == charId);
  final replyFailures = <String, String>{};
  StreamSubscription<ChatroomPhoneEvent>? _events;
  StreamSubscription<WorldChatroomState>? _states;
  Timer? _refreshTimer;
  Timer? _replyPollTimer;
  int _replyPollSeconds = 2;
  bool _refreshing = false, _dirty = false, _refreshHome = false;
  bool _wasConnected = false;
  static final _journalWrites = <String, Future<void>>{};
  Future<void> get writesSaved =>
      _journalWrites[_storageKey] ?? Future<void>.value();
  String get _storageKey =>
      'phone-writes:${Uri.encodeComponent(namespace)}:$uid:$worldId';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  static String errorText(Object e) =>
      e is ApiException ? e.message : 'Unable to load. Please try again.';

  Future<void> _initialize() async {
    final g = _generation;
    final owner = await readUid();
    if (!_current(g)) return;
    uid = owner;
    if (owner == null || owner.isEmpty || worldId.isEmpty) {
      if (!_localReady.isCompleted) _localReady.complete();
      errors['home'] = 'Sign in and open Mini phone from a World.';
      _notify();
      return;
    }
    _cacheScope = MiniPhoneCacheScope(namespace, owner, worldId);
    final scope = _cacheScope!;
    try {
      await _cacheWrites[scope.key];
      final restored = await cacheStorage.load(scope);
      if (!_current(g)) return;
      _cache = restored;
      _cacheCanSave = true;
      _restoreCacheProjection();
    } catch (_) {
      if (!_current(g)) return;
      errors['cache'] =
          'Unable to load messages saved on this device. Please try again.';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_current(g)) return;
      await _journalWrites[_storageKey];
      if (!_current(g)) return;
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        for (final value in jsonDecode(raw) as List) {
          final write = PhoneWrite.fromJson(phoneMap(value));
          pending[write.key] = write;
          if (write.kind == 'dm' && !write.rejected) {
            _outgoingDm[write.id] = write;
          }
        }
      }
    } catch (_) {
      /* A damaged local journal cannot replace server data. */
    }
    if (!_current(g)) return;
    final journalBeforeRestore = jsonEncode(
      pending.values.map((w) => w.toJson()).toList(),
    );
    for (final m in _cache.messages.values) {
      if (m.senderType != 'user' || m.senderId != uid || m.requestId == null) {
        continue;
      }
      _outgoingDm.remove(m.requestId);
      for (final w in pending.values.toList()) {
        if (w.kind != 'dm' || w.id != m.requestId) continue;
        _sessionByChar[w.target] = m.sessionId;
        w.accepted = true;
        if (isPlayerChat(w.target)) pending.remove(w.key);
      }
      if (m.replyStatus != null) {
        _applyReplyState(m.requestId!, m.replyStatus!, m.failure, m.sessionId);
      }
    }
    if (journalBeforeRestore !=
        jsonEncode(pending.values.map((w) => w.toJson()).toList())) {
      unawaited(_save().catchError((Object _) {}));
    }
    _hydrated = true;
    if (!_localReady.isCompleted) _localReady.complete();
    final early = List<ChatroomPhoneEvent>.of(_earlyEvents);
    _earlyEvents.clear();
    for (final event in early) {
      receive(event);
    }
    _notify();
    await _retryPendingReads();
    if (!_current(g)) return;
    await Future.wait([refreshSummary(), refreshPeople()]);
    if (_current(g) && pending.isNotEmpty) scheduleRefresh();
  }

  void _accountChanged() {
    _generation++;
    if (!_localReady.isCompleted) _localReady.complete();
    _localReady = Completer<void>();
    _hydrated = _cacheCanSave = false;
    _cacheScope = null;
    _cache = MiniPhoneCache();
    _earlyEvents.clear();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _dirty = _refreshHome = false;
    uid = null;
    _postReadOnLoad = false;
    authorFilter = null;
    home = const PhoneHome();
    unread = const PhoneUnread(0, null);
    sessions = [];
    posts = [];
    album = [];
    notifications = null;
    people.clear();
    users.clear();
    postAuthorIds = [];
    playerCharIds.clear();
    drafts.clear();
    messages.clear();
    details.clear();
    comments.clear();
    pending.clear();
    _outgoingDm.clear();
    replyFailures.clear();
    _sessionByChar.clear();
    _peerByChar.clear();
    _knownSessionChars.clear();
    _replyStates.clear();
    _appliedReplyTerminals.clear();
    _replyPollTimer?.cancel();
    _replyPollTimer = null;
    _replyPollSeconds = 2;
    _likeIntent.clear();
    _likeRunning.clear();
    pages.clear();
    hasMore.clear();
    errors.clear();
    busy.clear();
    _versions.clear();
    _reads.clear();
    likeTargets.clear();
    activeCharId = null;
    activePostId = null;
    _notify();
    ready = _initialize();
  }

  Future<void> _save() {
    final key = _storageKey;
    final content = jsonEncode(pending.values.map((w) => w.toJson()).toList());
    return _journalWrites[key] = (_journalWrites[key] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(key, content);
        });
  }

  Future<bool> load<T>(
    String key,
    Future<T> Function() fetch,
    void Function(T) apply,
  ) async {
    if (_disposed || uid == null) return false;
    final g = _generation, v = (_versions[key] ?? 0) + 1;
    _versions[key] = v;
    busy.add(key);
    errors.remove(key);
    _notify();
    try {
      final result = await fetch();
      if (!_current(g) || _versions[key] != v) return false;
      apply(result);
      return true;
    } catch (e) {
      if (_current(g) && _versions[key] == v) errors[key] = errorText(e);
      return false;
    } finally {
      if (_current(g) && _versions[key] == v) {
        busy.remove(key);
        _notify();
      }
    }
  }

  Future<bool> refreshPeople() => load('people', loadWorld, (w) {
    worldName = w.name;
    currentTime = w.currentTime;
    for (final c in w.characters) {
      String field(List<String> keys) => keys
          .map((k) => phoneText(c[k]))
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final id = field(['char_id', 'character_id', 'id']);
      if (id.isNotEmpty) {
        final p = PhonePerson(
          id,
          field(['name', 'char_name']),
          GenesisImageResource.fromJson(
            c['avatar_url'] ?? c['avatar'] ?? c['image'],
          ).displayUrl,
        );
        people[id] = p;
        final playerUid = field(['player_uid', 'user_id', 'uid']);
        if (playerUid.isNotEmpty) {
          playerCharIds.add(id);
          _peerByChar[id] = playerUid;
          users[playerUid] = PhonePerson(playerUid, p.name, p.avatar, type: 1);
        }
      }
    }
  });
  Future<bool> refreshSummary({int? preserveAfterRevision}) async {
    final revision = preserveAfterRevision ?? _cache.revision;
    final results = await Future.wait([
      load('home', () => api.home(worldId), (value) {
        home = value;
        _cache.rebaseHome(value, uid!, revision);
        for (final id in value.messages.map((m) => m.sessionId).toSet()) {
          _mergeMessages(
            id,
            value.messages.where((m) => m.sessionId == id).toList(),
          );
        }
        unawaited(_persistCache());
        for (final m in value.messages) {
          if (m.senderType == 'char') _sessionByChar[m.senderId] = m.sessionId;
        }
        for (final n in value.notifications) {
          if (n.actorType == 1) unawaited(resolveUser(n.actorId));
        }
      }),
      load('unread', () => api.unread(worldId), (value) => unread = value),
    ]);
    return results.every((v) => v);
  }

  Future<bool> refreshSessions({bool next = false}) {
    const key = 'sessions';
    final revision = _cache.revision;
    final pn = next ? (pages[key] ?? 1) + 1 : 1;
    return load(
      key,
      () => api.sessions(worldId, pn: pn, unreadOnly: unreadSessionsOnly),
      (page) {
        _cache.mergeSessions(
          page.list,
          next: next,
          requestedRevision: revision,
        );
        sessions = _cache.sessions;
        for (final s in page.list) {
          _rememberSession(s);
        }
        pages[key] = pn;
        hasMore[key] = page.hasMore;
        unawaited(_persistCache());
      },
    );
  }

  void _rememberSession(PhoneSession session) {
    _knownSessionChars.add(session.person.id);
    _peerByChar[session.person.id] = session.peerUid;
    if (session.id > 0) _sessionByChar[session.person.id] = session.id;
    people[session.person.id] = session.person;
  }

  int? sessionFor(String charId) => _sessionByChar[charId];
  PhonePerson person(String id, {int type = 2}) =>
      (type == 1 ? users[id] : people[id]) ??
      PhonePerson(
        id,
        type == 1 && id == uid ? 'You' : 'Unknown',
        '',
        type: type,
      );
  Future<void> resolveUser(String id) async {
    if (loadUser == null ||
        users.containsKey(id) ||
        busy.contains('user:$id')) {
      return;
    }
    await load('user:$id', () => loadUser!(id), (u) {
      users[id] = PhonePerson(id, u.nickname, u.avatar, type: 1);
    });
  }

  List<PhoneMessage> history(String charId) =>
      messages[sessionFor(charId)] ?? const [];
  bool unresolved(String key) =>
      pending[key] != null && !pending[key]!.rejected;
  PhoneWrite? waiting(String charId) =>
      unresolved('dm:$charId') ? pending['dm:$charId'] : null;
  bool _terminal(String? state) => state == 'completed' || state == 'failed';

  void _applyReplyState(
    String requestId,
    String status,
    String? failure,
    int sessionId,
  ) {
    final previous = _replyStates[requestId];
    if (_terminal(previous?.status) &&
        _appliedReplyTerminals.contains(requestId)) {
      return;
    }
    final state =
        _terminal(previous?.status) ||
            previous?.status == 'generating' && status == 'pending'
        ? previous!
        : (status: status, failure: failure);
    _replyStates[requestId] = state;
    String? charId;
    for (final entry in _sessionByChar.entries) {
      if (entry.value == sessionId) charId = entry.key;
    }
    for (final w in pending.values.toList()) {
      if (w.kind == 'dm' && w.id == requestId) charId = w.target;
    }
    if (charId == null || isPlayerChat(charId)) return;
    _sessionByChar[charId] = sessionId;
    final key = 'dm:$charId';
    final write = pending[key];
    if (_terminal(state.status)) {
      _appliedReplyTerminals.add(requestId);
      if (write?.id == requestId) pending.remove(key);
      if (state.status == 'failed' &&
          (write == null || write.id == requestId)) {
        replyFailures[charId] = state.failure ?? 'Reply generation failed.';
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

  void _mergeMessages(int id, List<PhoneMessage> incoming) {
    final all = <int, PhoneMessage>{
      for (final m in messages[id] ?? <PhoneMessage>[]) m.id: m,
    };
    for (final m in incoming) {
      final old = all[m.id];
      final state = _replyStates[m.requestId];
      final preserve = _terminal(state?.status)
          ? state
          : _terminal(old?.replyStatus)
          ? (status: old!.replyStatus!, failure: old.failure)
          : null;
      all[m.id] =
          preserve != null && m.senderType == 'user' && m.senderId == uid
          ? PhoneMessage.withReplyState(m, preserve.status, preserve.failure)
          : m;
      if (m.senderType == 'char') _sessionByChar[m.senderId] = id;
      if (m.senderType == 'user' && m.senderId == uid && m.requestId != null) {
        _outgoingDm.remove(m.requestId);
        for (final w in pending.values.toList()) {
          if (w.id == m.requestId && w.kind == 'dm') {
            _sessionByChar[w.target] = id;
            w.accepted = true;
            w.rejected = false;
            if (isPlayerChat(w.target)) pending.remove(w.key);
          }
        }
      }
    }
    _cache.merge(all.values);
    messages[id] = [for (final id in all.keys) _cache.messages[id]!]
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final m in messages[id]!) {
      if (m.senderType == 'user' &&
          m.senderId == uid &&
          m.requestId != null &&
          m.replyStatus != null) {
        _applyReplyState(m.requestId!, m.replyStatus!, m.failure, id);
      }
    }
    _cache.merge(messages[id]!);
    unawaited(_persistCache());
    _scheduleReplyPoll();
  }

  Future<bool> _resolveSession(String charId) async {
    if (sessionFor(charId) != null ||
        _knownSessionChars.contains(charId) && !unresolved('dm:$charId')) {
      return true;
    }
    final g = _generation;
    return load(
      'session:$charId',
      () async {
        var pn = 1;
        while (_current(g)) {
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
          _rememberSession(session);
        }
      },
    );
  }

  Future<bool> refreshMessages(String charId, {bool next = false}) async {
    final generation = _generation;
    final journalBefore = jsonEncode(
      pending.values.map((w) => w.toJson()).toList(),
    );
    if (!await _resolveSession(charId) || !_current(generation)) return false;
    final id = sessionFor(charId);
    if (id == null) return true;
    if (next && (messages[id]?.isNotEmpty ?? false)) {
      final before = messages[id]!.first.id;
      final scope = _cacheScope;
      var cached = _cache.history(id).where((m) => m.id < before).toList();
      if (scope != null && _cacheCanSave) {
        try {
          await cacheSaved;
          final stored = await cacheStorage.loadBefore(scope, id, before, 50);
          if (!_current(generation)) return false;
          final byId = {
            for (final m in [...stored, ...cached]) m.id: m,
          };
          cached = byId.values.toList();
        } catch (_) {
          if (!_current(generation)) return false;
          errors['cache'] = 'Unable to load saved messages. Please try again.';
        }
      }
      if (cached.isNotEmpty) {
        cached.sort((a, b) => b.id.compareTo(a.id));
        _mergeMessages(id, cached.take(50).toList());
        hasMore['messages:$id'] = true;
        _notify();
        return true;
      }
    }
    final key = 'messages:$id',
        pn = next ? (pages['messages:$id'] ?? 1) + 1 : 1;
    final known = messages[id]?.map((m) => m.id).toSet() ?? <int>{};
    final g = _generation;
    final ok = await load(
      key,
      () async {
        var page = await api.messages(worldId, id, pn: pn);
        final recovered = <PhoneMessage>[...page.list];
        if (next && known.isNotEmpty) {
          final oldest = known.reduce((a, b) => a < b ? a : b);
          while (page.hasMore &&
              !page.list.any((m) => m.id < oldest) &&
              _current(g)) {
            page = await api.messages(worldId, id, pn: page.pn + 1);
            recovered.addAll(page.list);
          }
        }
        // Recover a missed run of messages, not just the newest ten bubbles.
        while (!next &&
            known.isNotEmpty &&
            page.hasMore &&
            !page.list.any((m) => known.contains(m.id)) &&
            _current(g)) {
          page = await api.messages(worldId, id, pn: page.pn + 1);
          recovered.addAll(page.list);
        }
        return PhonePage(recovered, page.total, page.pn, page.rn);
      },
      (page) {
        _mergeMessages(id, page.list);
        pages[key] = page.pn;
        final oldest = messages[id]?.firstOrNull?.id;
        hasMore[key] =
            page.hasMore ||
            oldest != null && _cache.history(id).any((m) => m.id < oldest);
      },
    );
    if (ok &&
        _current(generation) &&
        journalBefore !=
            jsonEncode(pending.values.map((w) => w.toJson()).toList())) {
      unawaited(_save().catchError((Object _) {}));
    }
    if (!_current(generation)) return false;
    if (ok && !next && activeCharId == charId && foreground && phoneVisible) {
      await markSessionRead(id);
    }
    return ok;
  }

  final _reads = <int, Future<void>>{};
  Future<void> markSessionRead(int id, {bool newDelivery = false}) {
    if (id <= 0 || !_hydrated) return Future<void>.value();
    _cache.markRead(id);
    sessions = [
      for (final s in sessions)
        s.id == id ? PhoneSession.withUnreadCount(s, 0) : s,
    ];
    final saved = _persistCache();
    _notify();
    return _syncRead(id, saved: saved);
  }

  Future<void> _syncRead(int id, {Future<bool>? saved}) {
    final existing = _reads[id];
    if (existing != null) return existing;
    final g = _generation;
    return _reads[id] =
        (() async {
          if (saved != null && !await saved) return;
          while (_current(g)) {
            final intent = _cache.pendingReads[id];
            if (intent == null) break;
            // Durable before submission: reopening can retry an interrupted receipt.
            if (!await _persistCache() || !_current(g)) return;
            final ok = await load(
              'read:$id',
              () => api.readSession(id),
              (_) {},
            );
            if (!_current(g) || !ok) break;
            _cache.acknowledgeRead(id, intent.revision);
            await _persistCache();
            if (!_current(g)) return;
            await refreshSummary(preserveAfterRevision: intent.revision);
            if (!_current(g)) return;
          }
        })().whenComplete(() {
          if (_current(g)) _reads.remove(id);
        });
  }

  Future<void> _retryPendingReads() async {
    final g = _generation;
    for (final id in _cache.pendingReads.keys.toList()) {
      if (!_current(g)) return;
      await _syncRead(id);
    }
  }

  Future<bool> refreshPostAuthors() => load(
    'postAuthors',
    () => api.postAuthors(worldId),
    (ids) => postAuthorIds = ids,
  );

  Future<bool> refreshPosts({bool next = false, bool markRead = false}) async {
    if (next && (busy.contains('posts') || hasMore['posts'] != true)) {
      return false;
    }
    if (markRead) _postReadOnLoad = true;
    final authorsRefresh = next ? null : refreshPostAuthors();
    final pn = next ? (pages['posts'] ?? 1) + 1 : 1;
    final ok = await load(
      'posts',
      () => api.posts(worldId, pn: pn, charId: authorFilter),
      (page) {
        posts = <int, PhonePost>{
          if (next)
            for (final p in posts) p.id: p,
          for (final p in page.list) p.id: p,
        }.values.toList();
        for (final p in page.list) {
          // A fresh feed supersedes interaction details cached before entry.
          details.remove(p.id);
          if (p.author.type == 1) users[p.author.id] = p.author;
        }
        pages['posts'] = pn;
        hasMore['posts'] = page.hasMore;
      },
    );
    if (ok && _postReadOnLoad && postsVisible && phoneVisible && foreground) {
      _postReadOnLoad = false;
      final read = await load(
        'readPosts',
        () => api.readPosts(worldId),
        (_) {},
      );
      if (read) {
        await refreshSummary();
        if (notificationsVisible) await refreshNotifications();
      }
    }
    await authorsRefresh;
    return ok;
  }

  Future<bool> refreshDetail(int id) =>
      load('detail:$id', () => api.detail(worldId, id), (d) => details[id] = d);
  Future<bool> refreshComments(int id, {bool next = false}) {
    final key = 'comments:$id',
        pn = next ? (pages['comments:$id'] ?? 1) + 1 : 1;
    return load(key, () => api.comments(worldId, id, pn: pn), (page) {
      comments[id] = <int, PhoneComment>{
        if (next)
          for (final c in comments[id] ?? <PhoneComment>[]) c.id: c,
        for (final c in page.list) c.id: c,
      }.values.toList();
      pages[key] = pn;
      hasMore[key] = page.hasMore;
    });
  }

  Future<bool> refreshNotifications({int pn = 1}) => load(
    'notifications',
    () =>
        api.notifications(worldId, pn: pn, unreadOnly: unreadNotificationsOnly),
    (page) {
      notifications = page;
      for (final n in page.list) {
        if (n.actorType == 1) unawaited(resolveUser(n.actorId));
      }
    },
  );
  Future<bool> refreshAlbum({bool next = false}) {
    final pn = next ? (pages['album'] ?? 1) + 1 : 1;
    return load('album', () => api.album(worldId, pn: pn), (page) {
      album = <int, PhoneAlbumAsset>{
        if (next)
          for (final a in album) a.id: a,
        for (final a in page.list) a.id: a,
      }.values.toList();
      pages['album'] = pn;
      hasMore['album'] = page.hasMore;
    });
  }

  Future<bool> write(
    String kind,
    String target,
    String content, {
    String? image,
    int? replyTo,
    bool retry = false,
  }) async {
    await ready;
    if (_disposed || uid == null || content.trim().isEmpty) return false;
    final key = '$kind:$target', g = _generation;
    if (busy.contains(key)) return false;
    final existing = pending[key];
    if (existing != null && !existing.rejected && !retry) {
      errors[key] = 'The previous request is still awaiting confirmation.';
      _notify();
      return false;
    }
    final reuse =
        existing != null &&
        (retry ||
            existing.content == content &&
                existing.image == image &&
                existing.replyTo == replyTo);
    final w =
        (reuse ? existing : null) ??
        PhoneWrite(
          const Uuid().v4(),
          kind,
          target,
          content,
          image: image,
          replyTo: replyTo,
        );
    pending[key] = w;
    if (kind == 'dm' &&
        !history(target).any(
          (m) =>
              m.senderType == 'user' &&
              m.senderId == uid &&
              m.requestId == w.id,
        )) {
      _outgoingDm[w.id] = w;
    }
    w.rejected = false;
    busy.add(key);
    errors.remove(key);
    replyFailures.remove(target);
    _notify();
    try {
      await _save();
      if (!_current(g)) return false;
      switch (kind) {
        case 'dm':
          await api.send(worldId, target, w.id, w.content);
        case 'post':
          await api.createPost(worldId, w.id, w.content, image: w.image);
        case 'comment':
          await api.comment(
            worldId,
            int.parse(target),
            w.id,
            w.content,
            replyToCommentId: w.replyTo,
          );
        default:
          throw StateError('Unsupported write');
      }
      if (!_current(g)) return false;
      w.accepted = true;
      if (kind != 'dm') pending.remove(key);
      await _save();
      if (!_current(g)) return false;
      if (kind == 'dm') scheduleRefresh(refreshHome: false);
      if (kind == 'post') await refreshSummary();
      if (kind == 'comment') {
        await Future.wait([
          refreshDetail(int.parse(target)),
          refreshComments(int.parse(target)),
        ]);
      }
      return true;
    } catch (e) {
      if (!_current(g)) return false;
      // A delivery can precede an HTTP failure. Committed evidence wins.
      if (!w.accepted) {
        errors[key] = errorText(e);
        if (e is ArgumentError || e is FormatException) {
          w.rejected = true;
        } else if (e is ApiException && e.kind == ApiExceptionKind.business) {
          if (e.code == 2062 && kind == 'dm') {
            w.uncertain = true;
            scheduleRefresh();
          } else {
            w.rejected = true;
          }
        } else {
          w.uncertain = true;
        }
        if (kind == 'dm' && w.rejected) _outgoingDm.remove(w.id);
        await _save();
      }
      return w.accepted;
    } finally {
      if (_current(g)) {
        busy.remove(key);
        _notify();
      }
    }
  }

  final _likeIntent = <int, bool>{};
  final likeTargets = <int, bool>{};
  final _likeRunning = <int>{};
  Future<void> setLiked(int id, bool liked) async {
    _likeIntent[id] = liked;
    likeTargets[id] = liked;
    _notify();
    if (!_likeRunning.add(id)) return;
    final g = _generation;
    try {
      while (_current(g) && _likeIntent.containsKey(id)) {
        final desired = _likeIntent.remove(id)!;
        final ok = await load(
          'like:$id',
          () => desired ? api.like(worldId, id) : api.unlike(worldId, id),
          (_) {},
        );
        if (!_current(g)) return;
        final queried = await refreshDetail(id);
        if (!ok && !queried) {
          _likeIntent.remove(id);
          return;
        }
        // Only a newer user intent may run after an uncertain operation.
        if (_likeIntent[id] == details[id]?.isLiked) _likeIntent.remove(id);
      }
    } finally {
      if (_current(g)) {
        _likeRunning.remove(id);
        likeTargets.remove(id);
        _notify();
      }
    }
  }

  void attach(WorldChatroomService service) {
    _events?.cancel();
    _states?.cancel();
    final generation = _generation;
    _events = service.phoneEvents.listen((event) {
      if (_current(generation)) receive(event);
    });
    _wasConnected = false;
    _states = service.states.listen((state) {
      if (!_current(generation)) return;
      if (state.connected && !_wasConnected) scheduleRefresh();
      if (!state.connected && _wasConnected && pending.isNotEmpty) {
        for (final write in pending.values) {
          if (write.kind == 'dm' && !write.rejected) write.uncertain = true;
        }
        unawaited(_save().catchError((Object _) {}));
        _notify();
      }
      _wasConnected = state.connected;
      if (state.latestSocketCurrentTime.isNotEmpty &&
          currentTime != state.latestSocketCurrentTime) {
        currentTime = state.latestSocketCurrentTime;
        _notify();
      }
    });
  }

  void receive(ChatroomPhoneEvent event) {
    if (_disposed || event.worldId != worldId) return;
    if (!_hydrated) {
      _earlyEvents.add(event);
      return;
    }
    if (uid == null || !_cache.acceptEvent(event.eventId)) return;
    if (event.type == 'phone.messages.delivered') {
      _cache.delivered(event.messages, uid!);
      _mergeMessages(event.sessionId!, event.messages);
      for (final w in pending.values.toList()) {
        if (w.kind != 'dm') continue;
        final related =
            event.requestId == w.id ||
            event.messages.any((m) => m.requestId == w.id);
        if (related) {
          _sessionByChar[w.target] = event.sessionId!;
          w.accepted = true;
          w.rejected = false;
          if (isPlayerChat(w.target) &&
              event.messages.any(
                (m) =>
                    m.senderType == 'user' &&
                    m.senderId == uid &&
                    m.requestId == w.id,
              )) {
            pending.remove(w.key);
          } else if (event.requestId == w.id &&
              event.messages.any((m) => m.senderType == 'char')) {
            _applyReplyState(w.id, 'completed', null, event.sessionId!);
          }
        }
      }
      if (foreground &&
          phoneVisible &&
          activeCharId != null &&
          sessionFor(activeCharId!) == event.sessionId) {
        unawaited(markSessionRead(event.sessionId!, newDelivery: true));
      }
      // A complete correlated AI batch can precede both HTTP and its source message.
      if (event.requestId != null &&
          event.messages.any((m) => m.senderType == 'char')) {
        _applyReplyState(event.requestId!, 'completed', null, event.sessionId!);
      }
    } else if (event.type == 'phone.reply.updated') {
      _applyReplyState(
        event.requestId!,
        event.jobStatus!,
        event.failure,
        event.sessionId!,
      );
      final source = _cache.messages[event.sourceMessageId];
      final reply = _replyStates[event.requestId];
      if (source != null && reply != null && source.senderId == uid) {
        _cache.merge([
          PhoneMessage.withReplyState(source, reply.status, reply.failure),
        ]);
      }
      final history = messages[event.sessionId];
      if (history != null) {
        final state = _replyStates[event.requestId]!;
        messages[event.sessionId!] = [
          for (final m in history)
            if (m.id == event.sourceMessageId && m.senderId == uid)
              PhoneMessage.withReplyState(m, state.status, state.failure)
            else
              m,
        ];
      }
    }
    if (event.sessionId != null && messages[event.sessionId] != null) {
      _cache.merge(messages[event.sessionId]!);
    }
    unawaited(_persistCache());
    unawaited(_save().catchError((Object _) {}));
    _notify();
    // DM delivery already updates the local inbox; do not immediately replace
    // it with a potentially lagging Home snapshot after every push.
    if (event.type == 'phone.post.notification.created') scheduleRefresh();
  }

  void scheduleRefresh({bool refreshHome = true}) {
    if (_disposed) return;
    _dirty = true;
    _refreshHome = _refreshHome || refreshHome;
    _refreshTimer ??= Timer(const Duration(milliseconds: 180), () {
      _refreshTimer = null;
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    final g = _generation;
    try {
      while (_dirty && _current(g)) {
        _dirty = false;
        final refreshHome = _refreshHome;
        _refreshHome = false;
        await _retryPendingReads();
        if (!_current(g)) return;
        if (refreshHome) await refreshSummary();
        if (!_current(g)) return;
        // Recover known chats without using app-list endpoints for discovery.
        // Unknown session IDs are resolved on explicit chat entry or delivery.
        final targets = <String>{
          if (phoneVisible &&
              activeCharId != null &&
              sessionFor(activeCharId!) != null)
            activeCharId!,
          for (final write in pending.values)
            if (write.kind == 'dm' &&
                !write.rejected &&
                sessionFor(write.target) != null)
              write.target,
        };
        await Future.wait(targets.map(refreshMessages));
        if (!_current(g)) return;
        await Future.wait([
          for (final write in pending.values.toList())
            if (write.kind == 'dm' && !write.rejected) _recoverRequest(write),
        ]);
      }
    } finally {
      _refreshing = false;
      if (_dirty && !_disposed) scheduleRefresh(refreshHome: _refreshHome);
      _scheduleReplyPoll();
    }
  }

  void _scheduleReplyPoll() {
    if (_disposed || !foreground) return;
    final writes = pending.values.where(
      (w) => w.kind == 'dm' && !w.rejected && !isPlayerChat(w.target),
    );
    if (writes.isEmpty) {
      _replyPollTimer?.cancel();
      _replyPollTimer = null;
      _replyPollSeconds = 2;
      return;
    }
    if (_replyPollTimer != null) return;
    _replyPollTimer = Timer(Duration(seconds: _replyPollSeconds), () async {
      _replyPollTimer = null;
      if (_disposed || !foreground) return;
      _replyPollSeconds = (_replyPollSeconds * 2).clamp(2, 30);
      final generation = _generation;
      for (final write in writes.toList()) {
        await _recoverRequest(write);
        if (!_current(generation)) return;
      }
      _scheduleReplyPoll();
    });
  }

  Future<void> _recoverRequest(PhoneWrite write) async {
    final generation = _generation;
    final id = sessionFor(write.target);
    if (id == null) return;
    await load(
      'request:${write.id}',
      () => api.messages(worldId, id, clientRequestId: write.id),
      (page) {
        _mergeMessages(id, page.list);
      },
    );
    if (_current(generation)) await _save();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      scheduleRefresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    accountRevision.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _replyPollTimer?.cancel();
    _events?.cancel();
    _states?.cancel();
    super.dispose();
  }
}

class MiniPhoneConversation {
  const MiniPhoneConversation(this.person, this.unreadCount, this.lastMessage);
  final PhonePerson person;
  final int unreadCount;
  final PhoneMessage? lastMessage;
}

class PhoneWrite {
  PhoneWrite(
    this.id,
    this.kind,
    this.target,
    this.content, {
    this.image,
    this.replyTo,
  });
  factory PhoneWrite.fromJson(Map<String, dynamic> j) =>
      PhoneWrite(
          j['id'] as String,
          j['kind'] as String,
          j['target'] as String,
          j['content'] as String,
          image: j['image'] as String?,
          replyTo: j['replyTo'] as int?,
        )
        ..accepted = j['accepted'] == true
        ..rejected = j['rejected'] == true
        ..uncertain = true;
  final String id, kind, target, content;
  final String? image;
  final int? replyTo;
  bool accepted = false, uncertain = false, rejected = false;
  String get key => '$kind:$target';
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'target': target,
    'content': content,
    'image': image,
    'replyTo': replyTo,
    'accepted': accepted,
    'rejected': rejected,
  };
}
