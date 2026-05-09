import 'package:flutter/material.dart';

class SearchBarPlaceholder extends StatelessWidget {
  const SearchBarPlaceholder({super.key, this.hintText = 'Explore'});

  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF9E9E9E), size: 20),
          const SizedBox(width: 8),
          Text(
            hintText,
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

