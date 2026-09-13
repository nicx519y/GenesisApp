/// Presentation state of one reply action for the current conversation round.
enum LocationChatReplyActionState { none, disabled, busy, idle }

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
