import 'package:flutter/material.dart';

class LocationChatAvatar extends StatelessWidget {
  const LocationChatAvatar({
    super.key,
    required this.label,
    required this.colors,
  });

  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

String locationChatInitials(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '?';
  final chars = clean.characters.take(2).toList(growable: false);
  return chars.join().toUpperCase();
}
