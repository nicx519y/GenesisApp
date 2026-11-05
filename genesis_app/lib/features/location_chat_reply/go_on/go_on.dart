import '../shared/reply_action_state.dart';

/// Public invocation contract for continuing from the current reply round.
final class LocationChatGoOnFeature extends LocationChatReplyAction {
  const LocationChatGoOnFeature({
    required super.onInvoke,
    required super.state,
  });
  const LocationChatGoOnFeature.disabled() : super.disabled();
}
