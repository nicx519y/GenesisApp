part of 'world_page.dart';

extension _WorldPageTilemapView on _WorldPageState {
  Future<void> _loadTilemapView(
    AppServices services,
    int revision,
    String uid,
  ) async {
    if (_tilemapViewReady || widget.wid.trim().isEmpty) return;
    final generation = _tilemapViewGeneration;
    final worldId = widget.wid;
    final store = WorldTilemapViewStore(
      namespace:
          '${services.config.effectiveApiEnvironment}|${services.platformConfig.apiBaseUrl}',
      uid: uid,
      worldId: worldId,
    );
    final saved = await store.load();
    if (!mounted ||
        generation != _tilemapViewGeneration ||
        widget.wid != worldId ||
        !identical(services, _worldSessionServices) ||
        services.sessionRevision.value != revision) {
      return;
    }
    _setWorldPageState(() {
      _tilemapViewStore = store;
      _savedTilemapView = saved;
      _tilemapViewReady = true;
      _tilemapRestorationController.onViewStateChanged =
          _scheduleTilemapViewSave;
    });
  }

  void _restoreTilemapView(WorldDetail world) {
    if (_tilemapViewApplied || world.definitionVersion != 2) return;
    _tilemapViewApplied = true;
    final saved = _savedTilemapView;
    if (saved == null ||
        !worldTilemapViewIsValid(saved, world.processedLocationTree)) {
      return;
    }
    _restoredTilemapInitialLocationId = saved.initialLocationId;
    _tilemapRestorationController.restoreWorldView(
      worldId: widget.wid,
      state: saved,
    );
  }

  void _scheduleTilemapViewSave() {
    _tilemapViewSaveTimer?.cancel();
    _tilemapViewSaveTimer = Timer(
      const Duration(milliseconds: 300),
      _persistTilemapView,
    );
  }

  void _persistTilemapView() {
    final store = _tilemapViewStore;
    final state = _tilemapRestorationController.viewState;
    if (store != null && state != null) unawaited(store.save(state));
  }

  void _resetTilemapView() {
    _tilemapViewSaveTimer?.cancel();
    _persistTilemapView();
    _tilemapRestorationController.dispose();
    _tilemapRestorationController = TilemapRestorationController();
    _tilemapImplementationKey = GlobalKey(debugLabel: 'world-detail-tilemap');
    _tilemapViewStore = null;
    _savedTilemapView = null;
    _tilemapViewReady = false;
    _tilemapViewApplied = false;
    _tilemapViewGeneration += 1;
    _restoredTilemapInitialLocationId = '';
    _tilemapDisplayReady = false;
  }
}

/// A changed location tree must not restore deleted maps or broken back paths.
bool worldTilemapViewIsValid(
  TilemapViewState state,
  ProcessedLocationTree<Map<String, dynamic>> tree,
) {
  final path = [...state.locationTrail, state.currentLocationId];
  if (path.first != state.initialLocationId ||
      path.toSet().length != path.length) {
    return false;
  }
  for (var index = 0; index < path.length; index++) {
    final id = path[index];
    if (id == 'root' && index == 0) continue;
    final node = tree.nodeById(id);
    if (node == null) return false;
    if (index > 0 &&
        path[index - 1] != 'root' &&
        !tree
            .descendantsOf(path[index - 1], includeSelf: false)
            .any((child) => child.id == id)) {
      return false;
    }
  }
  return true;
}
