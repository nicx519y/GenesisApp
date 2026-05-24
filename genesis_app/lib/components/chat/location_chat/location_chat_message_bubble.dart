import 'package:flutter/material.dart';

import 'location_chat_message_vm.dart';

class LocationChatMessageBubble extends StatelessWidget {
  const LocationChatMessageBubble({super.key, required this.message});

  final LocationChatMessageVm message;

  @override
  Widget build(BuildContext context) {
    final background = message.isMe ? const Color(0xFF26F24C) : Colors.white;
    final text = message.error == null
        ? message.text
        : '${message.text}\n${message.error}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text.isEmpty ? '...' : text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          height: 16 / 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
