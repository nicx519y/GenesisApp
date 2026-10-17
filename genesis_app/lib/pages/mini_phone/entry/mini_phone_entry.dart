import 'mini_phone_dock_position.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../ui/components/genesis_avatar.dart';
import '../session/mini_phone_session.dart';
import '../preview/mini_phone_demo_store.dart';
import '../preview/mini_phone_preview_avatar.dart';
import '../music/mini_phone_music_service.dart';
import '../shared/mini_phone_ui.dart';

class MiniPhoneEntry extends StatefulWidget {
  const MiniPhoneEntry({super.key, required this.onPressed, this.session});
  final MiniPhoneSession? session;
  final VoidCallback onPressed;
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
  MiniPhoneDemoStore get _store => _session.store;
  int _unread = 0;
  int get _currentUnread =>
      _session.data?.totalUnreadCount ?? _store.totalUnread;
  Widget get _arrivalAvatar {
    final data = _session.data;
    if (data == null) return MiniAvatar(miniDemoPeople.first, size: 32);
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
      duration: const Duration(seconds: 3),
    );
    _musicPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _music.addListener(_musicChanged);
    _unread = _currentUnread;
    _store.addListener(_changed);
    _session.data?.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _musicChanged();
      if (mounted && _unread > 0 && !MediaQuery.disableAnimationsOf(context)) {
        _arrival.forward();
      }
    });
  }

  void _musicChanged() {
    if (!mounted) return;
    if (_music.playing && !MediaQuery.disableAnimationsOf(context)) {
      if (!_musicPulse.isAnimating) _musicPulse.repeat();
    } else {
      _musicPulse.stop();
    }
    if (_music.activated) {
      if (_music.track == null) _session.ensureMusicCatalog();
      _musicOverlay.show();
    } else {
      _musicOverlay.hide();
    }
    setState(() {});
  }

  void _changed() {
    final unread = _currentUnread;
    if (unread > _unread && !MediaQuery.disableAnimationsOf(context)) {
      _arrival.forward(from: 0);
    }
    if (unread == 0) _arrival.stop();
    setState(() => _unread = unread);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
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
    overlayChildBuilder: (_) => ModalRoute.of(context)?.isCurrent == false
        ? const SizedBox.shrink()
        : AnimatedBuilder(
            animation: _arrival,
            builder: (context, _) => Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _entryLink,
                showWhenUnlinked: false,
                offset: const Offset(-1, -48),
                child: _MiniPhonePopup(
                  child: Material(
                    color: const Color(0xFF303435),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _music.toggle,
                      child: Tooltip(
                        message: _music.playRequested
                            ? 'Pause music'
                            : 'Play music',
                        child: Semantics(
                          button: true,
                          label: _music.playRequested
                              ? 'Pause music'
                              : 'Play music',
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_unread > 0 && _arrival.isAnimating)
                                _arrivalAvatar,
                              if (_unread > 0 && _arrival.isAnimating)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 17,
                                    height: 17,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF303435),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: MiniIcon(
                                        _music.playRequested
                                            ? 'music-pause'
                                            : 'music-play',
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                MiniIcon(
                                  _music.playRequested
                                      ? 'music-pause'
                                      : 'music-play',
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
    child: CompositedTransformTarget(
      link: _entryLink,
      child: Semantics(
        label: 'Open Mini phone, $_unread unread messages',
        button: true,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: Listenable.merge([_arrival, _musicPulse]),
            builder: (context, child) {
              final seconds = _arrival.value * 3;
              final vibrating = _arrival.isAnimating && seconds < .76;
              final wave = vibrating
                  ? math.sin(seconds / .76 * math.pi * 8) * (1 - seconds / .76)
                  : 0.0;
              final music = _music.activated;
              final visible = _unread > 0 && _arrival.isAnimating;
              final alpha = visible
                  ? (_arrival.value < .1
                        ? _arrival.value / .1
                        : _arrival.value > .85
                        ? (1 - _arrival.value) / .15
                        : 1.0)
                  : 0.0;
              final reveal = (_arrival.isAnimating ? seconds / .9 : 1.0).clamp(
                0.0,
                1.0,
              );
              return SizedBox(
                width: 34,
                height: 57,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Transform.translate(
                      offset: Offset(wave * 1.2, 0),
                      child: Transform.rotate(
                        angle: wave * math.pi / 22,
                        child: child,
                      ),
                    ),
                    if (_unread > 0)
                      Positioned(
                        right: -5,
                        top: -6,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 17),
                          height: 17,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: miniRed,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '$_unread',
                              style: miniStyle(
                                9,
                                FontWeight.w600,
                              ).copyWith(height: 1),
                            ),
                          ),
                        ),
                      ),
                    if (music && _unread == 0) ...[
                      Positioned(
                        top: 26,
                        left: 9,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: _music.playing
                                ? .9 +
                                      .1 *
                                          math.sin(
                                            _musicPulse.value * math.pi * 2,
                                          )
                                : .55,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                _music.playing
                                    ? math.cos(_musicPulse.value * math.pi * 2)
                                    : 0,
                              ),
                              child: Transform.rotate(
                                angle: _music.playing
                                    ? math.sin(
                                            _musicPulse.value * math.pi * 2,
                                          ) *
                                          math.pi /
                                          30
                                    : 0,
                                child: const MiniIcon(
                                  'music-musical-note',
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (visible && !music)
                      Positioned(
                        left: -1,
                        top: -48,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: alpha.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, (1 - alpha) * 8),
                              child: _MiniPhonePopup(child: _arrivalAvatar),
                            ),
                          ),
                        ),
                      ),
                    if (_unread > 0)
                      Positioned(
                        top: 28,
                        left: 5,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: reveal,
                            child: Transform.translate(
                              offset: Offset(0, (1 - reveal) * 7),
                              child: Container(
                                width: 24,
                                height: 12,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0x1CFFFFFF),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF929294),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 1.5,
                                          color: const Color(0xFFC9C9CB),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          width: 7,
                                          height: 1.5,
                                          color: const Color(0xFF8D8D90),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            child: Container(
              width: 34,
              height: 57,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
                color: const Color(0xFF232228),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(width: 11, height: 2, color: Colors.white),
                  const SizedBox(height: 6),
                  Text(
                    '01:04',
                    style: miniStyle(
                      7,
                      FontWeight.w900,
                    ).copyWith(height: 1, letterSpacing: -.175),
                  ),
                  const Spacer(),
                  Container(width: 12, height: 2, color: Colors.white),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MiniPhonePopup extends StatelessWidget {
  const _MiniPhonePopup({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 41,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MiniPhonePopupPainter())),
        Positioned(
          left: 2,
          top: 2,
          width: 32,
          height: 32,
          child: ClipOval(child: child),
        ),
      ],
    ),
  );
}

class _MiniPhonePopupPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final circle = Path()..addOval(const Rect.fromLTWH(0, 0, 36, 36));
    final pointer = Path()
      ..moveTo(12, 34)
      ..lineTo(24, 34)
      ..lineTo(18, 41)
      ..close();
    final frame = Path.combine(PathOperation.union, circle, pointer);
    canvas.drawShadow(frame, Colors.black38, 3, false);
    canvas.drawPath(frame, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_MiniPhonePopupPainter oldDelegate) => false;
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
  });
  final String worldId;
  final double topInset, bottomInset;
  final double? leftBottomInset;
  final MiniPhoneDockPosition? positionStore;
  final void Function(MiniPhoneSession session) onPressed;
  @override
  State<MiniPhoneEdgeDock> createState() => _MiniPhoneEdgeDockState();
}

class _MiniPhoneEdgeDockState extends State<MiniPhoneEdgeDock> {
  late final MiniPhoneSession _session;
  late final bool _ownsSession;
  late bool _right;
  late double _vertical;
  MiniPhoneDockPosition get _positionStore =>
      widget.positionStore ?? miniPhoneDockPosition;
  bool _userMoved = false;
  Offset? _drag;
  @override
  void initState() {
    super.initState();
    final inherited = MiniPhoneSessionScope.read(context);
    _ownsSession = inherited == null;
    _session = inherited ?? MiniPhoneSession.forWorld(context, widget.worldId);
    _right = _positionStore.right;
    _vertical = _positionStore.vertical;
    unawaited(
      _positionStore.load().then((_) {
        if (!mounted || _userMoved) return;
        setState(() {
          _right = _positionStore.right;
          _vertical = _positionStore.vertical;
        });
      }),
    );
  }

  @override
  void dispose() {
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      const inset = 12.0;
      final left = inset;
      final right = math.max(left, bounds.maxWidth - inset - 34);
      final top = math.min(
        widget.topInset + 48,
        math.max(0.0, bounds.maxHeight - 57),
      );
      final dragSideRight =
          (_drag?.dx ?? (_right ? right : left)) + 17 >= bounds.maxWidth / 2;
      final bottomInset = dragSideRight
          ? widget.bottomInset
          : (widget.leftBottomInset ?? widget.bottomInset);
      final bottom = math.max(top, bounds.maxHeight - bottomInset - 57);
      final settled = Offset(
        _right ? right : left,
        top + (bottom - top) * _vertical,
      );
      final position = _drag ?? settled;
      final clamped = Offset(
        position.dx.clamp(left, right),
        position.dy.clamp(top, bottom),
      );
      void snap() {
        setState(() {
          final released = _drag ?? clamped;
          _right = released.dx + 17 >= bounds.maxWidth / 2;
          _vertical = bottom > top
              ? ((released.dy - top) / (bottom - top)).clamp(0.0, 1.0)
              : 0;
          _drag = null;
        });
        unawaited(_positionStore.save(_right, _vertical));
      }

      return Stack(
        children: [
          AnimatedPositioned(
            duration: _drag != null || MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: clamped.dx,
            top: clamped.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => setState(() {
                _userMoved = true;
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
