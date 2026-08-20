part of 'world_page.dart';

extension _WorldPageSheets on _WorldPageState {
  void _showMapTab() {
    if (_worldMainTabIndex == 0) return;
    _selectWorldMainTab(0);
  }

  void _handleBottomSheetLocationTap(WorldPoint point) {
    unawaited(_openChatForPoint(point));
  }

  void _openWorldBottomSheet(
    WorldBottomSheetKind kind, {
    bool scrollEventsToLatest = false,
    int? eventsTargetTickNumber,
    bool preserveSelection = false,
  }) {
    final world = _world;
    if (world == null) return;
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: worldBottomSheetPageName(kind),
      object1: widget.wid,
    );
    if (kind == WorldBottomSheetKind.events) {
      _clearEventsUnread();
    }
    if (kind == WorldBottomSheetKind.detail &&
        (_hasUnreadNewUserJoin || _pendingNewUserJoinNotice != null)) {
      _setWorldPageState(_activateDetailNewUserJoinNotices);
    }
    if (!preserveSelection) {
      if (scrollEventsToLatest) {
        _eventsLatestRevision += 1;
      }
      _eventsTargetTickNumber = eventsTargetTickNumber;
      _worldBottomSheetSelection.value = WorldBottomSheetSelection(
        kind: kind,
        eventsLatestRevision: _eventsLatestRevision,
        eventsTargetTickNumber: _eventsTargetTickNumber,
      );
    }
    _sectionsWorldNotifier.value = world;
    if (_worldBottomSheetOpen) return;
    _setWorldPageState(() => _worldBottomSheetOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_worldBottomSheetOpen) return;
      _worldBottomSheetKey.currentState?.open();
    });
  }

  void _reopenSelectedWorldBottomSheet() {
    final selection = _worldBottomSheetSelection.value;
    _openWorldBottomSheet(selection.kind, preserveSelection: true);
  }

  void _requestWorldBottomSheetClose() {
    if (!_worldBottomSheetOpen) return;
    final sheet = _worldBottomSheetKey.currentState;
    if (sheet == null) {
      _handleWorldBottomSheetCollapsed();
      return;
    }
    unawaited(sheet.close());
  }

  void _handleWorldBottomSheetCollapsed() {
    if (!_worldBottomSheetOpen) return;
    if (mounted) {
      _setWorldPageState(() {
        _worldBottomSheetOpen = false;
        _applyDeferredBottomSheetMapChatroomState();
      });
      return;
    }
    _worldBottomSheetOpen = false;
    _deferredBottomSheetMapChatroomState = null;
  }

  Future<void> _confirmAndDeleteWorldFromDetail(
    BuildContext actionContext,
    WorldDetail world,
  ) async {
    final worldId = world.worldId.trim();
    if (worldId.isEmpty ||
        !worldCanDeleteLaunchedOnlyBySelf(world, _currentUid)) {
      showGenesisToast(
        actionContext,
        'Only worlds launched by you alone can be deleted.',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final confirmed = await showGenesisActionBox<bool>(
      context: actionContext,
      title: '',
      titleWidget: _DeleteWorldConfirmationTitle(name: world.name.trim()),
      titleHeight: 104,
      actions: [
        GenesisActionBoxAction<bool>(
          label: 'Delete',
          value: true,
          color: context.genesisColors.danger,
        ),
      ],
      cancelLabel: 'Cancel',
    );
    if (confirmed != true || !mounted || !actionContext.mounted) return;
    final api = AppServicesScope.read(actionContext).api;

    try {
      await api.v1.world.deleteLaunched(worldId: worldId);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(WorldPageResult.deleted(deletedWorldId: worldId));
    } catch (error) {
      if (!actionContext.mounted) return;
      showGenesisToast(actionContext, apiErrorMessage(error));
    }
  }
}

class _DeleteWorldConfirmationTitle extends StatelessWidget {
  const _DeleteWorldConfirmationTitle({required this.name});

  static const _baseStyle = TextStyle(
    fontSize: 15,
    height: 1.16,
    fontWeight: FontWeight.w600,
  );
  final String name;

  @override
  Widget build(BuildContext context) {
    final resolvedName = name.trim().isEmpty ? 'this World' : name.trim();
    return Center(
      child: Text.rich(
        TextSpan(
          style: _baseStyle.copyWith(color: context.genesisColors.textPrimary),
          children: [
            const TextSpan(text: 'Delete world '),
            TextSpan(
              text: resolvedName,
              style: TextStyle(color: context.genesisColors.accentText),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
