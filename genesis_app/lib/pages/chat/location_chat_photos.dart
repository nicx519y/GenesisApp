part of 'location_chat_page.dart';

extension _LocationChatPhotos on _LocationChatPanelState {
  Set<String> _livePhotoTasks(List<ChatMessageVm> messages) {
    final key = (
      messages,
      _replyProjectionEpoch,
      _service?.photoRevision,
      _photoVisit,
    );
    if (_photoArrivalIndexKey == key) return _photoArrivalTaskIds;
    _photoArrivalIndexKey = key;
    return _photoArrivalTaskIds = Set.unmodifiable({
      for (final message in messages)
        if (message.photo != null &&
            (_service?.photoLiveRevision(message.photo!.taskId) ?? 0) >
                _photoVisibility.liveBaseline)
          message.photo!.taskId,
    });
  }

  Future<void> _takeScenePhoto() => _submitReplyAction(
    _LocationChatReplyActionTransaction(
      action: _LocationChatReplyConnectionAction.camera,
      commit: _submitScenePhoto,
    ),
  );

  void _resetPhotoVisit() {
    _photoArrivalRequests.clear();
    _photoReplacementRequests.clear();
    _photoArrivalIndexKey = null;
    _photoArrivalTaskIds = const {};
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
    unawaited(
      Future<void>(() async {
        if (!mounted ||
            !widget.active ||
            visit != _photoVisit ||
            revision != services.sessionRevision.value) {
          return;
        }
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
      }),
    );
  }

  bool _photoVisible(WorldChatroomMessage message) {
    final photo = message.photo;
    if (photo != null &&
        (_replyController
                ?.stateForRound(
                  widget.locationId,
                  message.conversationRoundNumber,
                )
                ?.formalReplyMessages
                .any((m) => m.globalMessageId == message.globalMessageId) ??
            false)) {
      return true;
    }
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
    final operation = _LocationChatReplyOperationScope(this);
    bool current() =>
        operation.canApplyToReply &&
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
      var store = ChatPhotoRequestStore(environment, uid, world, location);
      // Formal writes use the location journal; candidate writes use their card.
      // Preserve all uncertain writes exactly, including older request shapes.
      var pending = await store.read();
      // Resolve an acknowledged legacy write before choosing a new card target.
      // Otherwise clearing it below would leave a new write without a target.
      if (pending != null &&
          (service.state.messagesByLocation[location] ??
                  const <WorldChatroomMessage>[])
              .any((m) => m.photo?.requestId == pending!.requestId)) {
        await store.clear(pending.requestId);
        pending = null;
      }
      if (!current()) return;
      final controller = _replyController;
      if (controller == null) return;
      final target = pending == null
          ? await controller.preparePhotoTarget(location)
          : null;
      if (!current()) return;
      if (target != null) {
        store = ChatPhotoRequestStore(
          environment,
          uid,
          world,
          location,
          roundId: target.roundId,
          cardId: target.cardId,
        );
        pending = await store.read();
      }
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
      // As with Edit, user confirmation is not a connection preparation wait.
      _replyPreparationWait?.finish();
      final confirmed = await confirmCameraMoment(
        context,
        preferenceScope:
            '${Uri.encodeComponent(environment)}:${Uri.encodeComponent(uid)}',
        loadPrice: services.api.chatroomHttp.getPhotoPrice,
        recovering: pending != null,
      );
      if (!current() || !confirmed) return;
      if (pending == null && target != null) {
        controller.validatePhotoTarget(location, target);
      }
      final request =
          pending ??
          ChatPhotoRequest(
            requestId: ChatPhotoRequestStore.newId(),
            worldId: world,
            locationId: location,
            roundId: target?.roundId,
            cardId: target?.cardId,
          );
      await store.save(request);
      if (!mounted || !current()) {
        if (pending == null) await store.clear(request.requestId);
        return;
      }
      if (pending == null && target != null) {
        try {
          controller.validatePhotoTarget(location, target);
        } catch (_) {
          // Nothing was sent: do not leave an invalid new write for recovery.
          await store.clear(request.requestId);
          rethrow;
        }
      }
      final roundId = request.roundId;
      final cardId = request.cardId;
      final round = roundId == null
          ? null
          : controller.stateForRound(location, roundId);
      final targetMessages = cardId == null
          ? round?.formalReplyMessages
          : round?.messagesForCard(cardId);
      final replacesPhoto =
          targetMessages?.any((m) => m.photo?.imageUrl.isNotEmpty == true) ??
          false;
      _setReplyControlsState(() {
        _takingScenePhoto = true;
        // A retry still needs to be the latest dispatch for the viewport.
        _photoArrivalRequests.remove(request.requestId);
        _photoArrivalRequests.add(request.requestId);
        if (replacesPhoto) _photoReplacementRequests.add(request.requestId);
      });
      final monitor = service.photoGenerationMonitor;
      monitor?.start('chat', request.requestId, locationId: location);
      try {
        final receipt = await services.api.chatroomHttp.createPhoto(request);
        if (revision != services.sessionRevision.value || service.isDisposed) {
          return;
        }
        monitor?.observe('chat', receipt.photo);
        await service.acceptPhotoReceipt(receipt, request: request);
        await store.clear(request.requestId);
        return;
      } on ApiException catch (error) {
        if (error.kind == ApiExceptionKind.business) {
          monitor?.finish('chat', request.requestId);
          await store.clear(request.requestId);
          if (!mounted || !current()) return;
          if ((error.code == 2072 || error.code == 2073) &&
              request.cardId != null) {
            await controller.refreshPhotoCard(
              location,
              request.roundId!,
              request.cardId!,
            );
          }
          if (error.code == 2072) {
            await controller.clearCardsCache(location);
            await controller.restoreLocationCards(location);
            await service.refreshLocationHistory(locationId: location);
          }
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
      if (mounted) _setReplyControlsState(() => _takingScenePhoto = false);
    }
  }
}
