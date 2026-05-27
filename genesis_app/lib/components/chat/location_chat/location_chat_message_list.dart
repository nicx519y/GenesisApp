import 'package:flutter/material.dart';

import 'location_chat_message_row.dart';
import 'location_chat_message_vm.dart';

class LocationChatMessageList extends StatelessWidget {
  const LocationChatMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.worldName,
  });

  final ScrollController controller;
  final List<LocationChatMessageVm> messages;
  final String worldName;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _LocationChatWorldTitle(name: worldName);

        final messageIndex = index - 1;
        final current = messages[messageIndex];
        final previous = messageIndex == 0 ? null : messages[messageIndex - 1];
        return LocationChatMessageRow(
          message: current,
          showDateDivider:
              messageIndex == 0 ||
              (previous != null &&
                  current.createdAt.day != previous.createdAt.day),
        );
      },
    );
  }
}

class _LocationChatWorldTitle extends StatelessWidget {
  const _LocationChatWorldTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
