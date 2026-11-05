import 'package:flutter/foundation.dart';

import '../shared/reply_action_state.dart';

export 'src/chatroom_inspiration_controller.dart'
    show ChatroomInspirationController;
export 'src/chatroom_inspiration_models.dart'
    show ChatroomInspirationResponse, ChatroomInspirationSource;
export 'src/chatroom_inspiration_storage.dart'
    show
        ChatroomInspirationStorage,
        MemoryChatroomInspirationStorage,
        SqfliteChatroomInspirationStorage;

/// Public invocation and presentation contract for inspiration replies.
///
/// Request generations, cache epochs, HTTP details, and source validation stay
/// inside the inspiration feature.
final class LocationChatInspirationFeature {
  const LocationChatInspirationFeature({
    required this.messages,
    required this.state,
    this.onExpandedChanged,
    this.onSend,
    this.onEdit,
    this.freeUsesRemaining,
  });

  const LocationChatInspirationFeature.disabled()
    : messages = const [],
      state = LocationChatReplyActionState.none,
      onExpandedChanged = null,
      onSend = null,
      onEdit = null,
      freeUsesRemaining = null;

  final List<String> messages;
  final LocationChatReplyActionState state;
  bool get enabled => state == LocationChatReplyActionState.idle;
  bool get loading => state == LocationChatReplyActionState.busy;
  final int? freeUsesRemaining;
  final ValueChanged<bool>? onExpandedChanged;
  final ValueChanged<String>? onSend;
  final ValueChanged<String>? onEdit;
}
