part of '../chat/location_chat_page.dart';

/// Binds the independent archive state to the existing chat viewport. No room
/// joins, live queue writes, per-location HTTP, or background failure retries.
class _WorldHistoryLoader {
  _WorldHistoryLoader(this.owner);
  final _WorldChatHistorySectionState owner;
  WorldHistoryViewCache get cache => owner._cache;
  WorldHistoryProjection get projection => cache.projection;
  WorldHistoryController? get controller => cache.controller;
  WorldHistoryController? _listenedController;
  final _boundaryKeys = <String, GlobalKey>{};
  Set<String> _visibleIds = {};
  String? get _readingId => cache.readingId;
  set _readingId(String? value) => cache.readingId = value;
  String get readingLocationId => cache.readingLocationId;
  set readingLocationId(String value) => cache.readingLocationId = value;
  bool _scheduled = false;
  bool _protectScheduled = false;
  int _recoveredRevision = -1;
  int _scheduleGeneration = 0;

  Object? _reportedError;
  Timer? _idleTimer;

  bool get enabled => owner._requestsEnabled && owner._metadataReady;
  bool get ready => controller?.ready ?? false;
  bool get loading => controller?.loading ?? false;
  bool get hasMore => controller?.hasOlder ?? true;
  bool get hasNewer => controller?.hasNewer ?? false;
  bool get failed => controller?.failed ?? false;
  GlobalKey boundaryKey(String id) =>
      _boundaryKeys.putIfAbsent(id, GlobalKey.new);
  GlobalKey? existingBoundaryKey(String id) => _boundaryKeys[id];

  void bind() {
    cache.controller ??= WorldHistoryController(
      worldId: owner.widget.worldId,
      appVersion: owner._messageAppVersion,
      fetch: AppServicesScope.read(owner.context).api.getWorldHistory,
    );
    if (identical(_listenedController, controller)) return;
    _listenedController?.removeListener(_changed);
    _listenedController = controller!..addListener(_changed);
  }

