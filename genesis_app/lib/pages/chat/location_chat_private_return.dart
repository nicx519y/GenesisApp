part of 'location_chat_page.dart';

extension _LocationChatPhoneNavigation on _LocationChatPanelState {
  Future<void> _takeScenePhoto() async {
    if (_takingScenePhoto) return;
    _takingScenePhoto = true;
    final services = AppServicesScope.read(context);
    final revision = services.sessionRevision.value;
    final worldId = _modelWorldId;
    final locationId = widget.locationId;
    bool isCurrent() =>
        mounted &&
        revision == services.sessionRevision.value &&
        worldId == _modelWorldId &&
        locationId == widget.locationId;
    try {
      final uid = await services.sessionStore.readLoginUid();
      if (!mounted || !isCurrent() || uid == null) return;
      FocusManager.instance.primaryFocus?.unfocus();
      final confirmed = await confirmCameraMoment(
        context,
        // Until generation is wired, keep the explanation available even if
        // its preference was remembered during an earlier UI preview.
        forceShow: true,
        preferenceScope:
            '${Uri.encodeComponent(services.config.chatroomHttpBaseUrl)}:${Uri.encodeComponent(uid)}',
      );
      if (!mounted || !isCurrent() || !confirmed) return;
      // Same generation availability as the Camera page: no transport is wired
      // until a real creation/status/message/album contract is supplied.
      showGenesisToast(
        context,
        context.l10n.miniPhoneComingSoon,
        brightness: Brightness.dark,
      );
    } finally {
      _takingScenePhoto = false;
    }
  }

  Future<void> _openPhoneFromRoom({
    MiniPhoneSession? session,
    PhonePerson? contact,
    MiniPhoneScreen? initialScreen,
    String initialCameraPrompt = '',
    required String source,
  }) async {
    await PagePresentationScope.runCovered(context, () async {
      await showMiniPhone(
        context,
        session: session,
        worldId: _modelWorldId,
        modelCache: _modelRequestCache,
        initialContact: contact,
        initialScreen: initialScreen,
        initialCameraPrompt: initialCameraPrompt,
        entrySource: source,
      );
    });
  }
}
