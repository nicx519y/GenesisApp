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
  'heartbeat_failed',
  'snapshot_failed',
  'socket_closed',
  'socket_error',
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
  final requestType = failure.requestType.trim();
  if (_userInitiatedChatroomRequestTypes.contains(requestType)) return true;

  final code = failure.code.trim();
  if (_passiveChatroomFailureCodes.contains(code)) return false;

  final sourceType = failure.sourceType.trim();
  if (_passiveChatroomFailureSourceTypes.contains(sourceType)) return false;

  return true;
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
      showGenesisToast(context, failure.message);
      onFailure?.call(failure);
    }
  });
}
