import 'package:flutter/material.dart';

import '../../../icons/custom_icon_assets.dart';
import '../shared/reply_feature_button.dart';

/// Public invocation contract for editing the currently presented reply.
final class LocationChatEditFeature {
  const LocationChatEditFeature({
    required this.onInvoke,
    required this.enabled,
    required this.busy,
    this.freeUsesRemaining,
  });

  const LocationChatEditFeature.disabled()
    : onInvoke = null,
      enabled = false,
      busy = false,
      freeUsesRemaining = null;

  final VoidCallback? onInvoke;
  final bool enabled;
  final bool busy;
  final int? freeUsesRemaining;

  VoidCallback? get invocation => enabled && !busy ? onInvoke : null;
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
    loading: feature.busy,
    onTap: feature.invocation == null
        ? null
        : () {
            onBeforeInvoke?.call();
            feature.invocation!();
          },
  );
}
