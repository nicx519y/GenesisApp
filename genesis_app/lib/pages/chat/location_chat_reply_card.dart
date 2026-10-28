import 'package:flutter/widgets.dart';

import '../../components/chat/shared/chat_ui.dart' show ChatMessageVm;

class LocationChatReplyCard {
  const LocationChatReplyCard({
    required this.id,
    required List<ChatMessageVm> messages,
    this.status,
    this.contentIdentity,
  }) : _messages = messages,
       _resolveMessages = null;

  const LocationChatReplyCard.lazy({
    required this.id,
    required List<ChatMessageVm> Function() resolveMessages,
    this.status,
    this.contentIdentity,
  }) : _messages = null,
       _resolveMessages = resolveMessages;

  final int id;
  final List<ChatMessageVm>? _messages;
  final List<ChatMessageVm> Function()? _resolveMessages;
  List<ChatMessageVm> get messages => _messages ?? _resolveMessages!();
  final Object? contentIdentity;
  final Widget? status;
}
