import 'package:flutter/foundation.dart';

@immutable
final class WorldDeletionEvent {
  const WorldDeletionEvent({required this.worldId});

  final String worldId;
}

final ValueNotifier<WorldDeletionEvent?> worldDeletionEvents =
    ValueNotifier<WorldDeletionEvent?>(null);

@immutable
final class WorldListRefreshEvent {
  const WorldListRefreshEvent({required this.worldId});

  final String worldId;
}

final ValueNotifier<WorldListRefreshEvent?> worldListRefreshEvents =
    ValueNotifier<WorldListRefreshEvent?>(null);

void publishWorldDeletion(String rawWorldId) {
  final worldId = rawWorldId.trim();
  if (worldId.isEmpty) return;
  worldDeletionEvents.value = WorldDeletionEvent(worldId: worldId);
}

void publishWorldListRefresh(String rawWorldId) {
  final worldId = rawWorldId.trim();
  if (worldId.isEmpty) return;
  worldListRefreshEvents.value = WorldListRefreshEvent(worldId: worldId);
}
