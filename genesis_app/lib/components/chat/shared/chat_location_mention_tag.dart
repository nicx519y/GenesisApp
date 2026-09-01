import 'package:flutter/material.dart';

class ChatLocationMentionTag extends StatelessWidget {
  const ChatLocationMentionTag({super.key, required this.name, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.place_outlined,
          size: effectiveStyle.fontSize,
          color: effectiveStyle.color,
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: effectiveStyle,
        ),
      ],
    );
  }
}
