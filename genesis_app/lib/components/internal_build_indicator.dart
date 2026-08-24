import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/config/app_flavor_config.dart';

class InternalBuildIndicator extends StatelessWidget {
  const InternalBuildIndicator({
    super.key,
    required this.child,
    this.isInternal = AppFlavorConfig.currentIsInternal,
  });

  static const indicatorKey = ValueKey<String>('internal-build-indicator');

  final Widget child;
  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    if (!isInternal) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: MediaQuery.paddingOf(context).top,
          right: 0,
          child: const IgnorePointer(child: _InternalCornerRibbon()),
        ),
      ],
    );
  }
}

class _InternalCornerRibbon extends StatelessWidget {
  const _InternalCornerRibbon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: InternalBuildIndicator.indicatorKey,
      width: 64,
      height: 42,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 6,
              right: -22,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 74,
                  height: 16,
                  alignment: Alignment.center,
                  color: const Color(0xEBFFD400),
                  child: const Text(
                    'INTERNAL',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
