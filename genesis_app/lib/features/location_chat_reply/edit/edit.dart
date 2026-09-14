import 'package:flutter/material.dart';

import '../../../icons/custom_icon_assets.dart';
import '../shared/reply_feature_button.dart';
import '../shared/reply_action_state.dart';

/// Public invocation contract for editing the currently presented reply.
final class LocationChatEditFeature extends LocationChatReplyAction {
  const LocationChatEditFeature({
    required super.onInvoke,
    required super.state,
    this.freeUsesRemaining,
  });
  const LocationChatEditFeature.disabled()
    : freeUsesRemaining = null,
      super.disabled();

  final int? freeUsesRemaining;
}

class LocationChatEditButton extends StatelessWidget {
  const LocationChatEditButton({
    super.key,
    required this.feature,
    this.onBeforeInvoke,
  });

  final LocationChatEditFeature feature;
  final VoidCallback? onBeforeInvoke;

  @override
  Widget build(BuildContext context) => LocationChatReplyFeatureButton(
    label: 'Edit',
    iconAsset: editSquareIconAsset,
    state: feature.state,
    onTap: feature.invocation,
    onBeforeInvoke: onBeforeInvoke,
  );
}
