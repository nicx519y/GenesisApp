import 'package:flutter/material.dart';

import '../../../icons/my_flutter_app_icons.dart';

class LocationChatAiBadge extends StatelessWidget {
  const LocationChatAiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(
      MyFlutterApp.redstarCharIcon,
      size: 16,
      color: Color(0xFFF42C47),
    );
  }
}
