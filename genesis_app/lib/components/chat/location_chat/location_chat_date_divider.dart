import 'package:flutter/material.dart';

class LocationChatDateDivider extends StatelessWidget {
  const LocationChatDateDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 26),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        _dateLabel(DateTime.now()),
        style: const TextStyle(
          color: Color(0xFF777777),
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String _dateLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return 'today $hour:$minute';
}
