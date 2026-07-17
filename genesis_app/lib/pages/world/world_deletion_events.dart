import 'package:flutter/foundation.dart';

@immutable
final class WorldDeletionEvent {
  const WorldDeletionEvent({required this.worldId});

  final String worldId;
}

final ValueNotifier<WorldDeletionEvent?> worldDeletionEvents =
    ValueNotifier<WorldDeletionEvent?>(null);

void publishWorldDeletion(String rawWorldId) {
  final worldId = rawWorldId.trim();
  if (worldId.isEmpty) return;
  worldDeletionEvents.value = WorldDeletionEvent(worldId: worldId);
}
