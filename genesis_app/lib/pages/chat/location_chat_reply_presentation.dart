import '../../components/chat/shared/chat_ui.dart';

/// Replaces only canonical AI replies in the selected round. UI flags such as
/// isSystem (which includes narrators) and isMe do not define card membership.
List<ChatMessageVm> buildLocationChatReplyPresentation({
  required List<ChatMessageVm> source,
  required String roundId,
  required Set<int> replyMessageIds,
  List<ChatMessageVm>? candidates,
}) {
  if (candidates == null) return List<ChatMessageVm>.of(source);
  final output = <ChatMessageVm>[];
  var inserted = false;
  for (final message in source) {
    if (message.roundId == roundId &&
        message.globalMessageId > 0 &&
        replyMessageIds.contains(message.globalMessageId)) {
      if (!inserted) output.addAll(candidates);
      inserted = true;
    } else {
      output.add(message);
    }
  }
  if (!inserted) {
    output.addAll(candidates);
  }
  return output;
}
