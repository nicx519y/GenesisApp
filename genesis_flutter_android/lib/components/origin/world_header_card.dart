import 'package:flutter/material.dart';

class WorldHeaderCard extends StatelessWidget {
  const WorldHeaderCard({
    super.key,
    required this.title,
    required this.oid,
    required this.updatedText,
    required this.originator,
  });

  final String title;
  final String oid;
  final String updatedText;
  final String originator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B6192),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          spacing: 10,
          children: [
            Text(
              'OID: $oid',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF888888),
              ),
            ),
            Text(
              'Last updated: $updatedText',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF888888),
              ),
            ),
            const Spacer(),
            Text(
              'Originator: $originator >',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF888888),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
