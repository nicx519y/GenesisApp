import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';

class WorldDescriptionCard extends StatelessWidget {
  const WorldDescriptionCard({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(MyFlutterApp.eye, size: 14, color: Color(0xFFFF2344)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: Color(0xFF111111),
          ),
        ),
      ],
    );
  }
}
