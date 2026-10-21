import 'package:flutter/material.dart';

import '../../../network/models/music.dart';
import 'mini_phone_music_widgets.dart';

/// Keeps both covers attached to the finger; commits playback only after settling.
class MiniMusicCoverSwipe extends StatefulWidget {
  const MiniMusicCoverSwipe({
    super.key,
    required this.track,
    required this.previousTrack,
    required this.nextTrack,
    required this.width,
    required this.height,
    required this.enabled,
    required this.preloadNext,
    required this.onNext,
    required this.onPrevious,
  });

  final MusicTrack track;
  final MusicTrack? previousTrack, nextTrack;
  final double width, height;
  final bool enabled, preloadNext;
  final VoidCallback onNext, onPrevious;

  @override
  State<MiniMusicCoverSwipe> createState() => _MiniMusicCoverSwipeState();
}

class _MiniMusicCoverSwipeState extends State<MiniMusicCoverSwipe>
    with SingleTickerProviderStateMixin {
  late final _offset = AnimationController.unbounded(vsync: this);
  bool _settling = false;
  int _gestureRevision = 0;
  double get _extent => widget.width + 12;
  bool get _canSwipe =>
      widget.enabled &&
      widget.previousTrack != null &&
      widget.nextTrack != null;

  @override
  void didUpdateWidget(covariant MiniMusicCoverSwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.file != widget.track.file ||
        oldWidget.width != widget.width ||
        (oldWidget.enabled && !widget.enabled)) {
      _gestureRevision++;
      _offset.stop();
      _offset.value = 0;
      _settling = false;
    }
  }

  Future<void> _settle({double velocity = 0, bool canceled = false}) async {
    if (_settling) return;
    final revision = ++_gestureRevision;
    final distance = _offset.value * _extent;
    final sameDirection = velocity * distance >= 0;
    final commit =
        !canceled &&
        _canSwipe &&
        (distance.abs() >= 48 || (velocity.abs() >= 700 && sameDirection));
    final target = commit ? (distance < 0 ? -1.0 : 1.0) : 0.0;
    _settling = true;
    try {
      await _offset
          .animateTo(
            target,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      if (!mounted || revision != _gestureRevision) return;
      if (commit) {
        target < 0 ? widget.onNext() : widget.onPrevious();
        // A guarded playback command may decline the change. Return the cover
        // in that case; a changed track resets the offset in didUpdateWidget.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && revision == _gestureRevision) {
            _settling = false;
            _settle(canceled: true);
          }
        });
      } else {
        _settling = false;
      }
    } on TickerCanceled {
      // Track changes, rotation, or closing the player cancel only this motion.
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: _canSwipe
        ? (_) {
            if (_settling) return;
            _gestureRevision++;
            _offset.stop();
          }
        : null,
    onHorizontalDragUpdate: _canSwipe
        ? (details) {
            if (!_settling && _extent > 0) {
              _offset.value = (_offset.value + details.delta.dx / _extent)
                  .clamp(-1, 1);
            }
          }
        : null,
    onHorizontalDragEnd: _canSwipe
        ? (details) => _settle(velocity: details.primaryVelocity ?? 0)
        : null,
    onHorizontalDragCancel: _canSwipe ? () => _settle(canceled: true) : null,
    child: Listener(
      onPointerCancel: (_) {
        _gestureRevision++;
        _offset.stop();
        _settling = false;
        _settle(canceled: true);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, _) {
            final adjacent = _offset.value > 0
                ? widget.previousTrack
                : widget.nextTrack;
            Widget cover(MusicTrack track, double x, {bool current = false}) =>
                Transform.translate(
                  key: ValueKey(track.file),
                  offset: Offset(x, 0),
                  child: MiniMusicCover(
                    track: track,
                    nextTrack: current ? widget.nextTrack : null,
                    preloadNext: current && widget.preloadNext,
                    width: widget.width,
                    height: widget.height,
                    radius: 16,
                  ),
                );
            return SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                children: [
                  cover(widget.track, _offset.value * _extent, current: true),
                  if (_offset.value != 0 && adjacent != null)
                    cover(
                      adjacent,
                      (_offset.value + (_offset.value > 0 ? -1 : 1)) * _extent,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }
}
