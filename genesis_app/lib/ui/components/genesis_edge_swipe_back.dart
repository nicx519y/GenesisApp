import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double _kGenesisEdgeSwipeWidth = 24;
const double _kGenesisEdgeSwipeTriggerDistance = 64;
const double _kGenesisEdgeSwipeTriggerVelocity = 450;

class GenesisEdgeSwipeBack extends StatefulWidget {
  const GenesisEdgeSwipeBack({
    super.key,
    required this.child,
    required this.onBack,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onBack;
  final bool enabled;

  @override
  State<GenesisEdgeSwipeBack> createState() => _GenesisEdgeSwipeBackState();
}

class _GenesisEdgeSwipeBackState extends State<GenesisEdgeSwipeBack> {
  double _dragDistance = 0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (!widget.enabled ||
        (platform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return widget.child;
    }
    final direction = Directionality.of(context);
    final padding = MediaQuery.paddingOf(context);
    final edgePadding = direction == TextDirection.rtl
        ? padding.right
        : padding.left;
    final width = math.max(_kGenesisEdgeSwipeWidth, edgePadding);

    return Stack(
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: width,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _reset(),
            onHorizontalDragUpdate: (details) {
              final delta = details.primaryDelta ?? 0;
              final logicalDelta = direction == TextDirection.rtl
                  ? -delta
                  : delta;
              _dragDistance = math.max(0, _dragDistance + logicalDelta);
              if (_dragDistance >= _kGenesisEdgeSwipeTriggerDistance) {
                _trigger();
              }
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final logicalVelocity = direction == TextDirection.rtl
                  ? -velocity
                  : velocity;
              if (logicalVelocity >= _kGenesisEdgeSwipeTriggerVelocity) {
                _trigger();
                return;
              }
              _reset();
            },
            onHorizontalDragCancel: _reset,
          ),
        ),
      ],
    );
  }

  void _trigger() {
    if (_triggered) return;
    _triggered = true;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onBack();
  }

  void _reset() {
    _dragDistance = 0;
    _triggered = false;
  }
}
