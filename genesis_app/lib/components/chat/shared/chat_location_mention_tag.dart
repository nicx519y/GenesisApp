import 'package:flutter/material.dart';

class ChatLocationMentionTag extends StatelessWidget {
  const ChatLocationMentionTag({super.key, required this.name});

  static const Color backgroundColor = Colors.transparent;
  static const Color textColor = Color(0xFF3478F6);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '@$name',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
