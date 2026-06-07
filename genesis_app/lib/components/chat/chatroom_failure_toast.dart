import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/chatroom/chatroom_models.dart';
import '../common/genesis_center_toast.dart';

StreamSubscription<ChatroomFailureEvent> bindChatroomFailureToast(
  BuildContext context,
  Stream<ChatroomFailureEvent> failures, {
  bool Function(ChatroomFailureEvent failure)? shouldShow,
  void Function(ChatroomFailureEvent failure)? onFailure,
}) {
  return failures.listen((failure) {
    if (shouldShow != null && !shouldShow(failure)) return;
    if (context.mounted) {
      showGenesisToast(context, failure.message);
      onFailure?.call(failure);
    }
  });
}
