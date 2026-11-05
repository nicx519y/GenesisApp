part of 'location_chat_page.dart';

extension _LocationChatPhotos on _LocationChatPanelState {
  void _resetPhotoVisit() {
    _photoVisitService?.releaseMessageWindow(_photoNavigationOwner);
    _photoReveal = null;
    _photoArrivalRequests.clear();
    _photoVisit++;
    _photoVisitService = null;
    _photoVisitSessionRevision = null;
    _photoVisibility = LocationChatPhotoVisibility(liveBaseline: 0);
  }

  void _ensurePhotoVisit() {
    final service = _service;
    final services = AppServicesScope.read(context);
    final revision = services.sessionRevision.value;
    if (!widget.active ||
        service == null ||
        !service.photoSessionReady ||
        (identical(service, _photoVisitService) &&
            revision == _photoVisitSessionRevision)) {
      return;
    }
    _resetPhotoVisit();
    _photoVisitService = service;
    _photoVisitSessionRevision = revision;
    service.beginPhotoVisit(widget.locationId);
    _photoVisibility = LocationChatPhotoVisibility(
      liveBaseline: service.photoRevision,
    );
    final visit = _photoVisit;
    final location = widget.locationId;
    final target = service.photoNavigationTarget;
    final navigate = target != null && target.locationId == location;
    if (navigate) service.photoNavigationTarget = null;
    unawaited(
      Future<void>(() async {
        if (!mounted ||
            !widget.active ||
            visit != _photoVisit ||
            revision != services.sessionRevision.value) {
          return;
        }
        final navigation = navigate
            ? _scrollCoordinator.beginHistoryNavigation()
            : null;
        await service.recoverPhotos(location);
        if (!mounted ||
            !widget.active ||
            visit != _photoVisit ||
            revision != services.sessionRevision.value ||
            !identical(service, _service)) {
          return;
        }
        _photoVisibility.calibrated = true;
        _handleChatroomState(service.state, forceMessageReconcile: true);
        if (navigate && navigation == _scrollCoordinator.commandGeneration) {
          await _navigateToPhoto(target, service, visit, navigation!);
        }
      }),
    );
  }

  Future<void> _navigateToPhoto(
    ChatPhotoTarget target,
    WorldChatroomService service,
    int visit,
    int navigation,
  ) async {
    final services = AppServicesScope.read(context);
    final revision = _photoVisitSessionRevision;
    bool current() =>
        mounted &&
        revision == services.sessionRevision.value &&
        widget.active &&
        visit == _photoVisit &&
        identical(service, _service) &&
        navigation == _scrollCoordinator.commandGeneration;
    try {
      final window = await service.loadPhotoNavigationWindow(
        target,
        owner: _photoNavigationOwner,
        isCurrent: current,
      );
      if (!mounted || !current()) return;
      if (window == null) {
        showGenesisToast(
          context,
          context.l10n.chatPhotoUnavailable,
          brightness: Brightness.dark,
        );
        _scrollCoordinator.requestBottom(
          reason: LocationChatBottomReason.unseenMessageNotice,
          behavior: LocationChatBottomBehavior.jump,
        );
        return;
      }
      final message = window.messages.firstWhere(
        (m) => m.globalMessageId == target.globalMessageId,
      );
      _olderMessagesCursor = window.messages.first.locationMessageId;
      _hasMoreOlderMessages = window.hasMore;
      _olderMessagesExhaustedByRemote = !window.hasMore;
      _handleChatroomState(service.state, forceMessageReconcile: true);
      if (!mounted || !current()) return;
      _setLocationChatState(
        () => _photoReveal = (
          generation: navigation,
          localId: locationChatMessageLocalId(message),
        ),
      );
    } catch (error) {
      if (mounted && current()) {
        showGenesisToast(
          context,
          apiErrorMessage(error),
          brightness: Brightness.dark,
        );
        _scrollCoordinator.requestBottom(
          reason: LocationChatBottomReason.unseenMessageNotice,
          behavior: LocationChatBottomBehavior.jump,
        );
      }
    } finally {
      if (!current() || _photoReveal == null) {
        service.releaseMessageWindow(_photoNavigationOwner);
      }
    }
  }

