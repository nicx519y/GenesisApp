import 'package:flutter/material.dart';

import 'location_chat_ai_badge.dart';
import 'location_chat_avatar.dart';
import 'location_chat_date_divider.dart';
import 'location_chat_message_bubble.dart';
import 'location_chat_message_vm.dart';
import 'location_chat_system_message.dart';

class LocationChatMessageRow extends StatelessWidget {
  const LocationChatMessageRow({
    super.key,
    required this.message,
    required this.showDateDivider,
  });

  final LocationChatMessageVm message;
  final bool showDateDivider;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return LocationChatSystemMessage(text: message.text);
    }

    final row = message.isMe ? _buildMe(context) : _buildOther(context);
    if (!showDateDivider) return row;

    return Column(children: [const LocationChatDateDivider(), row]);
  }

  Widget _buildMe(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.68;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: LocationChatMessageBubble(message: message),
                ),
                if (message.status != 'sent') ...[
                  const SizedBox(height: 4),
                  Text(
                    message.status,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          LocationChatAvatar(
            label: locationChatInitials(message.senderName),
            colors: const [Color(0xFFFFE7B0), Color(0xFF9ED7FF)],
            seed: message.senderName,
          ),
        ],
      ),
    );
  }

  Widget _buildOther(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              LocationChatAvatar(
                label: locationChatInitials(message.senderName),
                colors: const [Color(0xFFBFD7F2), Color(0xFF4F6D94)],
                seed: message.senderName,
              ),
              if (message.senderType == 'character')
                const Positioned(
                  right: -8,
                  top: -9,
                  child: LocationChatAiBadge(),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: LocationChatMessageBubble(message: message),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
