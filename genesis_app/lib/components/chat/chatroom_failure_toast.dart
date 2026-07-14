import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/chatroom/chatroom_models.dart';
import '../common/genesis_center_toast.dart';

const Set<String> _userInitiatedChatroomRequestTypes = <String>{
  'join',
  'leave',
  'send_message',
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

bool shouldShowChatroomFailureToast(ChatroomFailureEvent failure) {
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
  final message = failure.message.trim();
  final requestType = failure.requestType.trim();
  if (!_isGenericChatroomFailureMessage(message) &&
      !_isInternalChatroomFailureMessage(message)) {
    if (message.isNotEmpty) return message;
  }
  return switch (requestType) {
    'join' => 'Join failed',
    'leave' => 'Leave failed',
    'send_message' => 'Send failed',
    _ => message.isEmpty ? 'Something went wrong' : message,
  };
}

bool _isGenericChatroomFailureMessage(String message) {
  return message.toLowerCase() == 'something went wrong';
}

bool _isInternalChatroomFailureMessage(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('chatroom ') ||
      normalized.contains(' ack') ||
      normalized.contains('llm') ||
      normalized.contains('stream');
}

StreamSubscription<ChatroomFailureEvent> bindChatroomFailureToast(
  BuildContext context,
  Stream<ChatroomFailureEvent> failures, {
  bool Function(ChatroomFailureEvent failure)? shouldShow,
  void Function(ChatroomFailureEvent failure)? onFailure,
}) {
  return failures.listen((failure) {
    if (!shouldShowChatroomFailureToast(failure)) return;
    if (shouldShow != null && !shouldShow(failure)) return;
    if (context.mounted) {
      showGenesisToast(context, chatroomFailureToastMessage(failure));
      onFailure?.call(failure);
    }
  });
}
