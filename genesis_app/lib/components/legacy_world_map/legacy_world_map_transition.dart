import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../world_point.dart';

class LegacyWorldMapLocationTrailEntry {
  const LegacyWorldMapLocationTrailEntry({
    required this.id,
    required this.origin,
  });

  final String id;
  final Alignment origin;
}

class LegacyWorldMapTransitionSpec {
  const LegacyWorldMapTransitionSpec({
    required this.origin,
    required this.direction,
  });

  final Alignment origin;
  final LegacyWorldMapTransitionDirection direction;
}

enum LegacyWorldMapTransitionDirection { drillIn, drillOut }

String legacyWorldMapPointLocationId(WorldPoint point) {
  final sceneId = point.sceneId.trim();
  if (sceneId.isNotEmpty) return sceneId;
  final pointId = point.pointId.trim();
  if (pointId.isNotEmpty) return pointId;
  return point.id.trim();
}

bool legacyWorldMapPointMatchesLocationIds(
  WorldPoint point,
  Set<String> locationIds,
) {
  if (locationIds.isEmpty) return false;
  final locationId = point.sceneId.trim();
  return locationId.isNotEmpty && locationIds.contains(locationId);
}

Alignment legacyWorldMapTransitionOrigin(WorldPoint point) {
  final dx = point.position.dx.clamp(0.0, 1.0).toDouble();
  final dy = point.position.dy.clamp(0.0, 1.0).toDouble();
  return Alignment(dx * 2 - 1, dy * 2 - 1);
}

double legacyWorldMapLerpDouble(double begin, double end, double t) {
  return begin + (end - begin) * t;
}

class LegacyWorldMapExitLocationButton extends StatelessWidget {
  const LegacyWorldMapExitLocationButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.trim();
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = displayLabel.isEmpty
            ? 0.0
            : (TextPainter(
                text: TextSpan(text: displayLabel, style: textStyle),
                maxLines: 1,
                textDirection: Directionality.of(context),
              )..layout()).width;
        final desiredWidth =
            36.0 + (displayLabel.isEmpty ? 0.0 : textWidth + 12);
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : desiredWidth;
        final buttonWidth = math.min(desiredWidth, maxWidth);

        return SizedBox(
          width: buttonWidth,
          height: 36,
          child: Container(
            padding: EdgeInsets.only(
              left: 0,
              right: displayLabel.isEmpty ? 0 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPressed,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.subdirectory_arrow_left,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                    if (displayLabel.isNotEmpty)
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            displayLabel,
                            maxLines: 1,
                            style: textStyle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LegacyWorldMapConstrainedMaxWidth extends StatelessWidget {
  const LegacyWorldMapConstrainedMaxWidth({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  final double? maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final resolvedMaxWidth = maxWidth;
    if (resolvedMaxWidth == null) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
      child: child,
    );
  }
}

class LegacyWorldMapTransitionSurface extends StatelessWidget {
  const LegacyWorldMapTransitionSurface({
    super.key,
    required this.mapKey,
    required this.transition,
    required this.child,
  });

  final LocalKey mapKey;
  final LegacyWorldMapTransitionSpec transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(seconds: 1),
      reverseDuration: const Duration(seconds: 1),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return _WorldMapZoomFadeTransition(
          animation: animation,
          incoming: child.key == mapKey,
          transition: transition,
          child: child,
        );
      },
      child: KeyedSubtree(key: mapKey, child: child),
    );
  }
}

class _WorldMapZoomFadeTransition extends StatelessWidget {
  const _WorldMapZoomFadeTransition({
    required this.animation,
    required this.incoming,
    required this.transition,
    required this.child,
  });

  final Animation<double> animation;
  final bool incoming;
  final LegacyWorldMapTransitionSpec transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: incoming ? Curves.easeOutCubic : Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        final scale = _transitionScale(t);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            alignment: transition.origin,
            child: child,
          ),
        );
      },
    );
  }

  double _transitionScale(double t) {
    return switch (transition.direction) {
      LegacyWorldMapTransitionDirection.drillIn =>
        incoming
            ? legacyWorldMapLerpDouble(0.56, 1, t)
            : legacyWorldMapLerpDouble(1.68, 1, t),
      LegacyWorldMapTransitionDirection.drillOut =>
        incoming
            ? legacyWorldMapLerpDouble(1.68, 1, t)
            : legacyWorldMapLerpDouble(0.56, 1, t),
    };
  }
}
