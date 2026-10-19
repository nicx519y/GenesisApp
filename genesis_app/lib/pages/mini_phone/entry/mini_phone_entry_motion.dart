import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Native equivalents of the handoff's CSS keyframes. The same sampler handles
/// body arrival, unread reveals, avatar popups, and looping music for every skin.
class EntryKeyframe {
  const EntryKeyframe(
    this.time, {
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.opacity = 1,
    this.scale = 1,
    this.glow = 0,
  });
  final double time, x, y, rotation, opacity, scale, glow;

  Widget apply(Widget child, {Alignment alignment = Alignment.center}) =>
      Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(x, y),
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            alignment: alignment,
            child: Transform.scale(
              scale: scale,
              alignment: alignment,
              child: child,
            ),
          ),
        ),
      );
}

class EntryMotion {
  const EntryMotion(
    this.durationMs,
    this.frames, {
    this.curve = Curves.easeInOut,
  });
  final int durationMs;
  final List<EntryKeyframe> frames;
  final Curve curve;

  EntryKeyframe sample(double progress) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= frames.first.time) return frames.first;
    if (t >= frames.last.time) return frames.last;
    for (var i = 1; i < frames.length; i++) {
      final a = frames[i - 1], b = frames[i];
      if (t > b.time) continue;
      final f = curve.transform(
        ((t - a.time) / (b.time - a.time)).clamp(0.0, 1.0),
      );
      double mix(double x, double y) => x + (y - x) * f;
      return EntryKeyframe(
        t,
        x: mix(a.x, b.x),
        y: mix(a.y, b.y),
        rotation: mix(a.rotation, b.rotation),
        opacity: mix(a.opacity, b.opacity),
        scale: mix(a.scale, b.scale),
        glow: mix(a.glow, b.glow),
      );
    }
    return frames.last;
  }

  EntryKeyframe atMilliseconds(double elapsed) => sample(elapsed / durationMs);
}

const entryAvatarMotion = EntryMotion(3000, [
  EntryKeyframe(0, opacity: 0, y: 4, scale: .85),
  EntryKeyframe(.1, scale: 1.04),
  EntryKeyframe(.18),
  EntryKeyframe(.85),
  EntryKeyframe(1, opacity: 0, y: -2.5, scale: .94),
], curve: Curves.ease);

const entryMusicMotion = EntryMotion(1400, [
  EntryKeyframe(0, opacity: .8, y: 1, rotation: -6),
  EntryKeyframe(.5, y: -1, rotation: 6),
  EntryKeyframe(1, opacity: .8, y: 1, rotation: -6),
]);
