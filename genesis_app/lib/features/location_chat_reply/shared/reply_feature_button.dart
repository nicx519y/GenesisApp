import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared visual primitive. Feature directories own the semantic label, icon,
/// availability, and invocation policy.
class LocationChatReplyFeatureButton extends StatelessWidget {
  const LocationChatReplyFeatureButton({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.onTap,
    this.expanded,
    this.loading = false,
  });

  static const double size = 32;
  static const double iconSize = 17;

  final String label;
  final String iconAsset;
  final VoidCallback? onTap;
  final bool? expanded;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final hidden = onTap == null && !loading;
    if (hidden) return const SizedBox.square(dimension: size);
    return Semantics(
      container: true,
      label: label,
      enabled: onTap != null,
      button: true,
      expanded: expanded,
      liveRegion: loading,
      value: loading ? 'Loading' : null,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: loading
                  ? const SizedBox.square(
                      key: ValueKey('location-chat-reply-feature-loading'),
                      dimension: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        strokeCap: StrokeCap.round,
                        color: Color(0xF2FFFFFF),
                      ),
                    )
                  : SvgPicture.asset(
                      iconAsset,
                      width: iconSize,
                      height: iconSize,
                      colorFilter: const ColorFilter.mode(
                        Color(0xF2FFFFFF),
                        BlendMode.srcIn,
                      ),
                      excludeFromSemantics: true,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
