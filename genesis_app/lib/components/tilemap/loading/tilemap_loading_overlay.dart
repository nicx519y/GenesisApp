import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tilemap_renderer.dart';
import '../tilemap_settings_store.dart';

class TilemapLoadingOverlay extends StatefulWidget {
  const TilemapLoadingOverlay({
    super.key,
    required this.style,
    required this.progress,
    required this.visualMode,
    this.backgroundKey,
  });

  final TilemapLoadingStyle style;
  final double progress;
  final TilemapVisualMode visualMode;
  final Key? backgroundKey;

  @override
  State<TilemapLoadingOverlay> createState() => _TilemapLoadingOverlayState();
}

class _TilemapLoadingOverlayState extends State<TilemapLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  bool _animationsDisabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant TilemapLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) _syncMotion();
  }

  void _syncMotion() {
    final shouldAnimate =
        !_animationsDisabled &&
        widget.style != TilemapLoadingStyle.disabled &&
        widget.style != TilemapLoadingStyle.minimalProgress;
    if (shouldAnimate) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion
        ..stop()
        ..value = 0.36;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualStyle = tilemapVisualStyleFor(widget.visualMode);
    final palette = _TilemapLoadingPalette.resolve(
      visualMode: widget.visualMode,
      backgroundColor: visualStyle.backgroundColor,
    );
    final progress = widget.progress.isFinite
        ? widget.progress.clamp(0.0, 1.0).toDouble()
        : 0.0;

    if (widget.style == TilemapLoadingStyle.disabled) {
      return ColoredBox(
        key: widget.backgroundKey,
        color: Colors.transparent,
        child: SizedBox.expand(
          key: const ValueKey<String>('tilemap-loading-overlay'),
          child: KeyedSubtree(
            key: ValueKey<String>('tilemap-loading-style-${widget.style.name}'),
            child: const SizedBox.shrink(),
          ),
        ),
      );
    }

    if (widget.style == TilemapLoadingStyle.minimalProgress) {
      return ColoredBox(
        key: widget.backgroundKey,
        color: Colors.black,
        child: SizedBox.expand(
          key: const ValueKey<String>('tilemap-loading-overlay'),
          child: KeyedSubtree(
            key: ValueKey<String>('tilemap-loading-style-${widget.style.name}'),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: SizedBox(
                    width: math.min(280, constraints.maxWidth * 0.64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: 'Loading map',
                          value: '${(progress * 100).round()}%',
                          child: LinearProgressIndicator(
                            key: const ValueKey<String>(
                              'tilemap-loading-progress',
                            ),
                            value: progress,
                            minHeight: 3,
                            backgroundColor: const Color(0xFF292929),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2F9663),
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '${(progress * 100).round()}%',
                          key: const ValueKey<String>(
                            'tilemap-loading-percent',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF2F9663),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      key: widget.backgroundKey,
      color: palette.background,
      child: SizedBox.expand(
        key: const ValueKey<String>('tilemap-loading-overlay'),
        child: KeyedSubtree(
          key: ValueKey<String>('tilemap-loading-style-${widget.style.name}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, child) => RepaintBoundary(
                    child: CustomPaint(
                      painter: _TilemapLoadingAtmospherePainter(
                        style: widget.style,
                        palette: palette,
                        progress: progress,
                        phase: _motion.value,
                      ),
                      isComplex: true,
                      willChange: !_animationsDisabled,
                    ),
                  ),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 420.0;
                    final height = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : 700.0;
                    final compact = height < 430;
                    final motifExtent = math
                        .min(
                          width * 0.92,
                          math.min(520.0, height - (compact ? 102 : 150)),
                        )
                        .clamp(86.0, 520.0)
                        .toDouble();
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: motifExtent,
                            child: AnimatedBuilder(
                              animation: _motion,
                              builder: (context, child) => RepaintBoundary(
                                child: CustomPaint(
                                  painter: _TilemapLoadingMotifPainter(
                                    style: widget.style,
                                    palette: palette,
                                    progress: progress,
                                    phase: _motion.value,
                                  ),
                                  isComplex: true,
                                  willChange: !_animationsDisabled,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 22),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: _TilemapLoadingStatus(
                              progress: progress,
                              palette: palette,
                              compact: compact,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TilemapLoadingStatus extends StatelessWidget {
  const _TilemapLoadingStatus({
    required this.progress,
    required this.palette,
    required this.compact,
  });

  final double progress;
  final _TilemapLoadingPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Semantics(
      label: 'Building the world',
      value: '$percent%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            painter: _TilemapStatusSparkPainter(palette: palette),
            child: SizedBox.square(dimension: compact ? 16 : 22),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            'BUILDING THE WORLD',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.foreground,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w400,
              letterSpacing: 3,
              height: 1.2,
            ),
          ),
          SizedBox(height: compact ? 9 : 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 2, color: palette.track),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF875BFF),
                      Color(0xFFC39CFF),
                      Color(0xFFFFD179),
                    ],
                  ).createShader(bounds),
                  child: LinearProgressIndicator(
                    key: const ValueKey<String>('tilemap-loading-progress'),
                    value: progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$percent%',
            key: const ValueKey<String>('tilemap-loading-percent'),
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _TilemapLoadingPalette {
  const _TilemapLoadingPalette({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.faint,
    required this.track,
    required this.purple,
    required this.gold,
    required this.mint,
    required this.isDark,
  });

  factory _TilemapLoadingPalette.resolve({
    required TilemapVisualMode visualMode,
    required Color backgroundColor,
  }) {
    final isDark = visualMode == TilemapVisualMode.dark;
    final foreground = isDark
        ? const Color(0xFFF7F4EE)
        : const Color(0xFF24221E);
    return _TilemapLoadingPalette(
      background: isDark
          ? Color.lerp(backgroundColor, const Color(0xFF08090E), 0.85)!
          : backgroundColor,
      foreground: foreground,
      muted: foreground.withValues(alpha: isDark ? 0.56 : 0.50),
      faint: foreground.withValues(alpha: isDark ? 0.10 : 0.08),
      track: foreground.withValues(alpha: isDark ? 0.12 : 0.10),
      purple: const Color(0xFF875BFF),
      gold: const Color(0xFFFFD179),
      mint: const Color(0xFF8DE5C4),
      isDark: isDark,
    );
  }

  final Color background;
  final Color foreground;
  final Color muted;
  final Color faint;
  final Color track;
  final Color purple;
  final Color gold;
  final Color mint;
  final bool isDark;
}

class _TilemapStatusSparkPainter extends CustomPainter {
  const _TilemapStatusSparkPainter({required this.palette});

  final _TilemapLoadingPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(
        center.dx + size.width * 0.10,
        center.dy - size.height * 0.10,
        size.width,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + size.width * 0.10,
        center.dy + size.height * 0.10,
        center.dx,
        size.height,
      )
      ..quadraticBezierTo(
        center.dx - size.width * 0.10,
        center.dy + size.height * 0.10,
        0,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - size.width * 0.10,
        center.dy - size.height * 0.10,
        center.dx,
        0,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.purple.withValues(alpha: 0.50)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.34),
    );
    canvas.drawPath(path, Paint()..color = palette.purple);
  }

  @override
  bool shouldRepaint(covariant _TilemapStatusSparkPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}

class _TilemapLoadingAtmospherePainter extends CustomPainter {
  const _TilemapLoadingAtmospherePainter({
    required this.style,
    required this.palette,
    required this.progress,
    required this.phase,
  });

  final TilemapLoadingStyle style;
  final _TilemapLoadingPalette palette;
  final double progress;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.43);
    final radius = size.shortestSide * 0.82;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          palette.purple.withValues(alpha: palette.isDark ? 0.07 : 0.04),
          palette.purple.withValues(alpha: 0),
        ]),
    );

    switch (style) {
      case TilemapLoadingStyle.tileAssembly:
        _paintIsometricGrid(canvas, size, opacity: 0.045);
        _paintAmbientSweep(canvas, size, center);
        _paintParticles(canvas, size, count: 25);
      case TilemapLoadingStyle.worldPortal:
        _paintNebula(canvas, size, center);
        _paintParticles(canvas, size, count: 32);
      case TilemapLoadingStyle.progressiveReveal:
        _paintIsometricGrid(canvas, size, opacity: 0.035);
        _paintDistantDiamonds(canvas, size, center);
        _paintParticles(canvas, size, count: 12);
      case TilemapLoadingStyle.coordinatePulse:
        _paintTopography(canvas, size, center);
        _paintParticles(canvas, size, count: 24);
      case TilemapLoadingStyle.minimalProgress:
      case TilemapLoadingStyle.disabled:
        break;
    }
    _paintVignette(canvas, size, center);
  }

  void _paintIsometricGrid(
    Canvas canvas,
    Size size, {
    required double opacity,
  }) {
    final step = (size.shortestSide * 0.095).clamp(34.0, 68.0);
    final slope = size.height * 0.62;
    final path = Path();
    for (
      var start = -size.height - step;
      start < size.width + size.height + step;
      start += step
    ) {
      path
        ..moveTo(start, 0)
        ..lineTo(start + slope, size.height)
        ..moveTo(start, 0)
        ..lineTo(start - slope, size.height);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = palette.foreground.withValues(
          alpha: palette.isDark ? opacity : opacity * 0.72,
        ),
    );
  }

  void _paintAmbientSweep(Canvas canvas, Size size, Offset center) {
    final drift = math.sin(phase * math.pi * 2) * size.shortestSide * 0.035;
    final start = Offset(
      center.dx - size.shortestSide * 0.50,
      center.dy + size.shortestSide * 0.31 + drift,
    );
    final end = Offset(
      center.dx + size.shortestSide * 0.50,
      center.dy - size.shortestSide * 0.27 + drift,
    );
    _paintLayeredGlowLine(
      canvas,
      start,
      end,
      colors: [
        palette.purple.withValues(alpha: 0.0),
        palette.purple.withValues(alpha: 0.22),
        palette.gold.withValues(alpha: 0.20),
        palette.gold.withValues(alpha: 0.0),
      ],
      width: math.max(0.8, size.shortestSide / 470),
      glowScale: 7,
    );
  }

  void _paintNebula(Canvas canvas, Size size, Offset center) {
    final shortest = size.shortestSide;
    final colors = <Color>[
      palette.purple,
      const Color(0xFFC5B5DC),
      palette.gold,
      const Color(0xFF7763A7),
      palette.mint,
    ];
    for (var index = 0; index < 18; index += 1) {
      final angle = _tilemapLoadingHash(index * 13 + 2) * math.pi * 2;
      final distance =
          shortest * (0.20 + _tilemapLoadingHash(index * 17 + 5) * 0.43);
      final motionAngle = phase * math.pi * 2 + index * 0.73;
      final drift = Offset(
        math.sin(motionAngle) * shortest * 0.012,
        math.cos(phase * math.pi * 2 + index * 0.73 * 0.83) * shortest * 0.009,
      );
      final cloudCenter =
          center +
          Offset(math.cos(angle), math.sin(angle) * 0.82) * distance +
          drift;
      final cloudRadius =
          shortest * (0.095 + _tilemapLoadingHash(index * 23 + 7) * 0.135);
      final alpha =
          (palette.isDark ? 0.145 : 0.052) +
          _tilemapLoadingHash(index * 29 + 11) *
              (palette.isDark ? 0.125 : 0.050);
      _paintSoftCloud(
        canvas,
        center: cloudCenter,
        radius: cloudRadius,
        stretch: 1.15 + _tilemapLoadingHash(index * 31 + 3) * 1.25,
        rotation: angle * 0.35,
        color: colors[index % colors.length],
        alpha: alpha,
      );
    }

    for (var index = 0; index < 5; index += 1) {
      final y = size.height * (0.64 + index * 0.07);
      final x =
          size.width *
          (0.14 + index * 0.19 + math.sin(phase * math.pi * 2 + index) * 0.012);
      _paintSoftCloud(
        canvas,
        center: Offset(x, y),
        radius: shortest * (0.10 + (index.isEven ? 0.025 : 0.0)),
        stretch: 2.0,
        rotation: -0.12 + index * 0.05,
        color: index.isEven ? const Color(0xFFC5B5DC) : palette.purple,
        alpha: palette.isDark ? 0.145 : 0.052,
      );
    }

    for (var cluster = 0; cluster < 9; cluster += 1) {
      final angle =
          -math.pi * 0.92 +
          cluster * math.pi * 0.23 +
          math.sin(phase * math.pi * 2 + cluster) * 0.025;
      final clusterCenter =
          center +
          Offset(math.cos(angle), math.sin(angle) * 0.86) *
              shortest *
              (0.33 + cluster % 3 * 0.035);
      for (var puff = 0; puff < 4; puff += 1) {
        final puffAngle = angle + (puff - 1.5) * 0.34;
        final puffCenter =
            clusterCenter +
            Offset(math.cos(puffAngle), math.sin(puffAngle)) *
                shortest *
                (0.025 + puff * 0.010);
        _paintSoftCloud(
          canvas,
          center: puffCenter,
          radius: shortest * (0.060 + (puff % 3) * 0.018),
          stretch: 1.35 + puff * 0.18,
          rotation: puffAngle * 0.40,
          color: switch ((cluster + puff) % 4) {
            0 => palette.purple,
            1 || 3 => const Color(0xFFC9BDCF),
            _ => palette.gold,
          },
          alpha: palette.isDark ? 0.13 : 0.047,
        );
      }
    }
  }

  void _paintSoftCloud(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double stretch,
    required double rotation,
    required Color color,
    required double alpha,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(stretch, 1);
    final cloudPaint = Paint()
      ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18)
      ..shader = ui.Gradient.radial(
        Offset.zero,
        radius,
        [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.54),
          color.withValues(alpha: 0),
        ],
        const [0, 0.48, 1],
      );
    canvas.drawCircle(Offset.zero, radius, cloudPaint);
    canvas.restore();
  }

  void _paintDistantDiamonds(Canvas canvas, Size size, Offset center) {
    final baseWidth = size.shortestSide * 0.11;
    final baseHeight = baseWidth * 0.48;
    for (var row = 0; row < 5; row += 1) {
      for (var column = 0; column < 5; column += 1) {
        final tileCenter = Offset(
          center.dx + (column - row) * baseWidth * 0.88,
          center.dy -
              size.shortestSide * 0.35 +
              (column + row) * baseHeight * 0.78,
        );
        final distance = (tileCenter - center).distance / size.shortestSide;
        final path = _tilemapLoadingDiamondPath(
          tileCenter,
          baseWidth,
          baseHeight,
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 + distance * 6)
            ..color = palette.foreground.withValues(
              alpha: (0.035 - distance * 0.018).clamp(0.009, 0.035),
            ),
        );
      }
    }
  }

  void _paintTopography(Canvas canvas, Size size, Offset center) {
    final maximumRadius =
        math.sqrt(size.width * size.width + size.height * size.height) * 0.70;
    for (var ring = 1; ring <= 17; ring += 1) {
      final path = Path();
      const segments = 72;
      final baseRadius = maximumRadius * ring / 17;
      for (var segment = 0; segment <= segments; segment += 1) {
        final angle = segment / segments * math.pi * 2;
        final warp =
            1 +
            math.sin(
                  angle * 3 +
                      ring * 0.73 +
                      math.sin(phase * math.pi * 2) * 0.16,
                ) *
                0.045 +
            math.sin(angle * 7 - ring * 0.39) * 0.020 +
            math.cos(angle * 11 + ring) * 0.010;
        final point = Offset(
          center.dx +
              math.cos(angle) *
                  baseRadius *
                  warp *
                  (1 + math.sin(ring * 0.41) * 0.055),
          center.dy +
              math.sin(angle) *
                  baseRadius *
                  warp *
                  (0.84 + math.cos(ring * 0.37) * 0.035),
        );
        if (segment == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring % 4 == 0 ? 0.8 : 0.55
          ..color = palette.foreground.withValues(
            alpha:
                (palette.isDark ? 0.045 : 0.036) + (ring % 4 == 0 ? 0.020 : 0),
          ),
      );
    }
  }

  void _paintParticles(Canvas canvas, Size size, {required int count}) {
    for (var index = 0; index < count; index += 1) {
      final x = _tilemapLoadingHash(index * 19 + 1) * size.width;
      final y = _tilemapLoadingHash(index * 31 + 9) * size.height;
      final pulse =
          0.30 +
          ((math.sin(phase * math.pi * 2 + index * 1.71) + 1) * 0.5) * 0.58;
      final color = switch (index % 5) {
        0 || 3 => palette.purple,
        1 => palette.gold,
        2 => palette.mint,
        _ => palette.foreground,
      };
      final radius = index % 7 == 0 ? 1.5 : 0.75;
      if (index % 7 == 0) {
        canvas.drawCircle(
          Offset(x, y),
          radius * 4.5,
          Paint()
            ..color = color.withValues(alpha: 0.12 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: 0.74 * pulse),
      );
    }
  }

  void _paintVignette(Canvas canvas, Size size, Offset center) {
    final edge = palette.isDark
        ? Colors.black.withValues(alpha: 0.25)
        : const Color(0xFF4D3F6E).withValues(alpha: 0.06);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          math.max(size.width, size.height) * 0.72,
          [Colors.transparent, edge],
          const [0.38, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _TilemapLoadingAtmospherePainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.palette != palette ||
        oldDelegate.progress != progress ||
        oldDelegate.phase != phase;
  }
}

class _TilemapLoadingMotifPainter extends CustomPainter {
  const _TilemapLoadingMotifPainter({
    required this.style,
    required this.palette,
    required this.progress,
    required this.phase,
  });

  final TilemapLoadingStyle style;
  final _TilemapLoadingPalette palette;
  final double progress;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case TilemapLoadingStyle.tileAssembly:
        _paintTileAssembly(canvas, size);
      case TilemapLoadingStyle.worldPortal:
        _paintWorldPortal(canvas, size);
      case TilemapLoadingStyle.progressiveReveal:
        _paintProgressiveReveal(canvas, size);
      case TilemapLoadingStyle.coordinatePulse:
        _paintCoordinatePulse(canvas, size);
      case TilemapLoadingStyle.minimalProgress:
      case TilemapLoadingStyle.disabled:
        break;
    }
  }

  void _paintTileAssembly(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.49);
    final shortest = size.shortestSide;
    final orbitRect = Rect.fromCenter(
      center: center,
      width: shortest * 0.83,
      height: shortest * 0.76,
    );

    canvas.drawOval(
      orbitRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.65, shortest / 650)
        ..color = palette.foreground.withValues(alpha: 0.09),
    );

    final arcStart = -math.pi * 0.92 + phase * math.pi * 2;
    _paintLayeredGlowArc(
      canvas,
      orbitRect,
      arcStart,
      math.pi * (1.06 + progress * 0.58),
      colors: [
        palette.purple.withValues(alpha: 0.92),
        palette.purple.withValues(alpha: 0.30),
        palette.gold.withValues(alpha: 0.95),
      ],
      width: math.max(1.0, shortest / 340),
      glowScale: 8,
    );

    final innerOrbit = orbitRect.deflate(shortest * 0.042);
    final dashPaint = Paint()
      ..color = palette.foreground.withValues(alpha: 0.13)
      ..strokeWidth = math.max(0.5, shortest / 720);
    for (var index = 0; index < 54; index += 1) {
      if (index % 3 != 0) continue;
      final angle = index / 54 * math.pi * 2;
      final point = Offset(
        innerOrbit.center.dx + math.cos(angle) * innerOrbit.width / 2,
        innerOrbit.center.dy + math.sin(angle) * innerOrbit.height / 2,
      );
      canvas.drawCircle(point, index % 9 == 0 ? 1.3 : 0.65, dashPaint);
    }

    final glowCenter = center.translate(0, shortest * 0.03);
    canvas.drawCircle(
      glowCenter,
      shortest * 0.27,
      Paint()
        ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
        ..shader = ui.Gradient.radial(
          glowCenter,
          shortest * 0.27,
          [
            palette.purple.withValues(alpha: palette.isDark ? 0.18 : 0.10),
            palette.gold.withValues(alpha: palette.isDark ? 0.07 : 0.04),
            palette.purple.withValues(alpha: 0),
          ],
          const [0, 0.47, 1],
        ),
    );

    final tileWidth = shortest * 0.172;
    final tileHeight = shortest * 0.087;
    const revealOrder = <List<int>>[
      <int>[6, 3, 7],
      <int>[2, 0, 4],
      <int>[8, 5, 1],
    ];
    final resolvedProgress = progress * 9;

    for (var diagonal = 0; diagonal <= 4; diagonal += 1) {
      for (var row = 0; row < 3; row += 1) {
        final column = diagonal - row;
        if (column < 0 || column >= 3) continue;
        final tileCenter = Offset(
          center.dx + (column - row) * tileWidth * 0.52,
          center.dy + (column + row - 2) * tileHeight * 0.52,
        );
        final path = _tilemapLoadingDiamondPath(
          tileCenter,
          tileWidth,
          tileHeight,
        );
        final reveal = (resolvedProgress - revealOrder[row][column]).clamp(
          0.0,
          1.0,
        );
        final tint = Color.lerp(
          palette.purple,
          palette.gold,
          (column - row + 2) / 4,
        )!;

        canvas.drawPath(
          path.shift(Offset(0, shortest * 0.012)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.20)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * 0.018),
        );
        if (reveal > 0) {
          canvas.drawPath(
            path,
            Paint()
              ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
              ..color = tint.withValues(alpha: 0.16 * reveal)
              ..maskFilter = MaskFilter.blur(
                BlurStyle.normal,
                shortest * 0.025,
              ),
          );
        }
        canvas.drawPath(
          path,
          Paint()..color = tint.withValues(alpha: 0.035 + reveal * 0.18),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.75, shortest / 490)
            ..color = Color.lerp(
              palette.foreground.withValues(alpha: 0.20),
              tint.withValues(alpha: 0.92),
              reveal,
            )!,
        );
      }
    }

    final floatingTiles = <Offset>[
      center.translate(0, -shortest * 0.27),
      center.translate(shortest * 0.25, -shortest * 0.13),
      center.translate(-shortest * 0.25, -shortest * 0.09),
      center.translate(0, shortest * 0.27),
    ];
    for (var index = 0; index < floatingTiles.length; index += 1) {
      final floatOffset =
          math.sin(phase * math.pi * 2 + index * 1.4) * shortest * 0.009;
      final point = floatingTiles[index].translate(0, floatOffset);
      final tint = index.isEven ? palette.purple : palette.gold;
      canvas.drawPath(
        _tilemapLoadingDiamondPath(point, tileWidth * 0.72, tileHeight * 0.72),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, shortest / 570)
          ..color = tint.withValues(alpha: 0.35),
      );
    }

    final sweepDrift =
        math.sin(phase * math.pi * 2) * size.shortestSide * 0.025;
    final beamStart = center.translate(
      -shortest * 0.32,
      shortest * 0.20 + sweepDrift,
    );
    final beamEnd = center.translate(
      shortest * 0.34,
      -shortest * 0.18 + sweepDrift,
    );
    _paintLayeredGlowLine(
      canvas,
      beamStart,
      beamEnd,
      colors: [
        palette.purple.withValues(alpha: 0.88),
        const Color(0xFFF5EDFF).withValues(alpha: 0.92),
        palette.gold.withValues(alpha: 0.92),
      ],
      width: math.max(0.9, shortest / 390),
      glowScale: 10,
    );

    for (var index = 0; index < 18; index += 1) {
      final angle = index / 18 * math.pi * 2 + phase * math.pi * 2;
      final point = Offset(
        center.dx + math.cos(angle) * orbitRect.width * 0.48,
        center.dy + math.sin(angle) * orbitRect.height * 0.48,
      );
      final color = switch (index % 4) {
        0 => palette.purple,
        1 => palette.gold,
        2 => palette.mint,
        _ => palette.foreground,
      };
      _paintGlowDot(
        canvas,
        point,
        radius: index % 5 == 0 ? shortest * 0.006 : shortest * 0.003,
        color: color,
        alpha: index % 5 == 0 ? 0.85 : 0.54,
      );
    }
  }

  void _paintWorldPortal(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final center = Offset(size.width * 0.5, size.height * 0.49);
    final radius = shortest * 0.33;

    canvas.drawCircle(
      center,
      radius * 1.56,
      Paint()
        ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
        ..shader = ui.Gradient.radial(
          center,
          radius * 1.56,
          [
            palette.purple.withValues(alpha: palette.isDark ? 0.18 : 0.11),
            palette.gold.withValues(alpha: palette.isDark ? 0.055 : 0.032),
            palette.purple.withValues(alpha: 0),
          ],
          const [0, 0.55, 1],
        ),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center.translate(-radius * 0.22, -radius * 0.20),
          radius * 1.28,
          const [
            Color(0xFF05040B),
            Color(0xFF0C091A),
            Color(0xFF211738),
            Color(0xFF06050C),
          ],
          const [0, 0.43, 0.79, 1],
        ),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    final tileWidth = shortest * 0.105;
    final tileHeight = tileWidth * 0.48;
    final resolvedProgress = progress * 2.1;
    for (var diagonal = -7; diagonal <= 7; diagonal += 1) {
      for (var row = -4; row <= 4; row += 1) {
        final column = diagonal - row;
        if (column < -4 || column > 4) continue;
        final point = Offset(
          center.dx + (column - row) * tileWidth * 0.5,
          center.dy + (column + row) * tileHeight * 0.5 + radius * 0.03,
        );
        if ((point - center).distance > radius * 0.94) continue;
        final normalizedDistance = (point - center).distance / radius;
        final reveal = (resolvedProgress - normalizedDistance * 1.65).clamp(
          0.0,
          1.0,
        );
        final tint = Color.lerp(
          palette.purple,
          palette.gold,
          ((point.dx - center.dx) / radius + 1) * 0.5,
        )!;
        final path = _tilemapLoadingDiamondPath(point, tileWidth, tileHeight);
        if (reveal > 0) {
          canvas.drawPath(
            path,
            Paint()..color = tint.withValues(alpha: 0.055 + reveal * 0.10),
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.45, shortest / 760)
            ..color = tint.withValues(alpha: 0.13 + reveal * 0.30),
        );
      }
    }

    for (var index = 0; index < 20; index += 1) {
      final angle = _tilemapLoadingHash(index * 17 + 4) * math.pi * 2;
      final distance =
          radius * math.sqrt(_tilemapLoadingHash(index * 23 + 8)) * 0.86;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(
        point,
        index % 6 == 0 ? 1.2 : 0.55,
        Paint()
          ..color = (index.isEven ? palette.purple : palette.gold).withValues(
            alpha: 0.30 + index % 4 * 0.09,
          ),
      );
    }
    canvas.restore();

    for (var index = 0; index < 6; index += 1) {
      final startAngle =
          -math.pi * 0.88 +
          index * math.pi * 0.36 +
          math.sin(phase * math.pi * 2 + index) * 0.035;
      final endAngle = startAngle + math.pi * (0.20 + index % 2 * 0.07);
      final startPoint =
          center +
          Offset(math.cos(startAngle), math.sin(startAngle)) *
              radius *
              (1.02 + index % 3 * 0.06);
      final endPoint =
          center +
          Offset(math.cos(endAngle), math.sin(endAngle)) *
              radius *
              (1.10 + index % 2 * 0.10);
      final controlA =
          center +
          Offset(math.cos(startAngle + 0.11), math.sin(startAngle + 0.11)) *
              radius *
              1.40;
      final controlB =
          center +
          Offset(math.cos(endAngle - 0.10), math.sin(endAngle - 0.10)) *
              radius *
              1.32;
      final wisp = Path()
        ..moveTo(startPoint.dx, startPoint.dy)
        ..cubicTo(
          controlA.dx,
          controlA.dy,
          controlB.dx,
          controlB.dy,
          endPoint.dx,
          endPoint.dy,
        );
      final color = switch (index % 3) {
        0 => palette.purple,
        1 => const Color(0xFFD5C8DD),
        _ => palette.gold,
      };
      canvas.drawPath(
        wisp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = shortest * 0.018
          ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * 0.025)
          ..color = color.withValues(alpha: palette.isDark ? 0.075 : 0.045),
      );
      canvas.drawPath(
        wisp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.6, shortest / 600)
          ..color = color.withValues(alpha: 0.14),
      );
    }

    final portalColors = <Color>[
      palette.purple.withValues(alpha: 0.94),
      const Color(0xFFBE9BFF).withValues(alpha: 0.90),
      palette.gold.withValues(alpha: 0.94),
      palette.mint.withValues(alpha: 0.68),
      palette.purple.withValues(alpha: 0.94),
    ];
    for (var ring = 0; ring < 4; ring += 1) {
      final ringRadius = radius * (1.00 + ring * 0.075);
      final rect = Rect.fromCircle(center: center, radius: ringRadius);
      _paintLayeredGlowArc(
        canvas,
        rect,
        phase * math.pi * 2 * (ring.isEven ? 1 : -1) + ring * 0.47,
        math.pi * 1.999,
        colors: portalColors,
        width: math.max(0.75, shortest / (ring == 0 ? 165 : 280)),
        glowScale: ring == 0 ? 7 : 5,
      );
    }

    for (var arc = 0; arc < 7; arc += 1) {
      final ringRadius = radius * (1.08 + (arc % 3) * 0.08);
      final rect = Rect.fromCircle(center: center, radius: ringRadius);
      final start =
          math.sin(phase * math.pi * 2) *
              (arc.isEven ? math.pi * 0.22 : -math.pi * 0.18) +
          arc * 0.87;
      final color = switch (arc % 3) {
        0 => palette.purple,
        1 => palette.gold,
        _ => palette.mint,
      };
      canvas.drawArc(
        rect,
        start,
        math.pi * (0.16 + (arc % 4) * 0.045),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.8, shortest / 260)
          ..color = color.withValues(alpha: 0.72),
      );
    }

    _paintLayeredGlowArc(
      canvas,
      Rect.fromCircle(center: center, radius: radius * 1.22),
      -math.pi / 2,
      math.pi * 2 * progress,
      colors: [
        palette.purple.withValues(alpha: 0.96),
        palette.gold.withValues(alpha: 0.96),
        palette.mint.withValues(alpha: 0.78),
      ],
      width: math.max(0.9, shortest / 260),
      glowScale: 7,
    );

    for (var index = 0; index < 12; index += 1) {
      final angle =
          phase * math.pi * 2 + index / 12 * math.pi * 2 + index * 0.17;
      final orbit = radius * (1.23 + (index % 3) * 0.12);
      final point =
          center + Offset(math.cos(angle), math.sin(angle) * 0.96) * orbit;
      final color = switch (index % 4) {
        0 => palette.purple,
        1 => palette.gold,
        2 => palette.mint,
        _ => const Color(0xFFF4EFFF),
      };
      _paintGlowDot(
        canvas,
        point,
        radius: index % 4 == 0 ? shortest * 0.005 : shortest * 0.0025,
        color: color,
        alpha: 0.72,
      );
    }

    for (var index = 0; index < 6; index += 1) {
      final side = index.isEven ? -1.0 : 1.0;
      final vertical = -0.52 + (index ~/ 2) * 0.53;
      final mistCenter = center.translate(
        side * radius * (0.96 + index % 3 * 0.07),
        radius * vertical +
            math.sin(phase * math.pi * 2 + index) * radius * 0.025,
      );
      final mistRadius = radius * (0.18 + index % 3 * 0.025);
      canvas.save();
      canvas.translate(mistCenter.dx, mistCenter.dy);
      canvas.rotate(side * 0.18);
      canvas.scale(1.85, 1);
      final mistColor = index % 3 == 0
          ? palette.purple
          : const Color(0xFFD3CAD8);
      canvas.drawCircle(
        Offset.zero,
        mistRadius,
        Paint()
          ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, mistRadius * 0.30)
          ..shader = ui.Gradient.radial(
            Offset.zero,
            mistRadius,
            [
              mistColor.withValues(alpha: palette.isDark ? 0.13 : 0.055),
              mistColor.withValues(alpha: palette.isDark ? 0.055 : 0.025),
              mistColor.withValues(alpha: 0),
            ],
            const [0, 0.52, 1],
          ),
      );
      canvas.restore();
    }
  }

  void _paintProgressiveReveal(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final center = Offset(size.width * 0.5, size.height * 0.49);
    final fieldGlowRadius = shortest * 0.42;
    canvas.drawCircle(
      center,
      fieldGlowRadius,
      Paint()
        ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
        ..shader = ui.Gradient.radial(
          center,
          fieldGlowRadius,
          [
            palette.purple.withValues(alpha: palette.isDark ? 0.13 : 0.075),
            palette.gold.withValues(alpha: palette.isDark ? 0.05 : 0.03),
            palette.purple.withValues(alpha: 0),
          ],
          const [0, 0.52, 1],
        ),
    );

    const rows = 6;
    const columns = 6;
    for (var row = 0; row < rows; row += 1) {
      final depth = row / (rows - 1);
      final perspective = 0.62 + depth * 0.48;
      final tileWidth = shortest * 0.185 * perspective;
      final tileHeight = tileWidth * 0.50;
      final spacingX = shortest * (0.132 + depth * 0.018);
      final y = size.height * 0.08 + row * shortest * 0.130;
      for (var column = 0; column < columns; column += 1) {
        final x = center.dx + (column - 2.5) * spacingX;
        final point = Offset(x, y);
        final path = _tilemapLoadingDiamondPath(point, tileWidth, tileHeight);
        final dx = (column - 2.5) / 3.0;
        final dy = (row - 2.5) / 3.0;
        final distance = math.sqrt(dx * dx + dy * dy);
        final reveal = (progress * 1.50 + 0.12 - distance).clamp(0.0, 1.0) * 2;
        final resolvedReveal = reveal.clamp(0.0, 1.0);
        final tint = Color.lerp(
          palette.purple,
          palette.gold,
          column / (columns - 1),
        )!;

        canvas.drawPath(
          path,
          Paint()
            ..color = palette.foreground.withValues(
              alpha: 0.022 + depth * 0.018,
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              1.2 + (1 - depth) * 4.5,
            ),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.55, shortest / 650)
            ..color = palette.foreground.withValues(alpha: 0.07 + depth * 0.06),
        );

        if (resolvedReveal <= 0) continue;
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
            ..color = tint.withValues(alpha: 0.12 * resolvedReveal)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * 0.016),
        );
        canvas.drawPath(
          path,
          Paint()..color = tint.withValues(alpha: 0.06 + resolvedReveal * 0.15),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.75, shortest / 500)
            ..color = tint.withValues(alpha: 0.22 + resolvedReveal * 0.48),
        );
      }
    }

    final drift = math.sin(phase * math.pi * 2) * shortest * 0.035;
    final beamStart = Offset(
      center.dx - shortest * 0.43,
      center.dy + shortest * 0.30 + drift,
    );
    final beamEnd = Offset(
      center.dx + shortest * 0.43,
      center.dy - shortest * 0.27 + drift,
    );
    _paintLayeredGlowLine(
      canvas,
      beamStart,
      beamEnd,
      colors: [
        palette.purple.withValues(alpha: 0.94),
        const Color(0xFFF6F0FF).withValues(alpha: 0.95),
        palette.gold.withValues(alpha: 0.96),
      ],
      width: math.max(1.0, shortest / 370),
      glowScale: 12,
    );
    _paintGlowDot(
      canvas,
      Offset.lerp(beamStart, beamEnd, progress)!,
      radius: shortest * 0.006,
      color: Color.lerp(palette.purple, palette.gold, progress)!,
      alpha: 0.95,
    );
  }

  void _paintCoordinatePulse(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final center = Offset(size.width * 0.5, size.height * 0.49);
    final maximumRadius = shortest * 0.40;
    final fineStroke = math.max(0.55, shortest / 720);

    for (var ring = 1; ring <= 4; ring += 1) {
      final radius = maximumRadius * ring / 4;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 4 ? fineStroke * 1.35 : fineStroke
          ..color = palette.foreground.withValues(
            alpha: ring == 4 ? 0.20 : 0.13,
          ),
      );
    }

    for (final offset in <double>[0, 0.5]) {
      final pulse = (phase + offset) % 1;
      canvas.drawCircle(
        center,
        maximumRadius * (0.18 + pulse * 0.98),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, shortest / 540)
          ..color = palette.purple.withValues(alpha: (1 - pulse) * 0.28),
      );
      canvas.drawCircle(
        center,
        maximumRadius * (0.18 + pulse * 0.98),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, shortest / 180)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * 0.015)
          ..color = palette.purple.withValues(alpha: (1 - pulse) * 0.10),
      );
    }

    final anchors = <({Offset point, Color color})>[
      (point: center.translate(0, -maximumRadius), color: palette.gold),
      (
        point: center.translate(maximumRadius, 0),
        color: const Color(0xFFFFE5A5),
      ),
      (point: center.translate(0, maximumRadius), color: palette.mint),
      (point: center.translate(-maximumRadius, 0), color: palette.purple),
    ];

    for (var index = 0; index < anchors.length; index += 1) {
      final anchor = anchors[index];
      _paintLayeredGlowLine(
        canvas,
        center,
        anchor.point,
        colors: [
          anchor.color.withValues(alpha: 0.10),
          anchor.color.withValues(alpha: 0.50),
        ],
        width: fineStroke,
        glowScale: 4,
      );
      final activation =
          (progress * anchors.length - index).clamp(0.0, 1.0) * 0.28;
      _paintGlowDot(
        canvas,
        anchor.point,
        radius: shortest * 0.0065,
        color: anchor.color,
        alpha: 0.70 + activation,
      );
    }

    final centerGlow = Paint()
      ..color = palette.purple.withValues(alpha: 0.24)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * 0.035);
    canvas.drawCircle(center, shortest * 0.050, centerGlow);
    final centerDiamond = _tilemapLoadingDiamondPath(
      center,
      shortest * 0.048,
      shortest * 0.048,
    );
    canvas.drawPath(
      centerDiamond,
      Paint()..color = palette.purple.withValues(alpha: 0.10 + progress * 0.13),
    );
    canvas.drawPath(
      centerDiamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, shortest / 430)
        ..color = palette.purple.withValues(alpha: 0.94),
    );

    for (var index = 0; index < 16; index += 1) {
      final angle =
          _tilemapLoadingHash(index * 17 + 5) * math.pi * 2 +
          phase * math.pi * 2;
      final distance =
          maximumRadius * (0.35 + _tilemapLoadingHash(index * 23 + 4) * 0.78);
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final color = switch (index % 5) {
        0 || 3 => palette.purple,
        1 => palette.gold,
        2 => palette.mint,
        _ => palette.foreground,
      };
      _paintGlowDot(
        canvas,
        point,
        radius: index % 6 == 0 ? shortest * 0.004 : shortest * 0.002,
        color: color,
        alpha:
            0.35 + ((math.sin(phase * math.pi * 2 + index) + 1) * 0.5) * 0.45,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TilemapLoadingMotifPainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.palette != palette ||
        oldDelegate.progress != progress ||
        oldDelegate.phase != phase;
  }
}

