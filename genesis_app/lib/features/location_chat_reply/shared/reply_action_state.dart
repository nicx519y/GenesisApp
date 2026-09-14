import 'package:flutter/foundation.dart';

/// Presentation state of one reply action for the current conversation round.
enum LocationChatReplyActionState { none, disabled, busy, idle }

/// Common invocation contract; feature-specific data stays on each feature.
class LocationChatReplyAction {
  const LocationChatReplyAction({required this.onInvoke, required this.state});
  const LocationChatReplyAction.disabled()
    : onInvoke = null,
      state = LocationChatReplyActionState.none;

  final VoidCallback? onInvoke;
  final LocationChatReplyActionState state;
  bool get enabled => state == LocationChatReplyActionState.idle;
  bool get busy => state == LocationChatReplyActionState.busy;
  VoidCallback? get invocation => enabled ? onInvoke : null;
}

LocationChatReplyActionState resolveLocationChatReplyActionState({
  required bool busy,
  required bool supported,
  required bool otherReplyOperationActive,
  required bool canInvoke,
  bool showWhenUnavailable = false,
}) {
  if (busy) return LocationChatReplyActionState.busy;
  if (!supported) return LocationChatReplyActionState.none;
  if (otherReplyOperationActive) {
    return LocationChatReplyActionState.disabled;
  }
  return canInvoke
      ? LocationChatReplyActionState.idle
      : showWhenUnavailable
      ? LocationChatReplyActionState.disabled
      : LocationChatReplyActionState.none;
}
