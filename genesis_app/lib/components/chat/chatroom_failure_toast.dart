import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/api_exception.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/chatroom_feature_quota_models.dart';
import '../../network/chatroom/chatroom_failure_identity.dart';
import '../common/genesis_center_toast.dart';

const Set<String> _userInitiatedChatroomRequestTypes = <String>{
  'join',
  'leave',
  'send_message',
};

const Set<String> _replyActionRequestTypes = <String>{
  'regenerate_llm_card',
  'go_on',
  'select_llm_card',
  'send_message', // Sending an inspiration uses the normal send request.
  'end_conversation_round',
  'llm_card_stream',
  'llm_card_generation_end',
};

bool _isReplyActionBusinessFailure(ChatroomFailureEvent failure) {
  final code = int.tryParse(failure.code.trim());
  return code != null &&
      code != 0 &&
      (_replyActionRequestTypes.contains(failure.requestType.trim()) ||
          _replyActionRequestTypes.contains(failure.sourceType.trim()) ||
          failure.sourceType == 'error');
}

/// These errors are already presented by the HTTP interceptor or WS listener.
/// Request futures and controller notifications must not present them again.
bool isChatroomErrorPresentedGlobally(Object? error) => switch (error) {
  ChatroomFeatureQuotaException() => false,
  ApiException e => e.kind == ApiExceptionKind.business,
  ChatroomFailureEvent() || ChatroomErrorEvent() => true,
  ChatroomPayloadEvent e => !e.ok,
  ChatroomLlmCardGenerationEnd e => e.errNo != 0,
  ChatroomLlmCardStream e => e.errNo != 0,
  _ => false,
};

String chatroomOperationErrorMessage(Object error) => switch (error) {
  ApiException e when e.kind == ApiExceptionKind.business => e.message.trim(),
  ChatroomFailureEvent e => chatroomFailureToastMessage(e),
  ChatroomErrorEvent e => e.message.trim(),
  ChatroomPayloadEvent e when !e.ok => e.codeMsg.trim(),
  ChatroomLlmCardGenerationEnd e when e.errNo != 0 => e.errMsg.trim(),
  ChatroomLlmCardStream e when e.errNo != 0 => e.errMsg.trim(),
  _ => '',
};

const Set<String> _passiveChatroomFailureCodes = <String>{
  'connect_failed',
  'event_handle_failed',
  'heartbeat_failed',
  'message_cache_failed',
  'message_cache_load_failed',
  'message_history_load_failed',
  'protocol_error',
  'snapshot_failed',
  'socket_closed',
  'socket_error',
  'stream_missing',
};

const Set<String> _passiveChatroomFailureSourceTypes = <String>{
  'connect',
  'disconnect',
  'heartbeat',
  'socket',
  'socket_closed',
  'socket_error',
};

bool isChatroomUnauthorizedFailure(ChatroomFailureEvent failure) {
  return failure.code.trim() == '10001';
}

bool shouldShowChatroomFailureToast(ChatroomFailureEvent failure) {
  if (chatroomFailureToastMessage(failure).isEmpty) return false;
  if (_isReplyActionBusinessFailure(failure)) return true;
  if (failure.code.trim() == '3001') return false;

  final requestType = failure.requestType.trim();
  if (_userInitiatedChatroomRequestTypes.contains(requestType)) return true;

  final code = failure.code.trim();
  if (_passiveChatroomFailureCodes.contains(code)) return false;

  final sourceType = failure.sourceType.trim();
  if (_passiveChatroomFailureSourceTypes.contains(sourceType)) return false;

  return true;
}

String chatroomFailureToastMessage(ChatroomFailureEvent failure) {
  final cause = failure.cause;
  final message = switch (cause) {
    ChatroomAck e when !e.ok => e.codeMsg,
    ChatroomAck e when e.regeneration?.error != null =>
      _chatroomErrorMapMessage(e.regeneration!.error),
    ChatroomPayloadEvent e when !e.ok => e.codeMsg,
    ChatroomErrorEvent e => e.message,
    ChatroomLlmCardStream e when e.errNo != 0 => e.errMsg,
    ChatroomLlmCardGenerationEnd e
        when e.errNo != 0 ||
            e.generationState == ChatroomCardGenerationState.failed =>
      e.errMsg.isNotEmpty ? e.errMsg : _chatroomErrorMapMessage(e.error),
    _ => '',
  };
  return message.trim();
}

String _chatroomErrorMapMessage(Object? error) {
  if (error is! Map) return '';
  final message = error['err_msg'];
  return message is String ? message.trim() : '';
}

Duration chatroomFailureToastDuration(ChatroomFailureEvent failure) {
  return const <String>{
        '1002',
        '1008',
        '2006',
        '2010',
        '5000',
        '10001',
      }.contains(failure.code.trim())
      ? const Duration(seconds: 4)
      : const Duration(seconds: 2);
}

StreamSubscription<ChatroomFailureEvent> bindChatroomFailureToast(
  BuildContext context,
  Stream<ChatroomFailureEvent> failures, {
  bool Function(ChatroomFailureEvent failure)? shouldShow,
  void Function(ChatroomFailureEvent failure)? onFailure,
}) {
  // A single WS event can reach the service through both events and failures.
  // Deduplicate by event identity, while allowing identical text on a new try.
  final seen = <Object>[];
  final seenOccurrences = <String>{};
  return failures.listen((failure) {
    final occurrence = chatroomFailureOccurrenceKey(failure);
    if (occurrence != null && !seenOccurrences.add(occurrence)) return;
    if (seenOccurrences.length > 512) {
      seenOccurrences.remove(seenOccurrences.first);
    }
    final identity = failure.cause is ChatroomEvent ? failure.cause! : failure;
    if (seen.any((previous) => identical(previous, identity))) return;
    seen.add(identity);
    if (seen.length > 64) seen.removeAt(0);
    if (shouldShow != null && !shouldShow(failure)) return;
    onFailure?.call(failure);
    if (!shouldShowChatroomFailureToast(failure)) return;
    if (context.mounted) {
      showGenesisToast(
        context,
        chatroomFailureToastMessage(failure),
        duration: chatroomFailureToastDuration(failure),
      );
    }
  });
}