Path _tilemapLoadingDiamondPath(Offset center, double width, double height) {
  return Path()
    ..moveTo(center.dx, center.dy - height / 2)
    ..lineTo(center.dx + width / 2, center.dy)
    ..lineTo(center.dx, center.dy + height / 2)
    ..lineTo(center.dx - width / 2, center.dy)
    ..close();
}

double _tilemapLoadingHash(int seed) {
  final value = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
  return value - value.floorToDouble();
}

Color _tilemapLoadingScaledAlpha(Color color, double scale) {
  return color.withValues(alpha: (color.a * scale).clamp(0.0, 1.0));
}

void _paintLayeredGlowLine(
  Canvas canvas,
  Offset start,
  Offset end, {
  required List<Color> colors,
  required double width,
  required double glowScale,
}) {
  final wideColors = colors
      .map((color) => _tilemapLoadingScaledAlpha(color, 0.30))
      .toList(growable: false);
  final mediumColors = colors
      .map((color) => _tilemapLoadingScaledAlpha(color, 0.60))
      .toList(growable: false);
  final colorStops = colors.length > 2
      ? List<double>.generate(
          colors.length,
          (index) => index / (colors.length - 1),
          growable: false,
        )
      : null;
  canvas.drawLine(
    start,
    end,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * glowScale
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * glowScale * 1.2)
      ..shader = ui.Gradient.linear(start, end, wideColors, colorStops),
  );
  canvas.drawLine(
    start,
    end,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * 3
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 2.5)
      ..shader = ui.Gradient.linear(start, end, mediumColors, colorStops),
  );
  canvas.drawLine(
    start,
    end,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..shader = ui.Gradient.linear(start, end, colors, colorStops),
  );
}

