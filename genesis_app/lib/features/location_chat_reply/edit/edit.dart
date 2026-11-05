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
