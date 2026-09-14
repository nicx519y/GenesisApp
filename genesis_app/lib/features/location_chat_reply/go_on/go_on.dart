import 'package:flutter/material.dart';

import '../../../icons/custom_icon_assets.dart';
import '../shared/reply_feature_button.dart';
import '../shared/reply_action_state.dart';

/// Public invocation contract for continuing from the current reply round.
final class LocationChatGoOnFeature extends LocationChatReplyAction {
  const LocationChatGoOnFeature({
    required super.onInvoke,
    required super.state,
  });
  const LocationChatGoOnFeature.disabled() : super.disabled();
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
    onTap: feature.invocation,
    onBeforeInvoke: onBeforeInvoke,
  );
}