void _paintLayeredGlowArc(
  Canvas canvas,
  Rect rect,
  double startAngle,
  double sweepAngle, {
  required List<Color> colors,
  required double width,
  required double glowScale,
}) {
  final wideColors = colors
      .map((color) => _tilemapLoadingScaledAlpha(color, 0.28))
      .toList(growable: false);
  final mediumColors = colors
      .map((color) => _tilemapLoadingScaledAlpha(color, 0.60))
      .toList(growable: false);
  final rotation = GradientRotation(startAngle);
  canvas.drawArc(
    rect,
    startAngle,
    sweepAngle,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * glowScale
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * glowScale * 1.15)
      ..shader = SweepGradient(
        colors: wideColors,
        transform: rotation,
      ).createShader(rect),
  );
  canvas.drawArc(
    rect,
    startAngle,
    sweepAngle,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * 3
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 2.6)
      ..shader = SweepGradient(
        colors: mediumColors,
        transform: rotation,
      ).createShader(rect),
  );
  canvas.drawArc(
    rect,
    startAngle,
    sweepAngle,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..shader = SweepGradient(
        colors: colors,
        transform: rotation,
      ).createShader(rect),
  );
}

void _paintGlowDot(
  Canvas canvas,
  Offset center, {
  required double radius,
  required Color color,
  required double alpha,
}) {
  canvas.drawCircle(
    center,
    radius * 5,
    Paint()
      ..blendMode = BlendMode.plus
      ..color = color.withValues(alpha: alpha * 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 4),
  );
  canvas.drawCircle(
    center,
    radius * 2.2,
    Paint()
      ..blendMode = BlendMode.plus
      ..color = color.withValues(alpha: alpha * 0.32)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.6),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()..color = color.withValues(alpha: alpha),
  );
}
