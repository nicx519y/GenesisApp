import 'package:flutter/material.dart';

import '../../../ui/components/genesis_avatar.dart';

class LocationChatAvatar extends StatelessWidget {
  const LocationChatAvatar({
    super.key,
    required this.label,
    required this.colors,
    this.seed,
  });

  final String label;
  final List<Color> colors;
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final seed = this.seed?.trim();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: seed == null || seed.isEmpty ? null : avatarColorForName(seed),
        gradient: seed == null || seed.isEmpty
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              )
            : null,
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
  return initialsForAvatarName(value);
}
