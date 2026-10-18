part of 'location_chat_page.dart';

/// Read-only history projection. It never joins a room or publishes fetched
/// archive rows into the live service/reply queues.
class _LocationChatWorldHistory {
  _LocationChatWorldHistory(this.owner);
  final _LocationChatPanelState owner;
  // UI visit memory is scoped to the live service and account/world. Reading
  // history never changes it; returning to the map must not clear it.
  static final _lastVisited = Expando<Map<String, String>>();
  static String recordVisit(
    WorldChatroomService service,
    String worldId,
    String locationId,
  ) {
    final visits = _lastVisited[service] ??= <String, String>{};
    final scope = '${service.identity?.userId ?? ''}/$worldId';
    final previous = visits[scope] ?? service.state.joinedLocationId;
    visits[scope] = locationId;
    return previous;
  }

  final _pages = <String, List<WorldChatroomMessage>>{};
  final _more = <String, bool>{};
  final _cursors = <String, int>{};
  final _failed = <String>{};
  final _vmCache = <String, (Object, ChatMessageVm)>{};
  final _locations = <String, String>{};
  final _boundaryKeys = <String, GlobalKey>{};
  GlobalKey boundaryKey(String id) =>
      _boundaryKeys.putIfAbsent(id, GlobalKey.new);
  GlobalKey? existingBoundaryKey(String id) => _boundaryKeys[id];
  final _mergedTicks = <Object, (int, ChatMessageVm)>{};
  List<ChatMessageVm> _lastProjection = const [];
  int _generation = 0;
  Timer? _idleTimer;
  Timer? _retryTimer;
  int _retryAttempts = 0;
  Object? _sourceScope;
  DateTime? _retryAfter;
  bool _fillScheduled = false;
  bool _started = false;
  bool ready = false;
  bool loading = false;
  String readingLocationId = '';

  bool get enabled =>
      owner.widget.active &&
      owner.widget.isLeafLocation &&
      owner.widget.worldId.isNotEmpty &&
      owner.widget.previewContent == null;
  bool get hasMore =>
      !ready || _failed.isNotEmpty || _more.values.any((m) => m);

  // Suspend IO on exit, but preserve the rendered archive through the route
  // transition. Replacing it with the local queue changes scroll coordinates.
  void pause() {
    _generation++;
    _idleTimer?.cancel();
    _retryTimer?.cancel();
    // A deliberate re-entry may retry immediately; do not retain a cooldown
    // whose timer was canceled while the panel was inactive.
    _retryAfter = null;
    _started = false;
    loading = false;
    _fillScheduled = false;
  }

  void reset() {
    _generation++;
    _idleTimer?.cancel();
    _retryTimer?.cancel();
    _retryAttempts = 0;
    _pages.clear();
    _more.clear();
    _cursors.clear();
    _failed.clear();
    _vmCache.clear();
    _locations.clear();
    _boundaryKeys.clear();
    _mergedTicks.clear();
    _lastProjection = const [];
    _started = false;
    ready = false;
    loading = false;
    readingLocationId = '';
    _retryAfter = null;
    _fillScheduled = false;
  }

