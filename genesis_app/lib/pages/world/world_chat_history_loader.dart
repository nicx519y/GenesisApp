part of '../chat/location_chat_page.dart';

/// Read-only history projection. It never joins a room or publishes fetched
/// archive rows into the live service/reply queues.
class _WorldHistoryLoader {
  _WorldHistoryLoader(this.owner);
  final _WorldChatHistorySectionState owner;
  final _pages = <String, List<WorldChatroomMessage>>{};
  final _more = <String, bool>{};
  final _cursors = <String, int>{};
  final _failed = <String>{};
  final _latestPending = <String>{};
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
  DateTime? _retryAfter;
  bool _fillScheduled = false;
  bool _started = false;
  bool ready = false;
  bool loading = false;
  String readingLocationId = '';

  bool get enabled => owner.widget.active && owner._metadataReady;
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
    _latestPending.clear();
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
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (owner.mounted && enabled) unawaited(loadOlder(refreshNewest: true));
    });
  }

  List<String> get _leafIds => {
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

  Future<void> loadOlder({bool refreshNewest = false}) async {
    if (!enabled ||
        loading ||
        (!hasMore && !refreshNewest) ||
        owner._chatroomState.world == null) {
      return;
    }
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) return;
    loading = true;
    final generation = _generation;
    final api = AppServicesScope.read(owner.context).api;
    final worldId = owner.widget.worldId;
    final floor = _floor;
    if (refreshNewest) _latestPending.addAll(_leafIds);
    final ids = refreshNewest
        ? _leafIds
        : !ready
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
    owner._changed();
    var next = 0;
    Future<void> worker() async {
      while (next < ids.length && generation == _generation && owner.mounted) {
        final id = ids[next++];
        final newest = _latestPending.contains(id);
        final cursor = newest ? 0 : _cursors[id] ?? 0;
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
          final previous = _pages[id];
          final oldKeys = previous?.map(_key).toSet() ?? const <String>{};
          // Retain old pagination only if the refreshed latest page overlaps.
          // Otherwise restart this room's window so a message gap cannot hide
          // between newly arrived rows and the archived cursor.
          final retainOlder =
              newest &&
              page.hasMore &&
              rows.any((r) => oldKeys.contains(_key(r)));
          final merged = <String, WorldChatroomMessage>{
            for (final row in [
              if (!newest || retainOlder) ...?previous,
              ...rows,
            ])
              _key(row): row,
          };
          _pages[id] = merged.values.toList()..sort(compareRaw);
          if (!retainOlder) {
            _cursors[id] = oldest > 0 ? oldest : cursor;
            _more[id] = page.hasMore;
          }
          _latestPending.remove(id);
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
        owner._changed();
      }
    }
  }

  static String _key(WorldChatroomMessage m) => m.globalMessageId > 0
      ? 'g:${m.globalMessageId}'
      : '${m.locationId}:${m.messageId}:${m.locationMessageId}';
  ChatMessageVm? _parse(WorldChatroomMessage row) {
    if (!owner._messageVersionIsVisible(row)) return null;
    final key = _key(row);
    final identity = (
      row,
      owner._chatroomState.world,
      owner._chatroomState.entitiesById,
      owner.widget.currentUid,
    );
    if (_vmCache[key]?.$1 == identity) return _vmCache[key]!.$2;
    final index = _LocationChatTimelineIdentityIndex.fromState(
      owner._chatroomState,
      currentUserIds: [owner.widget.currentUid],
      currentSenderIds: const [],
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

  List<ChatMessageVm> project() {
    ensureStarted();
    if (!ready) return const [];
    final rawByKey = <String, WorldChatroomMessage>{
      for (final rows in _pages.values)
        for (final row in rows) _key(row): row,
    };
    final floor = _floor;
    final rows =
        rawByKey.values
            .where((row) => floor == null || compareRaw(row, floor) >= 0)
            .toList()
          ..sort(compareRaw);
    _locations.clear();
    final parsed = <ChatMessageVm>[];
    for (final row in rows) {
      final vm = _parse(row);
      if (vm == null) continue;
      parsed.add(vm);
      _locations[vm.localId] = row.locationId;
    }
    // Initial backdrop is the newest archived location, never an active room.
    if (readingLocationId.isEmpty && parsed.isNotEmpty) {
      readingLocationId = locationFor(parsed.last);
    }
    final chronological = parsed;
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
        enabled &&
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
      for (var i = 0; i < projected.length; i++)
        if (i == 0 ||
            locationFor(projected[i]) != locationFor(projected[i - 1]))
          projected[i].localId,
    };
    _boundaryKeys.removeWhere((id, _) => !boundaries.contains(id));
    if (!listEquals(projected, _lastProjection)) _lastProjection = projected;
    return _lastProjection;
  }

  String locationFor(ChatMessageVm message) =>
      _locations[message.localId] ?? '';

  void reading(String? id) {
    if (!enabled || !ready || !owner.mounted) return;
    final location = _locations[id];
    if (location == null || location.isEmpty || location == readingLocationId) {
      onScroll();
      return;
    }
    owner._update(() => readingLocationId = location);
    onScroll();
  }

  void ensureVisibleWindow() {
    if (!enabled ||
        !ready ||
        loading ||
        !hasMore ||
        _failed.isNotEmpty ||
        _fillScheduled) {
      return;
    }
    _fillScheduled = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!owner.mounted || generation != _generation) return;
      _fillScheduled = false;
      final controller = owner._scrollCoordinator.controller;
      if (enabled &&
          controller.hasClients &&
          controller.position.hasContentDimensions &&
          controller.position.maxScrollExtent <=
              LocationChatScrollCoordinator.bottomTolerance) {
        unawaited(loadOlder());
      }
    });
  }

  void onScroll() {
    if (!enabled ||
        !owner._scrollCoordinator.controller.hasClients ||
        loading ||
        !hasMore) {
      return;
    }
    final position = owner._scrollCoordinator.controller.position;
    _idleTimer?.cancel();
    if (!owner._scrollCoordinator.isReadingHistory ||
        position.extentBefore >= 200) {
      return;
    }
    _idleTimer = Timer(const Duration(milliseconds: 180), () {
      if (!owner.mounted ||
          !enabled ||
          !owner._scrollCoordinator.controller.hasClients) {
        return;
      }
      if (owner
          ._scrollCoordinator
          .controller
          .position
          .isScrollingNotifier
          .value) {
        onScroll();
      } else {
        unawaited(loadOlder());
      }
    });
  }
}
