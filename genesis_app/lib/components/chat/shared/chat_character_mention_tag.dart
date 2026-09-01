import 'package:flutter/material.dart';

class ChatCharacterMentionTag extends StatelessWidget {
  const ChatCharacterMentionTag({
    super.key,
    required this.name,
    this.style,
    this.includeTrailingSpace = false,
  });

  final String name;
  final TextStyle? style;
  final bool includeTrailingSpace;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.person_outline_rounded,
          size: effectiveStyle.fontSize,
          color: effectiveStyle.color,
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: effectiveStyle,
        ),
        if (includeTrailingSpace)
          ExcludeSemantics(child: Text(' ', style: effectiveStyle)),
      ],
    );
  }
}
