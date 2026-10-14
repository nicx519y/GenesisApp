import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../network/api_exception.dart';
import '../../network/mini_phone/mini_phone_api.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/world.dart';
import '../../network/models/user.dart';
import '../../utils/genesis_image_resource.dart';

/// One world/account's server-backed phone. It never synthesizes messages or counts.
class MiniPhoneStore extends ChangeNotifier with WidgetsBindingObserver {
  MiniPhoneStore({
    required this.api,
    required this.worldId,
    required this.namespace,
    required this.readUid,
    required this.loadWorld,
    required this.accountRevision,
    this.loadUser,
  }) {
    accountRevision.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    ready = _initialize();
  }
  final MiniPhoneApi api;
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
  PhonePerson? authorFilter;
  PhoneHome home = const PhoneHome();
  PhoneUnread unread = const PhoneUnread(0, null);
  String worldName = '', currentTime = '';
  String get clockTime =>
      RegExp(
        r'\b(?:[01]?\d|2[0-3]):[0-5]\d\b',
      ).firstMatch(currentTime)?.group(0) ??
      '—';
  String get worldDay =>
      RegExp(
        r'Day\s+\d+',
        caseSensitive: false,
      ).firstMatch(currentTime)?.group(0) ??
      '';
  final people = <String, PhonePerson>{};
  final users = <String, PhonePerson>{};
  final playerCharIds = <String>{};
  final authors = <String, PhonePerson>{};
  Iterable<PhonePerson> get contacts =>
      people.values.where((p) => !playerCharIds.contains(p.id));
  final drafts = <String, String>{};
  List<PhoneSession> sessions = [];
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
  final _seenEvents = <String>{};
  final pending = <String, PhoneWrite>{};
  final replyFailures = <String, String>{};
  StreamSubscription<ChatroomPhoneEvent>? _events;
  StreamSubscription<WorldChatroomState>? _states;
  Timer? _refreshTimer;
  bool _refreshing = false, _dirty = false;
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
      errors['home'] = 'Sign in and open Mini phone from a World.';
      _notify();
      return;
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
        }
      }
    } catch (_) {
      /* A damaged local journal cannot replace server data. */
    }
    if (!_current(g)) return;
    await Future.wait([refreshSummary(), refreshSessions(), refreshPeople()]);
    if (_current(g) && pending.isNotEmpty) scheduleRefresh();
  }

  void _accountChanged() {
    _generation++;
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
    authors.clear();
    playerCharIds.clear();
    drafts.clear();
    messages.clear();
    details.clear();
    comments.clear();
    pending.clear();
    replyFailures.clear();
    _sessionByChar.clear();
    _seenEvents.clear();
    _likeIntent.clear();
    _likeRunning.clear();
    pages.clear();
    hasMore.clear();
    errors.clear();
    busy.clear();
    _versions.clear();
    _reads.clear();
    _readAgain.clear();
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
          users[playerUid] = PhonePerson(playerUid, p.name, p.avatar, type: 1);
          authors['1:$playerUid'] = users[playerUid]!;
        } else {
          authors[p.key] = p;
        }
      }
    }
  });
  Future<bool> refreshSummary() async {
    final results = await Future.wait([
      load('home', () => api.home(worldId), (value) {
        home = value;
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
    final pn = next ? (pages[key] ?? 1) + 1 : 1;
    return load(
      key,
      () => api.sessions(worldId, pn: pn, unreadOnly: unreadSessionsOnly),
      (page) {
        final merged = <int, PhoneSession>{
          if (next)
            for (final s in sessions) s.id: s,
          for (final s in page.list) s.id: s,
        };
        sessions = merged.values.toList();
        for (final s in page.list) {
          _sessionByChar[s.person.id] = s.id;
          people[s.person.id] = s.person;
        }
        pages[key] = pn;
        hasMore[key] = page.hasMore;
      },
    );
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
  void _mergeMessages(int id, List<PhoneMessage> incoming) {
    final all = <int, PhoneMessage>{
      for (final m in messages[id] ?? <PhoneMessage>[]) m.id: m,
      for (final m in incoming) m.id: m,
    };
    messages[id] = all.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final m in incoming) {
      if (m.senderType == 'char') _sessionByChar[m.senderId] = id;
      if (m.senderType == 'user' && m.requestId != null) {
        for (final w in pending.values) {
          if (w.id == m.requestId && w.kind == 'dm') {
            _sessionByChar[w.target] = id;
            w.accepted = true;
            w.rejected = false;
          }
        }
      }
    }
  }

  Future<bool> _resolveSession(String charId) async {
    if (sessionFor(charId) != null) return true;
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
          _sessionByChar[charId] = session.id;
          people[charId] = session.person;
        }
      },
    );
  }

  Future<bool> refreshMessages(String charId, {bool next = false}) async {
    final generation = _generation;
    if (!await _resolveSession(charId) || !_current(generation)) return false;
    final id = sessionFor(charId);
    if (id == null) return true;
    final key = 'messages:$id',
        pn = next ? (pages['messages:$id'] ?? 1) + 1 : 1;
    final known = messages[id]?.map((m) => m.id).toSet() ?? <int>{};
    final g = _generation;
    final ok = await load(
      key,
      () async {
        var page = await api.messages(worldId, id, pn: pn);
        final recovered = <PhoneMessage>[...page.list];
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
        hasMore[key] = page.hasMore;
      },
    );
    if (ok && !next && activeCharId == charId && foreground && phoneVisible) {
      await markSessionRead(id);
    }
    return ok;
  }

  final _reads = <int, Future<void>>{};
  final _readAgain = <int>{};
  Future<void> markSessionRead(int id, {bool newDelivery = false}) {
    if (newDelivery && _reads.containsKey(id)) _readAgain.add(id);
    final g = _generation;
    return _reads[id] ??=
        (() async {
          do {
            _readAgain.remove(id);
            await _readSession(id);
          } while (_current(g) &&
              _readAgain.contains(id) &&
              phoneVisible &&
              foreground &&
              sessionFor(activeCharId ?? '') == id);
        })().whenComplete(() {
          if (_current(g)) _reads.remove(id);
        });
  }

  Future<void> _readSession(int id) async {
    final ok = await load('read:$id', () => api.readSession(id), (_) {});
    if (ok) await Future.wait([refreshSessions(), refreshSummary()]);
  }

  Future<bool> refreshPosts({bool next = false, bool markRead = false}) async {
    if (markRead) _postReadOnLoad = true;
    final pn = next ? (pages['posts'] ?? 1) + 1 : 1;
    final ok = await load(
      'posts',
      () => api.posts(worldId, pn: pn, author: authorFilter),
      (page) {
        posts = <int, PhonePost>{
          if (next)
            for (final p in posts) p.id: p,
          for (final p in page.list) p.id: p,
        }.values.toList();
        for (final p in page.list) {
          authors[p.author.key] = p.author;
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
      if (kind == 'post') await refreshPosts();
      if (kind == 'comment') {
        await Future.wait([
          refreshDetail(int.parse(target)),
          refreshComments(int.parse(target)),
          refreshPosts(),
        ]);
      }
      return true;
    } catch (e) {
      if (!_current(g)) return false;
      // A delivery can precede an HTTP failure. Committed evidence wins.
      if (!w.accepted) {
        errors[key] = errorText(e);
        if (e is ApiException && e.kind == ApiExceptionKind.business) {
          w.rejected = true;
        } else {
          w.uncertain = true;
        }
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
      if (_current(g)) await refreshPosts();
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
    if (_disposed ||
        uid == null ||
        event.worldId != worldId ||
        !_seenEvents.add(event.eventId)) {
      return;
    }
    if (_seenEvents.length > 2000) _seenEvents.remove(_seenEvents.first);
    if (event.type == 'phone.messages.delivered') {
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
          if (event.requestId == w.id &&
              event.messages.any((m) => m.senderType == 'char')) {
            pending.remove(w.key);
          }
        }
      }
      if (foreground &&
          phoneVisible &&
          activeCharId != null &&
          sessionFor(activeCharId!) == event.sessionId) {
        unawaited(markSessionRead(event.sessionId!, newDelivery: true));
      }
    } else if (event.type == 'phone.reply.updated') {
      for (final w in pending.values.toList()) {
        if (w.kind == 'dm' && w.id == event.requestId) {
          pending.remove(w.key);
          replyFailures[w.target] = event.failure!;
        }
      }
    }
    unawaited(_save().catchError((Object _) {}));
    _notify();
    scheduleRefresh();
  }

  void scheduleRefresh() {
    if (_disposed) return;
    _dirty = true;
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
        await Future.wait([
          refreshSummary(),
          refreshSessions(),
          if (postsVisible) refreshPosts(),
          if (activePostId != null) refreshDetail(activePostId!),
          if (notificationsVisible)
            refreshNotifications(pn: notifications?.pn ?? 1),
        ]);
        if (!_current(g)) return;
        // A first send can create its session while the connection is down.
        // Resolve session IDs before reading history, including older pages.
        final targets = <String>{
          if (phoneVisible && activeCharId != null) activeCharId!,
          for (final write in pending.values)
            if (write.kind == 'dm' && !write.rejected) write.target,
        };
        await Future.wait(targets.map(refreshMessages));
      }
    } finally {
      _refreshing = false;
      if (_dirty && !_disposed) scheduleRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      scheduleRefresh();
      unawaited(refreshPeople());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    accountRevision.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _events?.cancel();
    _states?.cancel();
    super.dispose();
  }
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
