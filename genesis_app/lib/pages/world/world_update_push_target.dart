import '../../components/world_map_location_action.dart';
import '../../components/world_point.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/world.dart';

/// Resolves the Location Chat target for a world-content push notice.
///
/// Returning `null` means the corresponding map node would drill down instead
/// of entering Location Chat directly, so the notice must not be displayed.
WorldPoint? resolveWorldUpdatePushChatTarget({
  required WorldContentUpdateNotice notice,
  required WorldDetail world,
  required List<WorldMapLocationNode> locationNodes,
}) {
  final targetLocationId = switch (notice.kind) {
    WorldContentUpdateKind.location => notice.entityId.trim(),
    WorldContentUpdateKind.character => _currentCharacterLocationId(
      world,
      notice.entityId,
    ),
  };
  if (targetLocationId.isEmpty) return null;

  final node = findWorldMapLocationNode(locationNodes, targetLocationId);
  if (node == null) return null;
  return resolveWorldMapLocationAction(node).chatTarget;
}

String _currentCharacterLocationId(WorldDetail world, String characterId) {
  final targetCharacterId = characterId.trim();
  if (targetCharacterId.isEmpty) return '';

  for (final position in world.characterPositions) {
    final positionedCharacter = _stringKeyedMap(position['character']);
    if (!_hasCharacterId(positionedCharacter, targetCharacterId) &&
        !_hasCharacterId(position, targetCharacterId)) {
      continue;
    }
    final locationId = _firstString(position, const [
      'current_location_id',
      'location_id',
    ]);
    if (locationId.isNotEmpty) return locationId;
  }

  for (final character in world.characters) {
    if (!_hasCharacterId(character, targetCharacterId)) continue;
    return _firstString(character, const [
      'current_location_id',
      'location_id',
    ]);
  }
  return '';
}

bool _hasCharacterId(Map<String, dynamic> character, String characterId) {
  return _firstString(character, const ['char_id', 'character_id', 'id']) ==
      characterId;
}

String _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic> _stringKeyedMap(Object? value) {
  if (value is! Map) return const <String, dynamic>{};
  return value.map((key, item) => MapEntry('$key', item));
}
