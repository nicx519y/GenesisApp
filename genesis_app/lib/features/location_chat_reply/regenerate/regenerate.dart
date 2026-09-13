import 'package:flutter/material.dart';

import '../../../icons/custom_icon_assets.dart';
import '../shared/reply_feature_button.dart';
import '../shared/reply_action_state.dart';

/// Public invocation contract for regenerating the current reply.
///
/// Consumers intentionally receive no controller, card, transport, or storage
/// implementation details.
final class LocationChatRegenerateFeature {
  const LocationChatRegenerateFeature({
    required this.onInvoke,
    required this.state,
    this.onLimitReached,
  });

  const LocationChatRegenerateFeature.disabled()
    : onInvoke = null,
      onLimitReached = null,
      state = LocationChatReplyActionState.none;

  final VoidCallback? onInvoke;
  final VoidCallback? onLimitReached;
  final LocationChatReplyActionState state;
  bool get enabled => state == LocationChatReplyActionState.idle;
  bool get busy => state == LocationChatReplyActionState.busy;

  VoidCallback? get invocation =>
      state == LocationChatReplyActionState.idle ? onInvoke : null;
}

class LocationChatRegenerateButton extends StatelessWidget {
  const LocationChatRegenerateButton({
    super.key,
    required this.feature,
    this.onBeforeInvoke,
  });

  final LocationChatRegenerateFeature feature;
  final VoidCallback? onBeforeInvoke;

  @override
  Widget build(BuildContext context) => LocationChatReplyFeatureButton(
    label: 'Regenerate',
    iconAsset: regenerateIconAsset,
    state: feature.state,
    onDisabledTap: feature.onLimitReached,
    onTap: feature.invocation == null
        ? null
        : () {
            onBeforeInvoke?.call();
            feature.invocation!();
          },
  );
}
