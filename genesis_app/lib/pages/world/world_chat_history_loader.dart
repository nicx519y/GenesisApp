part of '../chat/location_chat_page.dart';

/// Binds the independent archive state to the existing chat viewport. No room
/// joins, live queue writes, per-location HTTP, or background failure retries.
class _WorldHistoryLoader {
  _WorldHistoryLoader(this.owner);
  final _WorldChatHistorySectionState owner;
  final projection = WorldHistoryProjection();
  WorldHistoryController? controller;
  final _boundaryKeys = <String, GlobalKey>{};
  Set<String> _visibleIds = {};
  String? _readingId;
  String readingLocationId = '';
  bool _started = false;
  bool _scheduled = false;
  int _scheduleGeneration = 0;
  int _snapshot = -1;
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
    if (controller != null) return;
    controller = WorldHistoryController(
      worldId: owner.widget.worldId,
      fetch: AppServicesScope.read(owner.context).api.getWorldHistory,
    )..addListener(_changed);
  }

  void _changed() {
    final state = controller!;
    if (state.snapshot != _snapshot) {
      _snapshot = state.snapshot;
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

  void pause({bool leavingTab = false}) {
    _scheduleGeneration++;
    _scheduled = false;
    _idleTimer?.cancel();
    controller?.setActive(false);
    if (leavingTab) _started = false;
  }

  void reset() {
    pause(leavingTab: true);
    controller?.removeListener(_changed);
    controller?.dispose();
    controller = null;
    projection.clear();
    _boundaryKeys.clear();
    _visibleIds.clear();
    _readingId = null;
    readingLocationId = '';
    _snapshot = -1;
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
      // On tab re-entry discard a canceled operation's resume intent in favour
      // of a new first-page snapshot. Coverage/foreground resume preserves it.
      if (!_started) {
        _started = true;
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
    );
    _boundaryKeys.removeWhere((id, _) => !projection.byId.containsKey(id));
    if (_readingId == null && result.isNotEmpty) {
      readingLocationId = projection.rows.last.locationId;
    }
    return result;
  }

  String locationFor(ChatMessageVm message) =>
      projection.byId[message.localId]?.locationId ?? '';
  void visible(Set<String> ids) {
    _visibleIds = ids;
    _protectReading();
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
    _protectReading();
  }

  // Empty/version-filtered pages are deliberately manual, never auto-scanned.
  void ensureVisibleWindow() {}
  void onScroll() {
    _idleTimer?.cancel();
    final scroll = owner._scrollCoordinator.controller;
    if (!enabled ||
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
