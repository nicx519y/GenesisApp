import 'dart:math' as math;

import 'package:flutter/material.dart';

class WorldMapExitLocationButton extends StatelessWidget {
  const WorldMapExitLocationButton({
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

class WorldMapConstrainedMaxWidth extends StatelessWidget {
  const WorldMapConstrainedMaxWidth({
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
