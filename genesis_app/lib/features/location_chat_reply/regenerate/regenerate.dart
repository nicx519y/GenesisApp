import 'package:flutter/foundation.dart';

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