  bool _photoVisible(WorldChatroomMessage message) {
    final photo = message.photo;
    return _photoVisibility.includes(
      photo,
      liveRevision: photo == null
          ? 0
          : _service?.photoLiveRevision(photo.taskId) ?? 0,
      confirmedGenerating:
          photo != null &&
          _service?.photoConfirmedByHistory(photo.taskId) == true,
    );
  }

  Future<void> _submitScenePhoto() async {
    final service = _service;
    final location = widget.locationId;
    if (_takingScenePhoto ||
        !widget.active ||
        service == null ||
        !service.photoSubmittingLocations.add(location)) {
      return;
    }
    final services = AppServicesScope.read(context);
    final revision = services.sessionRevision.value;
    final world = _modelWorldId;
    bool current() =>
        mounted &&
        widget.active &&
        revision == services.sessionRevision.value &&
        identical(service, _service) &&
        !service.isDisposed &&
        world == _modelWorldId &&
        location == widget.locationId;
    try {
      final uid = await services.sessionStore.readLoginUid();
      if (!current() || uid == null) return;
      FocusManager.instance.primaryFocus?.unfocus();
      final environment = services.config.chatroomHttpBaseUrl;
      final store = ChatPhotoRequestStore(environment, uid, world, location);
      var pending = await store.read();
      if (!mounted || !current()) return;
      // A canonical echo can acknowledge a write whose HTTP response was lost.
      if (pending != null &&
          (service.state.messagesByLocation[location] ??
                  const <WorldChatroomMessage>[])
              .any((m) => m.photo?.requestId == pending!.requestId)) {
        await store.clear(pending.requestId);
        pending = null;
      }
      if (!mounted || !current()) return;
      final confirmed = await confirmCameraMoment(
        context,
        preferenceScope:
            '${Uri.encodeComponent(environment)}:${Uri.encodeComponent(uid)}',
        loadPrice: services.api.chatroomHttp.getPhotoPrice,
        recovering: pending != null,
      );
      if (!current() || !confirmed) return;
      final request =
          pending ??
          ChatPhotoRequest(
            requestId: ChatPhotoRequestStore.newId(),
            worldId: world,
            locationId: location,
          );
      await store.save(request);
      if (!mounted || !current()) return;
      _setLocationChatState(() {
        _takingScenePhoto = true;
        _photoArrivalRequests.add(request.requestId);
      });
      try {
        final receipt = await services.api.chatroomHttp.createPhoto(request);
        if (revision != services.sessionRevision.value || service.isDisposed) {
          return;
        }
        await service.acceptPhotoReceipt(receipt, request: request);
        await store.clear(request.requestId);
        return;
      } on ApiException catch (error) {
        if (error.kind == ApiExceptionKind.business) {
          await store.clear(request.requestId);
          if (!mounted || !current()) return;
          if (error.code == 10001 ||
              error.code == 3001 ||
              error.code == 21001) {
            return;
          }
          showGenesisToast(
            context,
            apiErrorMessage(error),
            brightness: Brightness.dark,
          );
        } else if (mounted && current()) {
          showGenesisToast(
            context,
            context.l10n.chatPhotoUncertain,
            brightness: Brightness.dark,
          );
        }
        return;
      }
    } catch (error) {
      if (mounted && current()) {
        showGenesisToast(
          context,
          apiErrorMessage(error),
          brightness: Brightness.dark,
        );
      }
    } finally {
      service.photoSubmittingLocations.remove(location);
      if (mounted) _setLocationChatState(() => _takingScenePhoto = false);
    }
  }
}
