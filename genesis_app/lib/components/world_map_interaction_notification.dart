import 'package:flutter/widgets.dart';

class WorldMapInteractionNotification extends Notification {
  const WorldMapInteractionNotification({required this.active});

  final bool active;
}
