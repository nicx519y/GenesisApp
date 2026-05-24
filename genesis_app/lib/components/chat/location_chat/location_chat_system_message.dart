import 'package:flutter/material.dart';

class LocationChatSystemMessage extends StatelessWidget {
  const LocationChatSystemMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}
