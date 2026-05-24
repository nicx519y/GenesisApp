import 'package:flutter/material.dart';

import 'location_chat_message_row.dart';
import 'location_chat_message_vm.dart';

class LocationChatMessageList extends StatelessWidget {
  const LocationChatMessageList({
    super.key,
    required this.controller,
    required this.messages,
  });

  final ScrollController controller;
  final List<LocationChatMessageVm> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final current = messages[index];
        final previous = index == 0 ? null : messages[index - 1];
        return LocationChatMessageRow(
          message: current,
          showDateDivider:
              index == 0 ||
              (previous != null &&
                  current.createdAt.day != previous.createdAt.day),
        );
      },
    );
  }
}
