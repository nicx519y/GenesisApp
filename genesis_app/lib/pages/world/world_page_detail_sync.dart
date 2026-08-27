part of 'world_page.dart';

extension _WorldPageDetailSync on _WorldPageState {
  Future<void> _fetchWorld({bool isInitial = false}) async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    FirebasePerformanceOperation? requestOperation;
    if (isInitial && !_initialContentRenderCompleted) {
      final attempt = ++_initialRequestPerformanceAttempt;
      requestOperation = await FirebasePerformanceOperation.start(
        surface: FirebasePerformanceSurface.worldPage,
        phase: FirebasePerformancePhase.request,
        attempt: attempt,
      );
      if (!mounted) {
        unawaited(requestOperation.cancel());
        _pollInFlight = false;
        return;
      }
      _initialRequestPerformanceOperation = requestOperation;
    }
    try {
      final world = await AppServicesScope.read(
        context,
      ).api.getWorld(widget.wid);
      if (!mounted ||
          !identical(_initialRequestPerformanceOperation, requestOperation) &&
              requestOperation != null) {
        unawaited(requestOperation?.cancel());
        return;
      }
      if (identical(_initialRequestPerformanceOperation, requestOperation)) {
        _initialRequestPerformanceOperation = null;
      }
      unawaited(requestOperation?.succeed());
      if (isInitial) {
        _initialRenderDataSource = FirebasePerformanceDataSource.network;
      }
      _applyWorldDetail(world, clearInitialLoadError: isInitial);
    } catch (e) {
      if (identical(_initialRequestPerformanceOperation, requestOperation)) {
        _initialRequestPerformanceOperation = null;
      }
      unawaited(
        requestOperation?.fail(errorType: firebasePerformanceErrorType(e)),
      );
      if (!mounted) return;
      debugPrint('[WorldPage] load failed wid="${widget.wid}": $e');
      if (isInitial) {
        _setWorldPageState(() {
          _initialLoadError = e;
        });
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _applyWorldDetail(
    WorldDetail world, {
    bool clearInitialLoadError = false,
  }) {
    _initialTilemapPreferredFocusLocationId ??= world.lastChatLocationId.trim();
    final canTrackWorldProgress = shouldConnectWorldChatroom(
      world.relationStatus,
    );
    final shouldStartTracking = world.isProgressing && canTrackWorldProgress;
    final previousDefinitionVersion = _world?.definitionVersion;
    final tilemapImplementationChanged =
        previousDefinitionVersion != world.definitionVersion;
    _precacheProgressWaitAvatarImages(world);
    _setWorldPageState(() {
      _world = world;
      if (_renderStage == _WorldPageRenderStage.framework) {
        _renderStage = _WorldPageRenderStage.detailShell;
      }
      if (tilemapImplementationChanged) {
        _tilemapDisplayReady = world.definitionVersion != 2;
        _tilemapDisplayError = null;
      }
      _sectionsWorldNotifier.value = world;
      if (clearInitialLoadError) _initialLoadError = null;
      _syncLocationChatDescriptors(world);
      _applyWorldDetailMapActivityLocations(world);
      _replaceMapBubbleCandidates(
        _buildMapBubbleCandidates(_worldChatroom?.state, world),
      );
    });
    _worldChatroom?.applyWorldSnapshot(world);
    _syncWorldChatroomForRelationStatus(world.relationStatus);
    _maybeOpenInitialLocationChat();
    if (shouldStartTracking) {
      _startWorldTickTracking();
    } else if (_worldTickInProgress) {
      _markWorldTickIdle();
    }
  }

  void _applyWorldDetailMapActivityLocations(WorldDetail world) {
    final recentLocationId = world.lastChatLocationId.trim();
    _recentChatLocationIds = recentLocationId.isEmpty
        ? const <String>{}
        : Set<String>.unmodifiable(<String>{recentLocationId});
    _recentChatLocationPathIds = recentLocationId.isEmpty
        ? const <String>{}
        : Set<String>.unmodifiable(
            _locationPathIdsForLocationId(
              recentLocationId,
              world.processedLocationTree,
            ),
          );

    final eventLocationIds = worldDetailEventLocationIds(world.locations);
    final eventLocationPathIds = <String>{};
    for (final locationId in eventLocationIds) {
      eventLocationPathIds.addAll(
        _locationPathIdsForLocationId(locationId, world.processedLocationTree),
      );
    }
    _currentTickEventLocationPathIds = Set<String>.unmodifiable(
      eventLocationPathIds,
    );
  }

  List<GenesisGenerationWaitAvatar> _progressWaitAvatarsFromWorld(
    WorldDetail? world,
  ) {
    if (world == null) return const <GenesisGenerationWaitAvatar>[];
    return world.characters
        .map((character) {
          return GenesisGenerationWaitAvatar(
            name: worldMapString(character, const [
              'name',
              'character_name',
              'player_username',
            ]).trim(),
            url: worldResolveAssetUrl(
              worldMapString(character, const [
                'avatar',
                'avatar_url',
                'role_avatar',
              ]),
            ).trim(),
          );
        })
        .where((avatar) => avatar.name.isNotEmpty || avatar.url.isNotEmpty)
        .toList(growable: false);
  }

  void _precacheProgressWaitAvatarImages(WorldDetail world) {
    if (!mounted) return;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    for (final avatar in _progressWaitAvatarsFromWorld(world)) {
      final resolvedUrl = selectGenesisImageUrl(
        avatar.url,
        logicalWidth: _WorldPageState._progressWaitAvatarSize,
        logicalHeight: _WorldPageState._progressWaitAvatarSize,
        devicePixelRatio: devicePixelRatio,
      ).trim();
      if (resolvedUrl.isEmpty) continue;
      final ImageProvider provider = resolvedUrl.startsWith('assets/')
          ? AssetImage(resolvedUrl)
          : GenesisStaticNetworkImageProvider(imageUrl: resolvedUrl);
      unawaited(
        precacheImage(
          provider,
          context,
          onError: (exception, stackTrace) {
            debugPrint(
              '[WorldPage] progress avatar precache failed url="$resolvedUrl": '
              '$exception',
            );
          },
        ).catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            '[WorldPage] progress avatar precache future failed '
            'url="$resolvedUrl": $error',
          );
        }),
      );
    }
  }

  Future<void> _precacheCurrentWorldFooterAvatar(WorldDetail world) async {
    if (!shouldConnectWorldChatroom(world.relationStatus)) return;
    final uid = _currentUid.trim();
    if (uid.isEmpty) return;

    Map<String, dynamic>? currentCharacter;
    for (final character in world.characters) {
      if (worldMapString(character, const ['player_uid']) != uid) continue;
      currentCharacter = character;
      break;
    }
    if (currentCharacter == null || !mounted) return;

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final avatarUrl = selectGenesisImageUrl(
      worldMapString(currentCharacter, const ['avatar']),
      logicalWidth: worldCharacterAvatarLogicalSize,
      logicalHeight: worldCharacterAvatarLogicalSize,
      devicePixelRatio: devicePixelRatio,
      maxDevicePixelRatio: devicePixelRatio,
    ).trim();
    if (avatarUrl.isEmpty) return;

    final ImageProvider<Object> provider;
    if (avatarUrl.startsWith('assets/')) {
      provider = AssetImage(avatarUrl);
    } else {
      final decodeSize = math.max(
        1,
        (worldCharacterAvatarLogicalSize * devicePixelRatio).ceil(),
      );
      provider = GenesisStaticNetworkImageProvider(
        imageUrl: avatarUrl,
        cacheWidth: decodeSize,
        cacheHeight: decodeSize,
        fit: BoxFit.cover,
      );
    }

    try {
      await precacheImage(
        provider,
        context,
        onError: (exception, stackTrace) {
          if (kDebugMode) {
            debugPrint(
              '[WorldPage] footer avatar precache failed url="$avatarUrl": '
              '$exception',
            );
          }
        },
      ).timeout(const Duration(seconds: 2));
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[WorldPage] footer avatar precache did not finish url="$avatarUrl": '
          '$error',
        );
      }
    }
  }

  String _rootMapImageUrlForWorld(WorldDetail world) {
    final displayRootMapUrl = worldRootMapImageUrl(
      world.processedLocationTree.initialMapDisplayRoots,
    ).trim();
    if (displayRootMapUrl.isNotEmpty) return displayRootMapUrl;
    final worldMapUrl = world.mapImageUrl.trim();
    if (worldMapUrl.isNotEmpty) return worldMapUrl;
    return world.origin.worldMap.trim();
  }

  List<WorldMapBubbleCandidate> _buildMapBubbleCandidates(
    WorldChatroomState? state,
    WorldDetail? world,
  ) {
    if (state == null || world == null) {
      return const <WorldMapBubbleCandidate>[];
    }
    return worldMapBubbleCandidatesFor(
      currentTickNo: world.tickCount,
      currentSubTickNo: world.subTickNo,
      characterPositions: world.characterPositions,
      messagesByLocation: state.messagesByLocation,
    );
  }

  bool _replaceMapBubbleCandidates(List<WorldMapBubbleCandidate> candidates) {
    if (_sameMapBubbleCandidates(_mapBubbleCandidates, candidates)) {
      return false;
    }
    _mapBubbleCandidates = candidates;
    return true;
  }

  bool _sameMapBubbleCandidates(
    List<WorldMapBubbleCandidate> current,
    List<WorldMapBubbleCandidate> next,
  ) {
    if (identical(current, next)) return true;
    if (current.length != next.length) return false;
    for (var index = 0; index < current.length; index += 1) {
      final currentItem = current[index];
      final nextItem = next[index];
      if (currentItem.characterId != nextItem.characterId ||
          currentItem.characterLocationId != nextItem.characterLocationId ||
          currentItem.content != nextItem.content) {
        return false;
      }
    }
    return true;
  }

  List<WorldMapMessageBubble> get _mapMessageBubbles {
    return _mapBubbleCandidates
        .map(
          (candidate) => WorldMapMessageBubble(
            characterId: candidate.characterId,
            content: candidate.content,
          ),
        )
        .toList(growable: false);
  }

  void _maybeShowTick1WaitDialog() {
    if (!widget.waitForTick1 || _tick1WaitDialogStarted) return;
    final world = _world;
    if (world == null || worldHasTick1(world)) return;
    _tick1WaitDialogStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        showGenesisDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => WorldTick1WaitDialog(
            loadWorld: _loadWorldForTick1Wait,
            onWorldReady: (world) =>
                _applyWorldDetail(world, clearInitialLoadError: true),
          ),
        ),
      );
    });
  }

  Future<WorldDetail> _loadWorldForTick1Wait() async {
    return AppServicesScope.read(context).api.getWorld(widget.wid);
  }
}
