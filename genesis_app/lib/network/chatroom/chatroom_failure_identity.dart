import 'dart:convert';

import 'chatroom_models.dart';

bool isChatroomBalanceFailureCode(String code) =>
    const {'3001', '21001'}.contains(code.trim());

int chatroomCardFailureCode(Object? error, {int fallback = 2004}) {
  if (error is Map) {
    final code = int.tryParse('${error['err_no']}');
    if (code != null && code != 0) return code;
  }
  return fallback;
}

String chatroomCardFailureMessage(Object? error) {
  final message = error is Map ? error['err_msg'] : null;
  return message is String && message.trim().isNotEmpty
      ? message
      : 'Generation failed';
}

/// An outer-success ACK can still describe a terminal failed candidate.
ChatroomFailureEvent? chatroomRegenerationAckFailure(ChatroomAck ack) {
  final receipt = ack.regeneration;
  if (!ack.ok ||
      receipt == null ||
      receipt.generationState != ChatroomCardGenerationState.failed) {
    return null;
  }
  return ChatroomFailureEvent(
    code: chatroomCardFailureCode(receipt.error).toString(),
    message: chatroomCardFailureMessage(receipt.error),
    clientMsgId: ack.clientMsgId,
    sourceType: 'ack',
    requestType: 'regenerate_llm_card',
    cause: ack,
  );
}

/// Stable across ACK/terminal ordering and duplicate delivery. Keep seen keys
/// bounded and scoped to an account/world service or a single UI subscription.
String? chatroomFailureOccurrenceKey(
  ChatroomFailureEvent failure, {
  String worldId = '',
}) {
  final cause = failure.cause;
  // A transport timeout and a later definitive business rejection are distinct
  // outcomes. In particular, a timeout must not swallow a later balance alert.
  final kind = isChatroomBalanceFailureCode(failure.code)
      ? 'balance'
      : failure.code.trim();
  if (cause is ChatroomAck && (cause.regeneration?.cardId ?? 0) > 0) {
    final receipt = cause.regeneration!;
    return jsonEncode([
      'card',
      cause.worldId.isEmpty ? worldId : cause.worldId,
      cause.locationId,
      receipt.conversationRoundId,
      receipt.cardId,
      kind,
    ]);
  }
  if (cause is ChatroomLlmCardGenerationEnd) {
    return jsonEncode([
      'card',
      cause.worldId,
      cause.locationId,
      cause.conversationRoundId,
      cause.cardId,
      kind,
    ]);
  }
  if (cause is ChatroomLlmCardStream) {
    return jsonEncode([
      'card',
      cause.worldId,
      cause.locationId,
      cause.conversationRoundId,
      cause.cardId,
      kind,
    ]);
  }
  if (failure.clientMsgId.isNotEmpty) {
    return jsonEncode([
      'request',
      cause is ChatroomPayloadEvent && cause.worldId.isNotEmpty
          ? cause.worldId
          : worldId,
      failure.clientMsgId,
      kind,
    ]);
  }
  return null;
}
