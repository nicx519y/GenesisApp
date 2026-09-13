import 'package:flutter/material.dart';

import '../../../icons/custom_icon_assets.dart';
import '../shared/reply_feature_button.dart';
import '../shared/reply_action_state.dart';

/// Public invocation contract for continuing from the current reply round.
final class LocationChatGoOnFeature {
  const LocationChatGoOnFeature({required this.onInvoke, required this.state});

  const LocationChatGoOnFeature.disabled()
    : onInvoke = null,
      state = LocationChatReplyActionState.none;

  final VoidCallback? onInvoke;
  final LocationChatReplyActionState state;
  bool get enabled => state == LocationChatReplyActionState.idle;
  bool get busy => state == LocationChatReplyActionState.busy;

  VoidCallback? get invocation =>
      state == LocationChatReplyActionState.idle ? onInvoke : null;
}

class LocationChatGoOnButton extends StatelessWidget {
  const LocationChatGoOnButton({
    super.key,
    required this.feature,
    this.onBeforeInvoke,
  });

  final LocationChatGoOnFeature feature;
  final VoidCallback? onBeforeInvoke;

  @override
  Widget build(BuildContext context) => LocationChatReplyFeatureButton(
    label: 'Go on',
    iconAsset: goOnIconAsset,
    state: feature.state,
    onTap: feature.invocation == null
        ? null
        : () {
            onBeforeInvoke?.call();
            feature.invocation!();
          },
  );
}
