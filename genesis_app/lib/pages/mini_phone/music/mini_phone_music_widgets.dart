import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../network/models/music.dart';
import '../../../ui/components/genesis_static_network_image.dart';
import '../../../ui/tokens/genesis_colors.dart';
import '../../../utils/genesis_image_resource.dart';
import '../shared/mini_phone_ui.dart';

/// Stable across progress rebuilds; only text, identity or geometry reset it.
class MiniMusicMarquee extends StatefulWidget {
  const MiniMusicMarquee({
    super.key,
    required this.text,
    required this.style,
    required this.identity,
    this.active = true,
  });
  final String text;
  final TextStyle style;
  final Object identity;
  final bool active;
  @override
  State<MiniMusicMarquee> createState() => _MiniMusicMarqueeState();
}

class _MiniMusicMarqueeState extends State<MiniMusicMarquee>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  Object? _metrics;
  double _distance = 0;
  double _travelSeconds = 0;
  bool _visible = false;
  bool _foreground = true;
  bool _enabled = false;
  bool _resetPending = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
  }

  void _sync() {
    if (!mounted) return;
    if (_resetPending) {
      _resetPending = false;
      _motion.reset();
      _motion.duration = Duration(
        milliseconds: ((4 + 2 * _travelSeconds) * 1000).round(),
      );
    }
    if (_enabled && _distance > 0) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  double _offset() {
    if (_resetPending || _distance <= 0) return 0;
    final seconds = _motion.value * (4 + 2 * _travelSeconds);
    if (seconds <= 2) return 0;
    if (seconds < 2 + _travelSeconds) return (seconds - 2) * 20;
    if (seconds <= 4 + _travelSeconds) return _distance;
    return (_distance - (seconds - 4 - _travelSeconds) * 20).clamp(
      0,
      _distance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    _enabled =
        widget.active &&
        _visible &&
        _foreground &&
        !reduced &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    return VisibilityDetector(
      key: ObjectKey(this),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0;
        if (mounted && visible != _visible) setState(() => _visible = visible);
      },
      child: LayoutBuilder(
        builder: (context, bounds) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          final height = painter.height;
          painter.dispose();
          final available = bounds.hasBoundedWidth ? bounds.maxWidth : width;
          final metrics = (
            widget.identity,
            widget.text,
            style,
            scaler,
            direction,
            available,
          );
          if (_metrics != metrics) {
            _metrics = metrics;
            _distance = (width - available).clamp(0, double.infinity);
            _travelSeconds = _distance / 20;
            _resetPending = true;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
          final text = Text(
            widget.text,
            maxLines: 1,
            softWrap: false,
            overflow: reduced ? TextOverflow.ellipsis : TextOverflow.visible,
            style: widget.style,
          );
          return Semantics(
            label: widget.text,
            child: ExcludeSemantics(
              child: SizedBox(
                height: height,
                child: reduced || _distance == 0
                    ? text
                    : ClipRect(
                        child: AnimatedBuilder(
                          animation: _motion,
                          builder: (_, _) => Transform.translate(
                            offset: Offset(
                              (direction == TextDirection.rtl ? 1 : -1) *
                                  _offset(),
                              0,
                            ),
                            child: OverflowBox(
                              alignment: AlignmentDirectional.centerStart,
                              minWidth: width,
                              maxWidth: width,
                              child: text,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }
}

/// Both rendering and prefetch use precisely the same URL and decoder key.
ImageProvider<Object> miniMusicCoverProvider(
  MusicTrack track,
  Size size,
  double dpr,
) {
  final ratio = genesisImageDevicePixelRatio(dpr);
  final resource = GenesisImageResourceRegistry.register(
    GenesisImageResource(legacyUrl: track.coverUrl, xlUrl: track.coverUrl),
  );
  final url = selectGenesisImageUrl(
    resource,
    logicalWidth: size.width,
    logicalHeight: size.height,
    devicePixelRatio: dpr,
  );
  if (url.startsWith('assets/')) return AssetImage(url);
  return GenesisStaticNetworkImageProvider(
    imageUrl: url,
    cacheWidth: (size.width * ratio).ceil(),
    cacheHeight: (size.height * ratio).ceil(),
    fit: BoxFit.cover,
  );
}

class MiniMusicCover extends StatefulWidget {
  const MiniMusicCover({
    super.key,
    required this.track,
    required this.width,
    required this.height,
    required this.radius,
    this.nextTrack,
    this.preloadNext = false,
  });
  final MusicTrack track;
  final MusicTrack? nextTrack;
  final double width, height, radius;
  final bool preloadNext;
  @override
  State<MiniMusicCover> createState() => _MiniMusicCoverState();
}

class _MiniMusicCoverState extends State<MiniMusicCover> {
  static final _inflight = <ImageProvider<Object>, Future<void>>{};
  Object? _prefetchAttempt;
  bool _visible = false;

  void _prefetch(ImageProvider<Object> provider, Object attempt) {
    if (_prefetchAttempt == attempt) return;
    _prefetchAttempt = attempt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_visible ||
          !widget.preloadNext ||
          _prefetchAttempt != attempt) {
        return;
      }
      if (_inflight.containsKey(provider)) return;
      final pending = precacheImage(provider, context, onError: (_, _) {});
      _inflight[provider] = pending;
      unawaited(
        pending.whenComplete(() {
          if (identical(_inflight[provider], pending)) {
            _inflight.remove(provider);
          }
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.width, widget.height);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final provider = miniMusicCoverProvider(widget.track, size, dpr);
    final next = widget.nextTrack;
    if (!widget.preloadNext || !_visible) _prefetchAttempt = null;
    if (widget.preloadNext && _visible && next != null) {
      final nextProvider = miniMusicCoverProvider(next, size, dpr);
      _prefetch(nextProvider, (widget.track.file, next.file, nextProvider));
    }
    return VisibilityDetector(
      key: ObjectKey(this),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0;
        if (mounted && visible != _visible) setState(() => _visible = visible);
      },
      child: Semantics(
        image: true,
        label: '${widget.track.title} cover',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: AnimatedSwitcher(
              duration: duration,
              layoutBuilder: (current, outgoing) => Stack(
                fit: StackFit.expand,
                children: [
                  if (!reduced && outgoing.isNotEmpty) outgoing.last,
                  if (current != null) current,
                ],
              ),
              child: _MiniMusicCoverFrame(
                key: ValueKey((widget.track.file, widget.track.coverUrl)),
                provider: provider,
                duration: duration,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMusicCoverFrame extends StatelessWidget {
  const _MiniMusicCoverFrame({
    super.key,
    required this.provider,
    required this.duration,
  });
  final ImageProvider<Object> provider;
  final Duration duration;
  Widget _placeholder() => const ColoredBox(color: GenesisColors.darkFaintFill);
  @override
  Widget build(BuildContext context) => Image(
    image: provider,
    fit: BoxFit.cover,
    gaplessPlayback: false,
    frameBuilder: (context, child, frame, synchronous) {
      if (frame == null) return _placeholder();
      if (synchronous || duration == Duration.zero) return child;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        child: child,
        builder: (_, opacity, image) => Stack(
          fit: StackFit.expand,
          children: [
            _placeholder(),
            Opacity(opacity: opacity, child: image),
          ],
        ),
      );
    },
    errorBuilder: (_, _, _) => _placeholder(),
  );
}

/// One gesture submits one seek. Position previews do not call the decoder.
class MiniMusicSeekBar extends StatefulWidget {
  const MiniMusicSeekBar({
    super.key,
    required this.identity,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.enabled,
    required this.onSeek,
    this.compact = false,
  });
  final Object identity;
  final Duration position, buffered;
  final Duration? duration;
  final bool enabled, compact;
  final Future<void> Function(Duration) onSeek;
  @override
  State<MiniMusicSeekBar> createState() => _MiniMusicSeekBarState();
}

class _MiniMusicSeekBarState extends State<MiniMusicSeekBar> {
  double? _preview;
  int _gestureRevision = 0;
  @override
  void didUpdateWidget(MiniMusicSeekBar old) {
    super.didUpdateWidget(old);
    if (old.identity != widget.identity) {
      _preview = null;
      _gestureRevision++;
    }
  }

  String _time(double milliseconds) {
    final seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _commit(double value) {
    final revision = ++_gestureRevision;
    setState(() => _preview = value);
    unawaited(
      widget.onSeek(Duration(milliseconds: value.round())).whenComplete(() {
        if (mounted && revision == _gestureRevision) {
          setState(() => _preview = null);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.duration?.inMilliseconds ?? 0)
        .clamp(0, 1 << 53)
        .toDouble();
    final value = (_preview ?? widget.position.inMilliseconds.toDouble()).clamp(
      0.0,
      total,
    );
    final enabled = widget.enabled && total > 0;
    final style = miniStyle(
      widget.compact ? 11 : 12,
      FontWeight.w400,
      miniSecondary,
    );
    final elapsed = Text(_time(value), style: style);
    final remaining = Text(
      total > 0 ? '-${_time(total - value)}' : '--:--',
      textAlign: TextAlign.right,
      style: style,
    );
    final slider = SizedBox(
      height: widget.compact ? 20 : 48,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: widget.compact ? 3 : 4,
          activeTrackColor: miniWhite,
          secondaryActiveTrackColor: GenesisColors.darkTextTertiary,
          inactiveTrackColor: const Color(0x29F4F3F6),
          thumbColor: miniWhite,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: widget.compact ? 4 : 5,
          ),
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: widget.compact ? 16 : 24,
          ),
        ),
        child: Slider(
          value: value,
          max: total > 0 ? total : 1,
          secondaryTrackValue: widget.buffered.inMilliseconds.toDouble().clamp(
            0.0,
            total,
          ),
          allowedInteraction: SliderInteraction.tapAndSlide,
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 8)
              : EdgeInsets.zero,
          semanticFormatterCallback: (value) =>
              '${_time(value)} of ${_time(total)}',
          onChanged: enabled
              ? (value) => setState(() => _preview = value)
              : null,
          onChangeEnd: enabled ? _commit : null,
        ),
      ),
    );
    if (widget.compact) {
      return Row(
        children: [
          SizedBox(width: 32, child: elapsed),
          Expanded(child: slider),
          SizedBox(width: 38, child: remaining),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        slider,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [elapsed, remaining],
        ),
      ],
    );
  }
}
