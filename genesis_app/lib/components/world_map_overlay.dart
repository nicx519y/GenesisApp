import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Fades map annotations without rebuilding the map or resetting its transform.
class WorldMapOverlay extends StatelessWidget {
  const WorldMapOverlay({
    super.key,
    required this.opacity,
    required this.child,
  });

  final ValueListenable<double>? opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opacity = this.opacity;
    if (opacity == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: opacity,
      child: child,
      builder: (context, value, child) => IgnorePointer(
        ignoring: value < 1,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
    );
  }
}
