import 'package:flutter/material.dart';

import '../../../icons/custom_icon_assets.dart';
import '../shared/reply_feature_button.dart';
import '../shared/reply_action_state.dart';

/// Public invocation contract for regenerating the current reply.
///
/// Consumers intentionally receive no controller, card, transport, or storage
/// implementation details.
final class LocationChatRegenerateFeature extends LocationChatReplyAction {
  const LocationChatRegenerateFeature({
    required super.onInvoke,
    required super.state,
    this.onLimitReached,
  });
  const LocationChatRegenerateFeature.disabled()
    : onLimitReached = null,
      super.disabled();

  final VoidCallback? onLimitReached;
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
    onTap: feature.invocation,
    onBeforeInvoke: onBeforeInvoke,
  );
}