  void ensureStarted() {
    if (!enabled || owner._chatroomState.world == null) return;
    final scope = (
      owner._myUserId,
      owner._service,
      Object.hashAll(
        owner._chatroomState.historyGenerationByLocation.entries.map(
          (e) => (e.key, e.value),
        ),
      ),
    );
    if (_sourceScope != scope) {
      reset();
      _sourceScope = scope;
    }
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (owner.mounted && enabled) unawaited(loadOlder());
    });
  }

  List<String> get _leafIds => {
    owner.widget.locationId,
    ...owner._chatroomState.world!.processedLocationTree.flattened
        .where((node) => node.children.isEmpty)
        .map((node) => node.id)
        .where((id) => id.isNotEmpty),
  }.toList();

  // Server round order is authoritative across locations. Location cursors
  // are used only for per-location paging, never cross-location sorting.
  static int compareRaw(WorldChatroomMessage a, WorldChatroomMessage b) {
    var c = a.conversationRoundNumber.compareTo(b.conversationRoundNumber);
    if (c != 0) return c;
    // HTTP rows omit roundOrder; compare persistent IDs before live-only order.
    if (a.globalMessageId > 0 && b.globalMessageId > 0) {
      c = a.globalMessageId.compareTo(b.globalMessageId);
      if (c != 0) return c;
    }
    if (a.messageId > 0 && b.messageId > 0) {
      c = a.messageId.compareTo(b.messageId);
      if (c != 0) return c;
    }
    c = a.roundOrder.compareTo(b.roundOrder);
    return c != 0 ? c : a.locationId.compareTo(b.locationId);
  }

  WorldChatroomMessage? get _floor {
    WorldChatroomMessage? floor;
    for (final id in _pages.keys.where((id) => _more[id] == true)) {
      final rows = _pages[id]!;
      if (rows.isEmpty) continue;
      final oldest = rows.reduce((a, b) => compareRaw(a, b) <= 0 ? a : b);
      if (floor == null || compareRaw(oldest, floor) > 0) floor = oldest;
    }
    return floor;
  }

  Future<void> loadOlder() async {
    if (!enabled || loading || !hasMore || owner._chatroomState.world == null) {
      return;
    }
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) return;
    loading = true;
    final generation = _generation;
    final api = AppServicesScope.read(owner.context).api;
    final worldId = owner.widget.worldId;
    final floor = _floor;
    final ids = !ready
        ? _leafIds
              .where((id) => !_pages.containsKey(id) || _failed.contains(id))
              .toList()
        : _pages.keys
              .where(
                (id) =>
                    _failed.contains(id) ||
                    (_more[id] == true &&
                        (floor == null ||
                            _pages[id]!.isEmpty ||
                            compareRaw(
                                  _pages[id]!.reduce(
                                    (a, b) => compareRaw(a, b) <= 0 ? a : b,
                                  ),
                                  floor,
                                ) ==
                                0)),
              )
              .toList();
    owner._notifyMessageViewport(invalidateReplyProjection: false);
    var next = 0;
    Future<void> worker() async {
      while (next < ids.length && generation == _generation && owner.mounted) {
        final id = ids[next++];
        final cursor = _cursors[id] ?? 0;
        try {
          final page = await api.chatroomHttp.getMessages(
            worldId: worldId,
            locationId: id,
            since: cursor,
            limit: 30,
          );
          if (generation != _generation || !owner.mounted) return;
          final rows = page.messages
              .map(WorldChatroomMessage.fromHttpMessage)
              .toList();
          final positiveCursors = rows
              .map((m) => m.locationMessageId)
              .where((id) => id > 0);
          final oldest = positiveCursors.isEmpty
              ? 0
              : positiveCursors.reduce(math.min);
          if (page.hasMore &&
              (oldest == 0 || (cursor > 0 && oldest >= cursor))) {
            throw const FormatException('History cursor did not advance');
          }
          final merged = <String, WorldChatroomMessage>{
            for (final row in [...?_pages[id], ...rows]) _key(row): row,
          };
          _pages[id] = merged.values.toList()..sort(compareRaw);
          _cursors[id] = oldest > 0 ? oldest : cursor;
          _more[id] = page.hasMore;
          _failed.remove(id);
        } catch (error) {
          if (generation != _generation || !owner.mounted) return;
          _failed.add(id);
          debugPrint(
            '[WorldTimeline] history page failed for $id: ${error.runtimeType}',
          );
        }
      }
    }

    try {
      await Future.wait(
        List.generate(math.min(3, ids.length), (_) => worker()),
      );
    } finally {
      if (generation == _generation && owner.mounted) {
        ready = _leafIds.every(_pages.containsKey);
        loading = false;
        _retryTimer?.cancel();
        if (_failed.isEmpty) {
          _retryAfter = null;
          _retryAttempts = 0;
        } else {
          final delay = Duration(
            seconds: math.min(30, 2 * (1 << math.min(4, _retryAttempts++))),
          );
          _retryAfter = DateTime.now().add(delay);
          _retryTimer = Timer(delay + const Duration(milliseconds: 20), () {
            if (owner.mounted && enabled && generation == _generation) {
              unawaited(loadOlder());
            }
          });
        }
        owner._notifyMessageViewport(invalidateReplyProjection: false);
      }
    }
  }

  static String _key(WorldChatroomMessage m) => m.globalMessageId > 0
      ? 'g:${m.globalMessageId}'
      : '${m.locationId}:${m.messageId}:${m.locationMessageId}';
  static String _vmKey(ChatMessageVm m, String location) =>
      m.globalMessageId > 0
      ? 'g:${m.globalMessageId}'
      : (m.messageId ?? 0) > 0 || m.locationMessageId > 0
      ? '$location:${m.messageId ?? 0}:${m.locationMessageId}'
      : 'local:${m.localId}';

  ChatMessageVm? _parse(WorldChatroomMessage row) {
    if (!owner._messageVersionIsVisible(row)) return null;
    final key = _key(row);
    final identity = (
      row,
      owner._chatroomState.world,
      owner._chatroomState.entitiesById,
      owner._myUserId,
      owner._mySenderId,
      owner._userInfoRevisionListenable?.value,
    );
    if (_vmCache[key]?.$1 == identity) return _vmCache[key]!.$2;
    final index = _LocationChatTimelineIdentityIndex.fromState(
      owner._chatroomState,
      currentUserIds: owner._myUserIdKeys,
      currentSenderIds: owner._mySenderIdKeys,
    );
    final context = LocationChatMessageParseContext(
      currentLocationId: row.locationId,
      isMine: owner._isMineMessage,
      senderName: owner._messageSenderDisplayName,
      avatarUrl: owner._messageAvatarUrl,
      isPlayerControlledRole: owner._messageSenderIsPlayerControlledRole,
      characterName: index.characterName,
      locationName: index.locationName,
      locationExists: index.locationExists,
      isUserId: index.isUserId,
      roleName: index.roleName,
      roleIsAi: index.roleIsAi,
      roleAvatarUrl: index.roleAvatarUrl,
    );
    final p = owner._parserForMessage(row)?.parse(row, context);
    if (p == null) return null;
    final vm = ChatMessageVm(
      localId: 'world-history:$key',
      clientMsgId: p.clientMsgId,
      globalMessageId: p.globalMessageId,
      messageId: p.messageId,
      locationMessageId: p.locationMessageId,
      roundId: p.roundId,
      tickNo: p.tickNo,
      subTickNo: p.subTickNo,
      senderId: p.senderId,
      senderName: p.senderName,
      avatarUrl: p.avatarUrl,
      imageUrl: p.imageUrl,
      timelinePayload: p.timelinePayload,
      isPlayerControlledRole: p.isPlayerControlledRole,
      text: p.text,
      currentTime: p.currentTime,
      isMe: p.isMe,
      status: p.status,
      senderType: p.senderType,
      messageType: p.messageType,
      createdAt: p.createdAt,
    );
    _vmCache[key] = (identity, vm);
    return vm;
  }

  List<ChatMessageVm> project(List<ChatMessageVm> live) {
    ensureStarted();
    if (!enabled) return _lastProjection.isNotEmpty ? _lastProjection : live;
    if (!ready) return _projectTicks(live);
    final rawByKey = <String, WorldChatroomMessage>{
      for (final rows in _pages.values)
        for (final row in rows) _key(row): row,
      for (final rows in owner._chatroomState.messagesByLocation.values)
        for (final row in rows) _key(row): row,
    };
    final floor = _floor;
    final combined = <String, (ChatMessageVm, WorldChatroomMessage?)>{};
    _locations.clear();
    final presentations = [
      ...?owner._replyController?.statesFor(owner.widget.locationId),
      if (owner._renderedReplyState != null) owner._renderedReplyState!,
    ];
    final replacedReplyIds = {
      for (final state in presentations)
        if (state.showCardPresentation ||
            state.selectedCardAwaitingFormalHistory)
          for (final row in state.formalReplyMessages)
            if (row.globalMessageId > 0) row.globalMessageId,
    };
    final liveOrder = {
      for (var i = 0; i < live.length; i++) live[i].localId: i,
    };
    for (final row in rawByKey.values) {
      if (row.locationId == owner.widget.locationId &&
          replacedReplyIds.contains(row.globalMessageId)) {
        continue;
      }
      if (floor != null && compareRaw(row, floor) < 0) continue;
      final vm = _parse(row);
      if (vm == null) continue;
      combined[_key(row)] = (vm, row);
      _locations[vm.localId] = row.locationId;
    }
    for (final vm in live) {
      final key = _vmKey(vm, owner.widget.locationId);
      final raw = rawByKey[key];
      if (raw != null && floor != null && compareRaw(raw, floor) < 0) continue;
      // Keep local pending/candidate rows and their stable live identities.
      combined[vm.isAiContentDisclaimer ? vm.localId : key] = (vm, raw);
      _locations[vm.localId] = owner.widget.locationId;
    }
    final rows = combined.values.toList()
      ..sort((a, b) {
        if (a.$1.isAiContentDisclaimer) {
          return b.$1.isAiContentDisclaimer ? 0 : -1;
        }
        if (b.$1.isAiContentDisclaimer) return 1;
        final ai = liveOrder[a.$1.localId];
        final bi = liveOrder[b.$1.localId];
        if (ai != null && bi != null && a.$1.roundId == b.$1.roundId) {
          return ai.compareTo(bi);
        }
        if (a.$2 != null && b.$2 != null) return compareRaw(a.$2!, b.$2!);
        final ar = int.tryParse(a.$1.roundId) ?? 0;
        final br = int.tryParse(b.$1.roundId) ?? 0;
        if (ar > 0 && br > 0 && ar != br) return ar.compareTo(br);
        return a.$1.createdAt.compareTo(b.$1.createdAt);
      });
    final chronological = rows.map((r) => r.$1).toList();
    final projected = _projectTicks(
      _placeTicksInLocationSegments(chronological),
      tickSnapshots: chronological,
      chronology: {
        for (var i = 0; i < chronological.length; i++)
          chronological[i].localId: i,
      },
    );
    // Hidden versioned pages can otherwise leave no scrollable content from
    // which the user could request the next complete history window.
    if (projected.where((m) => !m.isAiContentDisclaimer).length < 12 &&
        hasMore &&
        !loading &&
        _failed.isEmpty &&
        !_fillScheduled) {
      _fillScheduled = true;
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!owner.mounted || generation != _generation) return;
        _fillScheduled = false;
        unawaited(loadOlder());
      });
    }
    final boundaries = <String>{
      if (owner._entrySectionMessageId != null) owner._entrySectionMessageId!,
      for (var i = 1; i < projected.length; i++)
        if (!projected[i].isAiContentDisclaimer &&
            !projected[i - 1].isAiContentDisclaimer &&
            locationFor(projected[i]) != locationFor(projected[i - 1]))
          projected[i].localId,
    };
    _boundaryKeys.removeWhere((id, _) => !boundaries.contains(id));
    if (!listEquals(projected, _lastProjection)) _lastProjection = projected;
    return _lastProjection;
  }

  String locationFor(ChatMessageVm message) =>
      _locations[message.localId] ?? owner.widget.locationId;

  void reading(String? id, {bool useJoinedLocation = false}) {
    if (!enabled || !ready || !owner.mounted) return;
    final location =
        useJoinedLocation ||
            !owner._scrollCoordinator.isReadingHistory ||
            owner._scrollCoordinator.isAtBottom
        ? owner.widget.locationId
        : _locations[id];
    if (location == null || location.isEmpty || location == readingLocationId) {
      onScroll();
      return;
    }
    owner._setLocationChatState(() => readingLocationId = location);
    onScroll();
  }

  void onScroll() {
    if (!enabled ||
        !owner._scrollController.hasClients ||
        loading ||
        !hasMore) {
      return;
    }
    final position = owner._scrollController.position;
    _idleTimer?.cancel();
    if (!owner._scrollCoordinator.isReadingHistory ||
        position.extentBefore >= 200) {
      return;
    }
    _idleTimer = Timer(const Duration(milliseconds: 180), () {
      if (!owner.mounted || !enabled || !owner._scrollController.hasClients) {
        return;
      }
      if (owner._scrollController.position.isScrollingNotifier.value) {
        onScroll();
      } else {
        unawaited(loadOlder());
      }
    });
  }

  ChatMentionEntry? get readingLocation =>
      readingLocationId.isEmpty || readingLocationId == owner.widget.locationId
      ? null
      : owner
            ._mentionCatalogForState(owner._chatroomState)
            .locations
            .where((l) => l.id == readingLocationId)
            .firstOrNull;
}
