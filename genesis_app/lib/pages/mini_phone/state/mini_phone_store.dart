import '../../../l10n/genesis_l10n.dart';
import '../messages/mini_phone_messages_controller.dart';
export '../messages/mini_phone_messages_controller.dart'
    show MiniPhoneConversation;
import 'mini_phone_write.dart';
import 'mini_phone_analytics.dart';
export 'mini_phone_write.dart';
import '../posts/mini_phone_posts_controller.dart';
import '../photos/mini_phone_photos_controller.dart';
import 'mini_phone_requests.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../network/api_exception.dart';
import '../../../network/mini_phone/mini_phone_api.dart';
import '../../../network/mini_phone/mini_phone_cache.dart';
import '../../../network/mini_phone/mini_phone_cache_storage.dart';
import '../../../network/chatroom/chatroom_models.dart';
import '../../../network/chatroom/world_chatroom_service.dart';
import '../../../network/models/world.dart';
import '../../../network/models/user.dart';
import '../../../utils/genesis_image_resource.dart';

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
  late final analytics = MiniPhoneAnalytics(
    worldId: worldId,
    enabled: () => !_disposed && uid != null,
    generation: () => accountGeneration,
  );
  late final requests = MiniPhoneRequests(_notify);
  late final messagesController = MiniPhoneMessagesController(
    api: api,
    worldId: worldId,
    requests: requests,
    cacheStorage: cacheStorage,
    pending: pending,
    people: people,
    person: person,
    isHydrated: () => _hydrated,
    saveJournal: _save,
    refreshSummary: refreshSummary,
    scheduleReplyRecovery: _scheduleReplyPoll,
  );
  late final postsController = MiniPhonePostsController(
    api: api,
    worldId: worldId,
    requests: requests,
    users: users,
    resolveNotificationUsers: _resolveNotificationUsers,
    refreshPostSummary: refreshPostSummary,
  );
  late final photosController = MiniPhonePhotosController(
    api: api,
    worldId: worldId,
    requests: requests,
  );
  final MiniPhoneApi api;
  final MiniPhoneCacheStorage cacheStorage;
  Completer<void> _localReady = Completer<void>();
  Future<void> get localReady => _localReady.future;
  bool get isLocallyReady => _localReady.isCompleted;
  bool _hydrated = false;
  final _earlyEvents = <ChatroomPhoneEvent>[];
  List<PhoneMessage> get unreadMessages => messagesController.unreadMessages;
  int get dmUnreadCount => messagesController.dmUnreadCount;
  int get totalUnreadCount => dmUnreadCount + home.postUnread;
  String? get latestUnreadCharId => unreadMessages.isEmpty
      ? unread.charId
      : charForMessage(unreadMessages.first);

  Future<void> get cacheSaved => messagesController.cacheSaved;
  final String worldId, namespace;
  final Future<String?> Function() readUid;
  final Future<WorldDetail> Function() loadWorld;
  final Future<User> Function(String)? loadUser;
  final Listenable accountRevision;
  late Future<void> ready;
  String? get uid => requests.uid;
  set uid(String? value) => requests.uid = value;
  bool get _disposed => requests.disposed;
  set _disposed(bool value) => requests.disposed = value;
  bool get foreground => requests.foreground;
  set foreground(bool value) => requests.foreground = value;
  bool get phoneVisible => requests.phoneVisible;
  set phoneVisible(bool value) => requests.phoneVisible = value;
  int get _generation => requests.generation;
  set _generation(int value) => requests.generation = value;
  int get accountGeneration => _generation;
  String? get activeCharId => messagesController.activeCharId;
  set activeCharId(String? value) => messagesController.activeCharId = value;
  int? activePostId;
  bool albumVisible = false;
  bool get notificationsVisible => postsController.notificationsVisible;
  set notificationsVisible(bool value) =>
      postsController.notificationsVisible = value;
  bool get postsVisible => postsController.postsVisible;
  set postsVisible(bool value) => postsController.postsVisible = value;
  bool get unreadSessionsOnly => messagesController.unreadSessionsOnly;
  set unreadSessionsOnly(bool value) =>
      messagesController.unreadSessionsOnly = value;
  bool get unreadNotificationsOnly => postsController.unreadNotificationsOnly;
  set unreadNotificationsOnly(bool value) =>
      postsController.unreadNotificationsOnly = value;
  String? get authorFilter => postsController.authorFilter;
  set authorFilter(String? value) => postsController.authorFilter = value;

  PhoneHome home = const PhoneHome();
  PhoneUnread unread = const PhoneUnread(0, null);
  String worldName = '', currentTime = '';
  WorldMapStyle? mapStyle;
  bool worldDetailLoaded = false;
  final worldCoverImageKeys = <String>{};
  String get clockTime =>
      RegExp(
        r'\b(?:[01]?\d|2[0-3]):[0-5]\d\b',
      ).firstMatch(currentTime)?.group(0) ??
      '';
  String get worldDay {
    final match = RegExp(
      r'Day\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(currentTime);
    final day = int.tryParse(match?.group(1) ?? '');
    return day == null ? '' : GenesisL10n.current.miniPhoneWorldDay(day: day);
  }

  final people = <String, PhonePerson>{};
  final users = <String, PhonePerson>{};
  final playerCharIds = <String>{};
  List<String> get postAuthorIds => postsController.postAuthorIds;
  set postAuthorIds(List<String> value) =>
      postsController.postAuthorIds = value;
  List<PhonePerson>? _authors;
  List<String>? _authorIds;
  List<PhonePerson> get authors {
    if (_authors == null || !identical(_authorIds, postAuthorIds)) {
      _authorIds = postAuthorIds;
      _authors = List.unmodifiable(
        <String, PhonePerson>{
          ...people,
          for (final id in postAuthorIds)
            id: people[id] ?? PhonePerson(id, id, ''),
        }.values,
      );
    }
    return _authors!;
  }

  Iterable<PhonePerson> get contacts =>
      people.values.where((p) => !playerCharIds.contains(p.id));
  List<PhonePost> get posts => postsController.posts;
  set posts(List<PhonePost> value) => postsController.posts = value;
  List<PhoneAlbumAsset> get album => photosController.album;
  set album(List<PhoneAlbumAsset> value) => photosController.album = value;
  PhonePage<PhoneNotification>? get notifications =>
      postsController.notifications;
  set notifications(PhonePage<PhoneNotification>? value) =>
      postsController.notifications = value;
  Map<int, List<PhoneMessage>> get messages => messagesController.messages;
  Map<int, PhonePostDetail> get details => postsController.details;
  Map<int, List<PhoneComment>> get comments => postsController.comments;
  Map<String, int> get pages => requests.pages;
  Map<String, bool> get hasMore => requests.hasMore;
  Map<String, String> get errors => requests.errors;
  Set<String> get busy => requests.busy;
  Map<String, int> get _versions => requests.versions;
  final pending = <String, PhoneWrite>{};
  StreamSubscription<ChatroomPhoneEvent>? _events;
  StreamSubscription<WorldChatroomState>? _states;
  Timer? _refreshTimer;
  Timer? _replyPollTimer;
  int _replyPollSeconds = 2;
  bool _refreshing = false, _dirty = false, _refreshHome = false;
  bool _refreshChats = false, _postDirty = false, _postRefreshing = false;
  Timer? _postRefreshTimer;
  int? _replyPollingGeneration;
  Future<bool>? _summaryTask;
  bool _summaryAgain = false;
  int? _summaryRevision;
  int _postSummaryRevision = 0;
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
      e is ApiException ? e.message : GenesisL10n.current.miniPhoneLoadFailed;

  Future<void> _initialize() async {
    final g = _generation;
    String? owner;
    try {
      owner = await readUid();
    } catch (_) {
      if (_current(g)) {
        errors['identity'] = GenesisL10n.current.miniPhoneAccountFailed;
        if (!_localReady.isCompleted) _localReady.complete();
        _notify();
      }
      return;
    }
    if (!_current(g)) return;
    errors.remove('identity');
    uid = owner;
    if (owner == null || owner.isEmpty || worldId.isEmpty) {
      if (!_localReady.isCompleted) _localReady.complete();
      errors['home'] = GenesisL10n.current.miniPhoneOpenFromWorld;
      _notify();
      return;
    }
    messagesController.cacheScope = MiniPhoneCacheScope(
      namespace,
      owner,
      worldId,
    );
    final scope = messagesController.cacheScope!;
    try {
      await messagesController.cacheWrites[scope.key];
      final restored = await cacheStorage.load(scope);
      if (!_current(g)) return;
      messagesController.cache = restored;
      messagesController.cacheCanSave = true;
      messagesController.restoreCacheProjection();
    } catch (_) {
      if (!_current(g)) return;
      errors['cache'] = GenesisL10n.current.miniPhoneLoadDeviceMessagesFailed;
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
            messagesController.outgoing[write.id] = write;
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
    for (final m in messagesController.cache.messages.values) {
      if (m.senderType != 'user' || m.senderId != uid || m.requestId == null) {
        continue;
      }
      messagesController.outgoing.remove(m.requestId);
      for (final w in pending.values.toList()) {
        if (w.kind != 'dm' || w.id != m.requestId) continue;
        messagesController.sessionByChar[w.target] = m.sessionId;
        w.accepted = true;
        if (isPlayerChat(w.target)) pending.remove(w.key);
      }
      if (m.replyStatus != null) {
        messagesController.applyReplyState(
          m.requestId!,
          m.replyStatus!,
          m.failure,
          m.sessionId,
        );
      }
    }
    if (journalBeforeRestore !=
        jsonEncode(pending.values.map((w) => w.toJson()).toList())) {
      unawaited(_save());
    }
    _hydrated = true;
    if (!_localReady.isCompleted) _localReady.complete();
    final early = List<ChatroomPhoneEvent>.of(_earlyEvents);
    _earlyEvents.clear();
    for (final event in early) {
      receive(event);
    }
    _notify();
    if (_dirty || pending.isNotEmpty) {
      scheduleRefresh(
        refreshHome: _refreshHome,
        recoverChats: _refreshChats || pending.isNotEmpty,
      );
    }
    // Remote reconciliation must not hold the independently hydrated pages.
    await Future.wait([
      refreshSummary(),
      refreshPeople(),
      messagesController.retryPendingReads(),
    ]);
  }

  /// Retry only a failed identity read, preserving normal request scheduling.
  Future<void> retryInitialization() {
    if (_disposed || !errors.containsKey('identity')) return ready;
    errors.remove('identity');
    _localReady = Completer<void>();
    return ready = _initialize();
  }

  void _accountChanged() {
    requests.reset();
    if (!_localReady.isCompleted) _localReady.complete();
    _localReady = Completer<void>();
    _hydrated = messagesController.cacheCanSave = false;
    messagesController.cacheScope = null;
    messagesController.cache = MiniPhoneCache();
    _earlyEvents.clear();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _dirty = _refreshHome = _refreshChats = _postDirty = false;
    _refreshing = _postRefreshing = false;
    _postRefreshTimer?.cancel();
    _postRefreshTimer = null;
    _summaryTask = null;
    _summaryAgain = false;
    _summaryRevision = null;
    _postSummaryRevision = 0;
    _replyPollingGeneration = null;
    uid = null;
    postsController.reset();
    authorFilter = null;
    home = const PhoneHome();
    unread = const PhoneUnread(0, null);
    sessions = [];
    posts = [];
    album = [];
    worldCoverImageKeys.clear();
    mapStyle = null;
    worldDetailLoaded = false;
    currentTime = '';
    notifications = null;
    people.clear();
    _authors = null;
    users.clear();
    postAuthorIds = [];
    playerCharIds.clear();
    drafts.clear();
    messages.clear();
    details.clear();
    comments.clear();
    pending.clear();
    messagesController.outgoing.clear();
    replyFailures.clear();
    messagesController.sessionByChar.clear();
    messagesController.peerByChar.clear();
    messagesController.knownSessionChars.clear();
    messagesController.replyStates.clear();
    messagesController.appliedReplyTerminals.clear();
    _replyPollTimer?.cancel();
    _replyPollTimer = null;
    _replyPollSeconds = 2;
    pages.clear();
    hasMore.clear();
    errors.clear();
    busy.clear();
    _versions.clear();
    messagesController.reads.clear();
    likeTargets.clear();
    activeCharId = null;
    activePostId = null;
    _notify();
    ready = _initialize();
  }

  Future<bool> _save() {
    final key = _storageKey, g = _generation;
    final content = jsonEncode(pending.values.map((w) => w.toJson()).toList());
    final result = (_journalWrites[key] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          try {
            final prefs = await SharedPreferences.getInstance();
            if (!await prefs.setString(key, content)) {
              throw StateError('Phone request journal was not saved');
            }
            if (_current(g) && errors.remove('journal') != null) _notify();
            return true;
          } catch (_) {
            if (_current(g)) {
              errors['journal'] =
                  GenesisL10n.current.miniPhoneSaveRequestsFailed;
              _notify();
            }
            return false;
          }
        });
    _journalWrites[key] = result.then((_) {});
    return result;
  }

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

  Future<bool> refreshPeople() => load('people', loadWorld, (w) {
    _authors = null;
    worldName = w.name;
    mapStyle = w.mapStyle;
    worldDetailLoaded = true;
    worldCoverImageKeys
      ..clear()
      ..addAll(GenesisImageResourceRegistry.resolve(w.cover).keys);
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
          messagesController.peerByChar[id] = playerUid;
          users[playerUid] = PhonePerson(playerUid, p.name, p.avatar, type: 1);
        }
      }
    }
  });
  Future<bool> refreshSummary({int? preserveAfterRevision}) {
    if (_disposed) return Future.value(false);
    if (!foreground) {
      scheduleRefresh(recoverChats: false);
      return Future.value(false);
    }
    final existing = _summaryTask;
    if (existing != null) {
      if (preserveAfterRevision != null) {
        // A receipt completed after dispatch: one trailing snapshot must start
        // after the write, preserving everything newer than its read revision.
        _summaryAgain = true;
        _summaryRevision = _summaryRevision == null
            ? preserveAfterRevision
            : (_summaryRevision! < preserveAfterRevision
                  ? _summaryRevision
                  : preserveAfterRevision);
      }
      return existing;
    }
    _summaryRevision = preserveAfterRevision;
    final g = _generation;
    late final Future<bool> task;
    task =
        Future<bool>.microtask(() async {
          var ok = true;
          do {
            if (!_current(g) || !foreground) return false;
            _summaryAgain = false;
            final revision =
                _summaryRevision ?? messagesController.cache.revision;
            _summaryRevision = null;
            ok = await _readSummary(revision) && ok;
          } while (_current(g) && foreground && _summaryAgain);
          return ok;
        }).whenComplete(() {
          if (identical(_summaryTask, task)) _summaryTask = null;
        });
    _summaryTask = task;
    return task;
  }

  Future<bool> _readSummary(int revision) async {
    final postRevision = ++_postSummaryRevision;
    final results = await Future.wait([
      load('home', () => api.home(worldId), (value) {
        home = PhoneHome(
          dmUnread: value.dmUnread,
          messages: value.messages,
          postUnread: postRevision == _postSummaryRevision
              ? value.postUnread
              : home.postUnread,
          notifications: postRevision == _postSummaryRevision
              ? value.notifications
              : home.notifications,
        );
        messagesController.cache.rebaseHome(value, uid!, revision);
        for (final id in value.messages.map((m) => m.sessionId).toSet()) {
          messagesController.mergeMessages(
            id,
            value.messages.where((m) => m.sessionId == id).toList(),
          );
        }
        unawaited(messagesController.persistCache());
        for (final m in value.messages) {
          if (m.senderType == 'char') {
            messagesController.sessionByChar[m.senderId] = m.sessionId;
          }
        }
        _resolveNotificationUsers(home.notifications);
      }),
      load('unread', () => api.unread(worldId), (value) => unread = value),
    ]);
    return results.every((v) => v);
  }

  void _resolveNotificationUsers(List<PhoneNotification> items) {
    for (final n in items) {
      if (n.actorType == 1) unawaited(resolveUser(n.actorId));
    }
  }

  Future<bool> refreshPostSummary({bool afterWrite = false}) {
    if (_disposed) return Future.value(false);
    if (!foreground) {
      scheduleRefresh(
        refreshHome: false,
        recoverChats: false,
        postSummary: true,
      );
      return Future.value(false);
    }
    // This endpoint contains only Posts. Never rebase the DM inbox, query chat
    // history, retry read receipts or recover a DM because of a Posts event.
    late final int postRevision;
    return load(
      'postSummary',
      () {
        postRevision = ++_postSummaryRevision;
        return api.notifications(worldId, rn: 20, unreadOnly: true);
      },
      (page) {
        if (postRevision != _postSummaryRevision) return;
        home = PhoneHome(
          dmUnread: home.dmUnread,
          messages: home.messages,
          postUnread: page.total,
          notifications: page.list,
        );
        _resolveNotificationUsers(page.list);
      },
      deduplicate: !afterWrite,
    );
  }

  PhonePerson person(String id, {int type = 2}) =>
      (type == 1 ? users[id] : people[id]) ??
      PhonePerson(
        id,
        type == 1 && id == uid
            ? GenesisL10n.current.miniPhoneYou
            : GenesisL10n.current.miniPhoneUnknown,
        '',
        type: type,
      );
  Future<void> resolveUser(String id) async {
    if (!foreground ||
        loadUser == null ||
        users.containsKey(id) ||
        busy.contains('user:$id')) {
      return;
    }
    await load('user:$id', () => loadUser!(id), (u) {
      users[id] = PhonePerson(id, u.nickname, u.avatar, type: 1);
    });
  }

  Future<bool> refreshSessions({bool next = false}) =>
      messagesController.refreshSessions(next: next);
  int? sessionFor(String charId) => messagesController.sessionFor(charId);
  List<PhoneMessage> history(String charId) =>
      messagesController.history(charId);
  bool unresolved(String key) => messagesController.unresolved(key);
  PhoneWrite? waiting(String charId) => messagesController.waiting(charId);
  Future<bool> refreshMessages(String charId, {bool next = false}) =>
      messagesController.refreshMessages(charId, next: next);
  Future<void> markSessionRead(int id, {bool newDelivery = false}) =>
      messagesController.markSessionRead(id, newDelivery: newDelivery);
  Map<String, String> get drafts => messagesController.drafts;
  List<PhoneSession> get sessions => messagesController.sessions;
  set sessions(List<PhoneSession> value) => messagesController.sessions = value;
  List<MiniPhoneConversation> get conversations =>
      messagesController.conversations;
  Map<String, String> get replyFailures => messagesController.replyFailures;
  bool isPlayerChat(String charId) => messagesController.isPlayerChat(charId);
  PhonePerson personForMessage(PhoneMessage message) =>
      messagesController.personForMessage(message);
  String? charForMessage(PhoneMessage message) =>
      messagesController.charForMessage(message);
  Iterable<PhoneWrite> outgoingDm(String charId) =>
      messagesController.outgoingDm(charId);

  Future<bool> refreshPostAuthors() => postsController.refreshPostAuthors();
  Future<bool> refreshPosts({bool next = false, bool markRead = false}) =>
      postsController.refreshPosts(next: next, markRead: markRead);
  Future<bool> refreshDetail(
    int id, {
    bool afterWrite = false,
    bool onEntry = false,
  }) => postsController.refreshDetail(
    id,
    afterWrite: afterWrite,
    onEntry: onEntry,
  );
  Future<bool> refreshComments(
    int id, {
    bool afterWrite = false,
    bool onEntry = false,
  }) => postsController.refreshComments(
    id,
    afterWrite: afterWrite,
    onEntry: onEntry,
  );
  Future<bool> refreshNotifications({int pn = 1}) =>
      postsController.refreshNotifications(pn: pn);

  Future<bool> refreshAlbum({bool next = false}) =>
      photosController.refresh(next: next);

  Future<bool> write(
    String kind,
    String target,
    String content, {
    String? image,
    int? replyTo,
    bool retry = false,
    MiniPhoneAnalyticsAttempt? analyticsAttempt,
  }) async {
    await localReady;
    if (_disposed || uid == null || content.trim().isEmpty) return false;
    final key = '$kind:$target', g = _generation;
    if (busy.contains(key)) return false;
    final existing = pending[key];
    if (existing != null && !existing.rejected && !retry) {
      errors[key] = GenesisL10n.current.miniPhonePreviousRequestPending;
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
    final attempt =
        analyticsAttempt ??
        analytics.beginAttempt(
          kind == 'dm'
              ? 'dm_send'
              : kind == 'post'
              ? 'post_publish'
              : 'comment_send',
          target: target,
          source: kind == 'dm'
              ? 'chat'
              : kind == 'post'
              ? 'create'
              : 'comments',
          data: {
            'client_request_id': w.id,
            'is_retry': reuse,
            if (kind == 'dm') ...{
              'dm_session_id':
                  '${messagesController.sessionByChar[target] ?? 0}',
              'peer_type': messagesController.isPlayerChat(target)
                  ? 'player'
                  : 'ai',
            },
            if (kind == 'comment' && replyTo != null)
              'reply_to_comment_id': '$replyTo',
            if (kind == 'post') 'has_image': image?.isNotEmpty ?? false,
          },
        );
    attempt.data['client_request_id'] = w.id;
    var sent = false;
    pending[key] = w;
    if (kind == 'dm' &&
        !history(target).any(
          (m) =>
              m.senderType == 'user' &&
              m.senderId == uid &&
              m.requestId == w.id,
        )) {
      messagesController.outgoing[w.id] = w;
    }
    w.rejected = false;
    busy.add(key);
    errors.remove(key);
    replyFailures.remove(target);
    _notify();
    try {
      if (!await _save()) {
        if (_current(g)) w.uncertain = true;
        attempt.fail(StateError('journal'), sent: false, errorStage: 'journal');
        return false;
      }
      if (!_current(g)) return false;
      sent = true;
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
      attempt.finish('accepted');
      w.accepted = true;
      if (kind != 'dm') pending.remove(key);
      await _save();
      if (!_current(g)) return false;
      if (kind == 'dm') scheduleRefresh(refreshHome: false);
      if (kind == 'post') await refreshPostSummary(afterWrite: true);
      if (kind == 'comment') {
        await Future.wait([
          refreshDetail(int.parse(target), afterWrite: true),
          refreshComments(int.parse(target), afterWrite: true),
        ]);
      }
      return true;
    } catch (e) {
      if (!_current(g)) return false;
      attempt.fail(e, sent: sent, errorStage: sent ? 'request' : 'journal');
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
        if (kind == 'dm' && w.rejected) {
          messagesController.outgoing.remove(w.id);
        }
        await _save();
      }
      return w.accepted;
    } finally {
      if (_current(g)) {
        busy.remove(key);
        if (kind == 'dm' && !w.rejected) {
          scheduleRefresh(refreshHome: false);
        }
        _notify();
      }
    }
  }

  Map<int, bool> get likeTargets => postsController.likeTargets;
  Future<void> setLiked(int id, bool liked, {String? source}) {
    if (source != null && !_disposed) {
      analytics.event(
        'post_like',
        target: '$id',
        stage: liked ? 'like' : 'unlike',
        data: analytics.context(source),
      );
    }
    return postsController.setLiked(id, liked);
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
        unawaited(_save());
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
    if (uid == null || !messagesController.cache.acceptEvent(event.eventId)) {
      return;
    }
    if (event.type == 'phone.messages.delivered') {
      messagesController.cache.delivered(event.messages, uid!);
      messagesController.mergeMessages(event.sessionId!, event.messages);
      for (final w in pending.values.toList()) {
        if (w.kind != 'dm') continue;
        final related =
            event.requestId == w.id ||
            event.messages.any((m) => m.requestId == w.id);
        if (related) {
          messagesController.sessionByChar[w.target] = event.sessionId!;
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
            messagesController.applyReplyState(
              w.id,
              'completed',
              null,
              event.sessionId!,
            );
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
        messagesController.applyReplyState(
          event.requestId!,
          'completed',
          null,
          event.sessionId!,
        );
      }
    } else if (event.type == 'phone.reply.updated') {
      messagesController.applyReplyState(
        event.requestId!,
        event.jobStatus!,
        event.failure,
        event.sessionId!,
      );
      final source = messagesController.cache.messages[event.sourceMessageId];
      final reply = messagesController.replyStates[event.requestId];
      if (source != null && reply != null && source.senderId == uid) {
        messagesController.cache.merge([
          PhoneMessage.withReplyState(source, reply.status, reply.failure),
        ]);
      }
      final history = messages[event.sessionId];
      if (history != null) {
        final state = messagesController.replyStates[event.requestId]!;
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
      messagesController.cache.merge(messages[event.sessionId]!);
    }
    unawaited(messagesController.persistCache());
    unawaited(_save());
    _notify();
    // DM delivery already updates the local inbox; do not immediately replace
    // it with a potentially lagging Home snapshot after every push.
    if (event.type == 'phone.post.notification.created') {
      scheduleRefresh(
        refreshHome: false,
        recoverChats: false,
        postSummary: true,
      );
    }
  }

  void _schedulePostRefresh() {
    _postDirty = true;
    if (_disposed || !foreground || !_hydrated) return;
    _postRefreshTimer ??= Timer(const Duration(milliseconds: 180), () {
      _postRefreshTimer = null;
      unawaited(_refreshPostInbox());
    });
  }

  Future<void> _refreshPostInbox() async {
    if (_disposed || !foreground || _postRefreshing) return;
    final g = _generation;
    _postRefreshing = true;
    try {
      while (_postDirty && _current(g) && foreground) {
        _postDirty = false;
        await refreshPostSummary();
      }
    } finally {
      if (_current(g)) {
        _postRefreshing = false;
        if (_postDirty) _schedulePostRefresh();
      }
    }
  }

  void scheduleRefresh({
    bool refreshHome = true,
    bool recoverChats = true,
    bool postSummary = false,
  }) {
    if (_disposed) return;
    if (postSummary) _schedulePostRefresh();
    if (!refreshHome && !recoverChats) return;
    _dirty = true;
    _refreshHome = _refreshHome || refreshHome;
    _refreshChats = _refreshChats || recoverChats;
    if (foreground && errors.containsKey('identity')) {
      unawaited(retryInitialization());
    }
    if (!foreground || !_hydrated) return;
    _refreshTimer ??= Timer(const Duration(milliseconds: 180), () {
      _refreshTimer = null;
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_refreshing || _disposed || !foreground || !_hydrated) return;
    _refreshing = true;
    final g = _generation;
    var recoveredChats = false;
    try {
      while (_dirty && _current(g) && foreground) {
        _dirty = false;
        final summary = _refreshHome, chats = _refreshChats;
        _refreshHome = _refreshChats = false;
        recoveredChats = recoveredChats || chats;
        await Future.wait([
          if (summary) refreshSummary(),
          if (chats) messagesController.retryPendingReads(),
          if (chats &&
              phoneVisible &&
              activeCharId != null &&
              sessionFor(activeCharId!) != null)
            refreshMessages(activeCharId!),
          if (chats) _recoverPendingRequests(),
        ]);
      }
    } finally {
      if (_current(g)) {
        _refreshing = false;
        if (_dirty) {
          scheduleRefresh(
            refreshHome: _refreshHome,
            recoverChats: _refreshChats,
          );
        }
        if (recoveredChats) _scheduleReplyPoll();
      }
    }
  }

  Iterable<PhoneWrite> get _recoverableDms =>
      pending.values.where((w) => w.kind == 'dm' && !w.rejected);

  Future<bool> _discoverPendingSessions() => load('pendingSessions', () async {
    final g = _generation;
    final targets = _recoverableDms
        .where((w) => sessionFor(w.target) == null)
        .map((w) => w.target)
        .toSet();
    var pn = 1;
    while (targets.isNotEmpty && _current(g) && foreground) {
      final page = await api.sessions(worldId, pn: pn, unreadOnly: false);
      if (!_current(g) || !foreground) return false;
      for (final session in page.list) {
        if (session.id > 0 && targets.remove(session.person.id)) {
          messagesController.rememberSession(session);
        }
      }
      if (!page.hasMore) break;
      pn = page.pn + 1;
    }
    return true;
  }, (_) {});

  Future<bool> _recoverPendingRequests() => load('dmRecovery', () async {
    final g = _generation;
    if (_disposed || !foreground) return false;
    if (_recoverableDms.any((w) => sessionFor(w.target) == null)) {
      await _discoverPendingSessions();
      if (!_current(g)) return false;
      final failure = errors['pendingSessions'];
      for (final write in _recoverableDms) {
        if (sessionFor(write.target) == null && failure != null) {
          errors['session:${write.target}'] = failure;
        } else {
          errors.remove('session:${write.target}');
        }
      }
      _notify();
    }
    for (final write in _recoverableDms.toList()) {
      if (!_current(g) || !foreground) return false;
      await _recoverRequest(write);
    }
    return true;
  }, (_) {});

  void _scheduleReplyPoll() {
    if (_disposed || !foreground || _replyPollingGeneration == _generation) {
      return;
    }
    if (_recoverableDms.isEmpty) {
      _replyPollTimer?.cancel();
      _replyPollTimer = null;
      _replyPollSeconds = 2;
      return;
    }
    if (_replyPollTimer != null) return;
    final g = _generation;
    _replyPollTimer = Timer(Duration(seconds: _replyPollSeconds), () async {
      _replyPollTimer = null;
      if (!_current(g) || !foreground) return;
      _replyPollingGeneration = g;
      _replyPollSeconds = (_replyPollSeconds * 2).clamp(2, 30);
      try {
        await _recoverPendingRequests();
      } finally {
        if (_current(g)) {
          _replyPollingGeneration = null;
          _scheduleReplyPoll();
        }
      }
    });
  }

  Future<void> _recoverRequest(PhoneWrite write) async {
    final generation = _generation;
    final id = sessionFor(write.target);
    if (id == null ||
        !foreground ||
        pending[write.key]?.id != write.id ||
        write.rejected) {
      return;
    }
    final ok = await load(
      'request:${write.id}',
      () => api.messages(worldId, id, clientRequestId: write.id),
      (page) {
        messagesController.mergeMessages(id, page.list);
      },
    );
    if (!_current(generation)) return;
    await _save();
    if (ok &&
        _current(generation) &&
        foreground &&
        phoneVisible &&
        activeCharId == write.target) {
      await markSessionRead(id);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      scheduleRefresh();
      if (_postDirty) _schedulePostRefresh();
      unawaited(postsController.retryDeferredReads());
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _postRefreshTimer?.cancel();
      _postRefreshTimer = null;
      _replyPollTimer?.cancel();
      _replyPollTimer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    if (!_localReady.isCompleted) _localReady.complete();
    accountRevision.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _postRefreshTimer?.cancel();
    _replyPollTimer?.cancel();
    _events?.cancel();
    _states?.cancel();
    super.dispose();
  }
}
