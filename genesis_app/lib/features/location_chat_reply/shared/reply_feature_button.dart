import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../ui/tokens/genesis_colors.dart';
import 'reply_action_state.dart';

/// Shared visual primitive. Feature directories own the semantic label, icon,
/// availability, and invocation policy.
class LocationChatReplyFeatureButton extends StatelessWidget {
  const LocationChatReplyFeatureButton({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.onTap,
    this.onBeforeInvoke,
    this.onDisabledTap,
    this.expanded,
    required this.state,
  });

  static const double size = 32;
  static const double iconSize = 17;

  final String label;
  final String iconAsset;
  final VoidCallback? onTap;
  final VoidCallback? onBeforeInvoke;
  final VoidCallback? onDisabledTap;
  final bool? expanded;
  final LocationChatReplyActionState state;

  @override
  Widget build(BuildContext context) {
    if (state == LocationChatReplyActionState.none) {
      return const SizedBox.shrink();
    }
    final loading = state == LocationChatReplyActionState.busy;
    final enabled = state == LocationChatReplyActionState.idle && onTap != null;
    final disabledTap = state == LocationChatReplyActionState.disabled
        ? onDisabledTap
        : null;
    return Semantics(
      container: true,
      label: label,
      enabled: enabled || disabledTap != null,
      button: true,
      expanded: expanded,
      liveRegion: loading,
      value: loading ? 'Loading' : null,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  onBeforeInvoke?.call();
                  onTap!();
                }
              : disabledTap,
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
                        color: GenesisColors.darkTextPrimary,
                      ),
                    )
                  : SvgPicture.asset(
                      iconAsset,
                      width: iconSize,
                      height: iconSize,
                      colorFilter: ColorFilter.mode(
                        state == LocationChatReplyActionState.disabled
                            ? GenesisColors.darkTextTertiary
                            : GenesisColors.darkTextPrimary,
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
