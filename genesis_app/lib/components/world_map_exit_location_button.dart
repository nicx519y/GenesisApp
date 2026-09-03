import 'package:flutter/material.dart';

const double worldMapExitLocationButtonSize = 30;
const double worldMapExitLocationLabelGap = 9;
const String worldMapExitLocationIconFrameKey =
    'world-map-exit-location-icon-frame';

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
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const ValueKey<String>(worldMapExitLocationIconFrameKey),
                width: worldMapExitLocationButtonSize,
                height: worldMapExitLocationButtonSize,
                child: Material(
                  color: const Color(0x99151517),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(
                      color: Color(0x29FFFFFF),
                      width: 0.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const Center(
                    child: Icon(
                      Icons.subdirectory_arrow_left,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
              if (displayLabel.isNotEmpty) ...[
                const SizedBox(width: worldMapExitLocationLabelGap),
                Flexible(
                  child: Text(
                    displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF4F3F6),
                      fontSize: 14,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      shadows: <Shadow>[
                        Shadow(
                          color: Color(0xD9000000),
                          offset: Offset(0, 1),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WorldMapCenteredExitLocationButton extends StatelessWidget {
  const WorldMapCenteredExitLocationButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.maxWidth,
    required this.onPressed,
  });

  final Key? buttonKey;
  final String label;
  final double? maxWidth;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: WorldMapConstrainedMaxWidth(
        maxWidth: maxWidth,
        child: WorldMapExitLocationButton(
          key: buttonKey,
          label: label,
          onPressed: onPressed,
        ),
      ),
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
