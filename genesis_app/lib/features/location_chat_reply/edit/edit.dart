import 'package:flutter/material.dart';

import '../../../icons/custom_icon_assets.dart';
import '../shared/reply_feature_button.dart';
import '../shared/reply_action_state.dart';

/// Public invocation contract for editing the currently presented reply.
final class LocationChatEditFeature {
  const LocationChatEditFeature({
    required this.onInvoke,
    required this.state,
    this.freeUsesRemaining,
  });

  const LocationChatEditFeature.disabled()
    : onInvoke = null,
      state = LocationChatReplyActionState.none,
      freeUsesRemaining = null;

  final VoidCallback? onInvoke;
  final LocationChatReplyActionState state;
  bool get enabled => state == LocationChatReplyActionState.idle;
  bool get busy => state == LocationChatReplyActionState.busy;
  final int? freeUsesRemaining;

  VoidCallback? get invocation =>
      state == LocationChatReplyActionState.idle ? onInvoke : null;
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
    onTap: feature.invocation == null
        ? null
        : () {
            onBeforeInvoke?.call();
            feature.invocation!();
          },
  );
}