  void _changed() {
    final state = controller!;
    if (state.awaitingUserContinuation) _idleTimer?.cancel();
    if (state.snapshot != cache.snapshot) {
      cache.snapshot = state.snapshot;
      projection.clear();
      owner._historySections.reset();
      _readingId = null;
      _visibleIds.clear();
    }
    if (state.error != null && !identical(state.error, _reportedError)) {
      _reportedError = state.error;
      final error = state.error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!owner.mounted || !enabled || !identical(state, controller)) return;
        showGenesisToast(
          owner.context,
          error is ApiException
              ? error.serverErrMsg ?? error.message
              : error is FormatException
              ? error.message
              : error.toString(),
        );
      });
    }
    if (state.error == null) _reportedError = null;
    owner._changed();
  }

  void pause() {
    _scheduleGeneration++;
    _scheduled = false;
    _idleTimer?.cancel();
    controller?.setActive(false);
  }

  void detach() {
    pause();
    _listenedController?.removeListener(_changed);
    _listenedController = null;
  }

  void reset() {
    detach();
    cache.clear();
    _boundaryKeys.clear();
    _visibleIds.clear();
    _reportedError = null;
  }

  void ensureStarted() {
    if (!enabled || _scheduled) return;
    _scheduled = true;
    final generation = _scheduleGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!owner.mounted || generation != _scheduleGeneration) return;
      _scheduled = false;
      if (!enabled) return;
      bind();
      // Reopening resumes the same World-owned snapshot and reading position.
      if (!cache.started) {
        cache.started = true;
        controller!.requestEntryRefresh();
      } else {
        controller!.setActive(true);
      }
    });
  }

  Future<void> loadOlder({bool refreshNewest = false}) async {
    if (!enabled) return;
    bind();
    controller!.setActive(true);
    if (refreshNewest) {
      await controller!.refresh();
    } else if (failed) {
      await controller!.retry();
    } else {
      await controller!.loadOlder();
    }
  }

  Future<void> loadNewer() async {
    if (!enabled) return;
    owner._scrollCoordinator.beginHistoryNavigation();
    if (failed) {
      await controller?.retry();
    } else {
      await controller?.loadNewer();
    }
  }

  List<ChatMessageVm> project() {
    ensureStarted();
    final state = controller;
    final result = projection.project(
      newestFirst: state?.newestFirst ?? const [],
      dataRevision: state?.revision ?? -1,
      world: owner.widget.world,
      uid: owner.widget.currentUid,
      appVersion: owner._messageAppVersion,
      sectionParticipation: state?.sectionParticipation,
    );
    _boundaryKeys.removeWhere((id, _) => !projection.byId.containsKey(id));
    if (_readingId == null && result.isNotEmpty) {
      readingLocationId = projection.rows.last.locationId;
    }
    return result;
  }

  String locationFor(ChatMessageVm message) =>
      projection.byId[message.localId]?.locationId ?? '';
  String? sectionFor(ChatMessageVm message) =>
      projection.byId[message.localId]?.sectionId;

  void cancelScheduledLoad() => _idleTimer?.cancel();

  void visible(Set<String> ids) {
    _visibleIds = ids;
    _scheduleProtectReading();
  }

  void _scheduleProtectReading() {
    if (_protectScheduled) return;
    _protectScheduled = true;
    final generation = _scheduleGeneration;
    scheduleMicrotask(() {
      _protectScheduled = false;
      if (!owner.mounted || generation != _scheduleGeneration || !enabled) {
        return;
      }
      _protectReading();
    });
  }

  // Normal replacement lets the shared viewport retain surviving visible
  // anchors. Only an entirely lost visible range needs an explicit reveal.
  void restoreReading() {
    final state = controller;
    if (state == null || state.revision == _recoveredRevision) return;
    _recoveredRevision = state.revision;
    if (state.updatedPage == null ||
        _readingId == null ||
        projection.byId.containsKey(_readingId)) {
      return;
    }
    final retained = projection.rows.where(
      (row) => _visibleIds.contains(row.id),
    );
    if (retained.isNotEmpty) {
      _readingId = retained.first.id;
      _scheduleProtectReading();
      return;
    }
    final candidates = projection.rows
        .where((row) => state.pageFor(row.message.id) == state.updatedPage)
        .toList();
    if (candidates.isEmpty) {
      _readingId = null;
      return;
    }
    var target =
        (state.updatedTowardNewer ? candidates.first : candidates.last).id;
    // A collapsed section is represented by its header, never a hidden body.
    target = owner._historySections.visibleAnchorFor(target);
    final generation = owner._scrollCoordinator.commandGeneration;
    final revision = state.revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!owner.mounted ||
          !enabled ||
          !identical(state, controller) ||
          state.revision != revision ||
          owner._scrollCoordinator.commandGeneration != generation ||
          !projection.byId.containsKey(target)) {
        return;
      }
      final command = owner._scrollCoordinator.beginHistoryNavigation();
      owner._update(() {
        _readingId = target;
        owner._historySections.reveal = (generation: command, localId: target);
      });
      _scheduleProtectReading();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (owner.mounted &&
            owner._historySections.reveal?.generation == command) {
          owner._historySections.reveal = null;
        }
      });
    });
  }

  void _protectReading() {
    final ids = <String>{
      ..._visibleIds,
      ...owner._scrollCoordinator.retainedMessageLocalIds,
      if (_readingId != null) _readingId!,
      if (owner._historySections.reveal != null)
        owner._historySections.reveal!.localId,
    };
    projection.pin(ids);
    controller?.updateReading(
      messageId: projection.byId[_readingId]?.message.id,
      pinnedIds: ids
          .map((id) => projection.byId[id]?.message.id)
          .whereType<String>(),
    );
  }

  void reading(String? id) {
    if (!enabled || !ready || id == null) return;
    _readingId = id;
    final location = projection.byId[id]?.locationId ?? '';
    if (location != readingLocationId) {
      owner._update(() => readingLocationId = location);
    }
    _scheduleProtectReading();
  }

  // Empty/version-filtered pages are deliberately manual, never auto-scanned.
  void ensureVisibleWindow() {}
  void onScroll() {
    _idleTimer?.cancel();
    final scroll = owner._scrollCoordinator.controller;
    if (!enabled ||
        (controller?.awaitingUserContinuation ?? false) ||
        loading ||
        failed ||
        !ready ||
        !scroll.hasClients ||
        (!owner._scrollCoordinator.isReadingHistory && !hasNewer)) {
      return;
    }
    final position = scroll.position;
    final older = position.extentBefore < 200 && hasMore;
    final newer = position.extentAfter < 200 && hasNewer;
    if (!older && !newer) return;
    _idleTimer = Timer(const Duration(milliseconds: 180), () {
      if (!owner.mounted || !enabled || !scroll.hasClients) return;
      if (scroll.position.isScrollingNotifier.value) {
        onScroll();
        return;
      }
      unawaited(older ? loadOlder() : loadNewer());
    });
  }
}
