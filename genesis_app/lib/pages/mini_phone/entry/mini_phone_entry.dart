import '../../../l10n/genesis_localizations.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/components/genesis_avatar.dart';
import '../music/mini_phone_music_service.dart';
import '../session/mini_phone_session.dart';
import 'mini_phone_dock_position.dart';
import 'mini_phone_entry_artwork.dart';
import 'mini_phone_entry_motion.dart';
import 'mini_phone_entry_style.dart';

class MiniPhoneEntry extends StatefulWidget {
  const MiniPhoneEntry({
    super.key,
    required this.onPressed,
    this.session,
    this.style,
    this.visible = true,
    this.interactive = true,
  });
  final MiniPhoneSession? session;
  final VoidCallback onPressed;
  final bool visible, interactive;

  /// Explicit style override; null selects from the current World's map era.
  final MiniPhoneEntryStyle? style;
  @override
  State<MiniPhoneEntry> createState() => _MiniPhoneEntryState();
}

class _MiniPhoneEntryState extends State<MiniPhoneEntry>
    with TickerProviderStateMixin {
  late final AnimationController _arrival;
  late final AnimationController _musicPulse;
  final _musicOverlay = OverlayPortalController();
  final _entryLink = LayerLink();
  late final MiniPhoneSession _session;
  late final bool _ownsSession;
  MiniPhoneMusicService get _music => _session.music;
  int _unread = 0;
  bool _reducedMotion = false;
  MiniPhoneEntryStyle _resolvedStyle(BuildContext context) {
    final scope = MiniPhoneSessionScope.watch(context);
    return widget.style ??
        MiniPhoneEntryStyle.fromMapEra(
          (scope != null ? scope.mapStyle : _session.data?.mapStyle)?.era,
        );
  }

  int get _currentUnread => _session.data?.totalUnreadCount ?? 0;
  bool get _arriving => _unread > 0 && _arrival.isAnimating && !_reducedMotion;
  Widget get _arrivalAvatar {
    final data = _session.data;
    if (data == null) return const SizedBox.shrink();
    final person = data.person(data.latestUnreadCharId ?? '');
    return GenesisAvatar(
      url: person.avatar,
      name: person.name,
      size: 32,
      borderRadius: 16,
    );
  }

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session = widget.session ?? MiniPhoneSession();
    _arrival = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: entryAvatarMotion.durationMs),
    );
    _musicPulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: entryMusicMotion.durationMs),
    );
    _music.addListener(_musicChanged);
    _unread = _currentUnread;
    _session.data?.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _musicChanged();
      if (_unread > 0 && !_reducedMotion) _arrival.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) _arrival.stop();
    _syncMusicAnimation();
  }

  void _syncMusicAnimation() {
    if (_music.playing && !_reducedMotion) {
      if (!_musicPulse.isAnimating) _musicPulse.repeat();
    } else {
      _musicPulse.stop();
    }
  }

  void _musicChanged() {
    if (!mounted) return;
    _syncMusicAnimation();
    if (_music.entryActivated) {
      if (_music.track == null) _session.ensureMusicCatalog();
      _musicOverlay.show();
    } else {
      _musicOverlay.hide();
    }
    setState(() {});
  }

  void _changed() {
    final unread = _currentUnread;
    if (unread > _unread && !_reducedMotion) _arrival.forward(from: 0);
    if (unread == 0) _arrival.stop();
    setState(() => _unread = unread);
  }

  @override
  void dispose() {
    _session.data?.removeListener(_changed);
    _arrival.dispose();
    _music.removeListener(_musicChanged);
    _musicPulse.dispose();
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _musicOverlay,
    overlayChildBuilder: (_) =>
        !widget.visible || ModalRoute.of(context)?.isCurrent == false
        ? const SizedBox.shrink()
        : AnimatedBuilder(
            animation: _arrival,
            builder: (context, _) => Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _entryLink,
                showWhenUnlinked: false,
                offset: const Offset(-5, -48),
                child: IgnorePointer(
                  ignoring: !widget.interactive,
                  child: MiniPhoneEntryBubble(
                    avatar: _arriving ? _arrivalAvatar : null,
                    playRequested: _music.playRequested,
                    onTap: () => _music.userToggle('dock'),
                  ),
                ),
              ),
            ),
          ),
    child: CompositedTransformTarget(
      link: _entryLink,
      child: Semantics(
        label: context.l10n.miniPhoneOpenUnread(count: _unread),
        button: true,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: Listenable.merge([_arrival, _musicPulse]),
            builder: (context, _) => SizedBox(
              width: 34,
              height: 57,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  MiniPhoneEntryArtwork(
                    skin: _resolvedStyle(context).skin,
                    unread: _unread > 0,
                    showMusic: _music.entryActivated && _unread == 0,
                    playing: _music.playing,
                    arriving: _arriving,
                    arrivalProgress: _arrival.value,
                    musicProgress: _musicPulse.value,
                    clockTime: _session.entryClockTime,
                    reducedMotion: _reducedMotion,
                  ),
                  if (_unread > 0)
                    Positioned(
                      right: -5,
                      top: -6,
                      child: MiniPhoneEntryBadge(count: _unread),
                    ),
                  if (_arriving && !_music.entryActivated)
                    Positioned(
                      left: -1,
                      top: -44,
                      child: IgnorePointer(
                        child: entryAvatarMotion
                            .sample(_arrival.value)
                            .apply(
                              MiniPhoneEntryBubble(avatar: _arrivalAvatar),
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Local UI position only; the handle snaps to a side after every drag.
class MiniPhoneEdgeDock extends StatefulWidget {
  const MiniPhoneEdgeDock({
    super.key,
    required this.topInset,
    required this.bottomInset,
    required this.onPressed,
    this.positionStore,
    this.worldId = '',
    this.leftBottomInset,
    this.style,
    this.viewport,
    this.visible = true,
    this.interactive = true,
    this.layoutIdentity,
    this.followViewportChanges = false,
  });
  final MiniPhoneEntryStyle? style;
  final String worldId;
  final double topInset, bottomInset;
  final double? leftBottomInset;
  final MiniPhoneDockPosition? positionStore;

  /// Resting scene bounds in this dock's stable coordinate system.
  final Rect? viewport;
  final bool visible, interactive, followViewportChanges;
  final Object? layoutIdentity;
  final void Function(MiniPhoneSession session) onPressed;
  @override
  State<MiniPhoneEdgeDock> createState() => _MiniPhoneEdgeDockState();
}

class _MiniPhoneEdgeDockState extends State<MiniPhoneEdgeDock> {
  late final MiniPhoneSession _session;
  late final bool _ownsSession;
  late MiniPhoneDockPosition _positionStore;
  final _viewportKey = GlobalKey();
  double? _viewportOriginY;
  bool _measurementScheduled = false;
  Offset? _drag;
  bool _followingViewport = false;
  @override
  void initState() {
    super.initState();
    final inherited = MiniPhoneSessionScope.read(context);
    _ownsSession = inherited == null;
    _session = inherited ?? MiniPhoneSession.forWorld(context, widget.worldId);
    _positionStore = widget.positionStore ?? miniPhoneDockPosition;
    _positionStore.addListener(_positionChanged);
    unawaited(_positionStore.load());
  }

  void _positionChanged() {
    if (mounted) setState(() {});
  }

  void _measureViewport(double fallbackTop, double screenHeight) {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    final store = _positionStore;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted || !identical(store, _positionStore)) return;
      final element = _viewportKey.currentContext;
      if (element is! RenderObjectElement) return;
      final box = element.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final origin = box.localToGlobal(Offset.zero).dy;
      if (_viewportOriginY == null || (_viewportOriginY! - origin).abs() > .1) {
        setState(() => _viewportOriginY = origin);
      }
      if (screenHeight > 0) {
        store.initializeScreenY((origin + fallbackTop) / screenHeight);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MiniPhoneEdgeDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followingViewport =
        widget.followViewportChanges &&
        oldWidget.layoutIdentity == widget.layoutIdentity &&
        oldWidget.viewport != widget.viewport;
    if (!widget.interactive) _drag = null;
    final next = widget.positionStore ?? miniPhoneDockPosition;
    if (!identical(_positionStore, next)) {
      _positionStore.removeListener(_positionChanged);
      _positionStore = next..addListener(_positionChanged);
      unawaited(_positionStore.load());
    }
  }

  @override
  void dispose() {
    _positionStore.removeListener(_positionChanged);
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniPhoneSessionScope.watch(context);
    return ListenableBuilder(
      listenable: _session.data ?? _session.music,
      builder: (context, _) {
        final ready =
            scope?.worldDetailReady ??
            (_session.data?.worldDetailLoaded ?? _session.worldId.isEmpty);
        // Do not mount the icon or its music/avatar overlays until the World
        // snapshot has resolved. A loaded null map_style can then use Classic.
        return ready
            ? Offstage(
                offstage: !widget.visible,
                child: TickerMode(
                  enabled: widget.visible,
                  child: IgnorePointer(
                    ignoring: !widget.interactive,
                    child: _buildDock(context),
                  ),
                ),
              )
            : const SizedBox.shrink();
      },
    );
  }

  Widget _buildDock(BuildContext context) => LayoutBuilder(
    key: _viewportKey,
    builder: (context, bounds) {
      const inset = 12.0;
      final viewport = widget.viewport ?? Offset.zero & bounds.biggest;
      final left = viewport.left + inset;
      final right = math.max(left, viewport.right - inset - 34);
      final top = math.min(
        viewport.top + widget.topInset + 48,
        math.max(viewport.top, viewport.bottom - 57),
      );
      final dragBottomInset = widget.leftBottomInset ?? widget.bottomInset;
      double bottomForSide(bool rightSide) => math.max(
        top,
        viewport.bottom -
            (rightSide ? widget.bottomInset : dragBottomInset) -
            57,
      );
      // Follow the finger across both halves; avoid right-side controls only
      // after release, using the existing snap animation.
      final bottom = _drag != null
          ? math.max(top, viewport.bottom - dragBottomInset - 57)
          : bottomForSide(_positionStore.right);
      final screenHeight = MediaQuery.sizeOf(context).height;
      final fallbackTop = top + (bottom - top) * _positionStore.vertical;
      _measureViewport(fallbackTop, screenHeight);
      final settled = Offset(
        _positionStore.right ? right : left,
        _positionStore.screenY == null
            ? fallbackTop
            : _positionStore.screenY! * screenHeight - (_viewportOriginY ?? 0),
      );
      final position = _drag ?? settled;
      final clamped = Offset(
        position.dx.clamp(left, right),
        position.dy.clamp(top, bottom),
      );
      void snap() {
        final released = _drag ?? clamped;
        final rightSide = released.dx + 17 >= viewport.center.dx;
        setState(() {
          _drag = null;
        });
        unawaited(
          _positionStore.save(
            rightSide,
            (released.dy + (_viewportOriginY ?? 0)) / screenHeight,
          ),
        );
      }

      if (_viewportOriginY == null || !_positionStore.loaded) {
        return const SizedBox.expand();
      }
      return Stack(
        children: [
          AnimatedPositioned(
            duration:
                _drag != null ||
                    _followingViewport ||
                    MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: clamped.dx,
            top: clamped.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => setState(() {
                _drag = clamped;
              }),
              onPanUpdate: (details) => setState(() {
                final next = (_drag ?? clamped) + details.delta;
                _drag = Offset(
                  next.dx.clamp(left, right),
                  next.dy.clamp(top, bottom),
                );
              }),
              onPanEnd: (_) => snap(),
              onPanCancel: snap,
              child: MiniPhoneEntry(
                visible: widget.visible,
                interactive: widget.interactive,
                style: widget.style,
                session: _session,
                onPressed: () => widget.onPressed(_session),
              ),
            ),
          ),
        ],
      );
    },
  );
}
