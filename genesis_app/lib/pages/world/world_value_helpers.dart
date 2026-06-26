import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/origin.dart';
import '../../network/models/world.dart';

String worldMapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String worldResolvedProfileAvatar(
  Map<String, dynamic> userInfo,
  String profileAvatar,
) {
  final resolved = asResolvedImageUrl(
    worldMapValue(userInfo, const ['avatar']),
    resolveAssetUrl,
    fallback: worldMapValue(userInfo, const [
      'avatar_url',
      'photoUrl',
      'photo_url',
      'picture',
    ]),
  );
  if (resolved.isNotEmpty) return resolved;
  return asResolvedImageUrl(profileAvatar, resolveAssetUrl);
}

Object? worldMapValue(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return value;
  }
  return null;
}

String worldResolveAssetUrl(String raw) {
  return resolveAssetUrl(raw);
}

List<OriginCharacter> worldPresetRoleCharacters(WorldDetail world) {
  return world.characters
      .where(worldIsAvailablePresetWorldRole)
      .map((character) {
        final charId = worldMapString(character, const [
          'char_id',
          'character_id',
          'id',
        ]);
        final locationId = worldMapString(character, const [
          'location_id',
          'initial_location_id',
        ]);
        final locationInt = int.tryParse(locationId) ?? 0;
        return OriginCharacter(
          id: int.tryParse(charId) ?? 0,
          characterId: charId,
          originId: world.originId,
          name: worldMapString(character, const [
            'name',
          ], fallback: 'Character'),
          avatar: worldMapString(character, const ['avatar']),
          tags: worldMapString(character, const ['identity']),
          tagline: worldMapString(character, const ['brief']),
          description: worldMapString(character, const [
            'description',
            'brief',
          ]),
          goal: worldMapString(character, const ['goal']),
          currentLocationId: locationInt,
          initialLocationId: locationInt,
          createdAt: null,
          updatedAt: null,
        );
      })
      .toList(growable: false);
}

bool worldIsAvailablePresetWorldRole(Map<String, dynamic> character) {
  final charId = worldMapString(character, const [
    'char_id',
    'character_id',
    'id',
  ]);
  if (charId.isEmpty) return false;
  final playerUid = worldMapString(character, const ['player_uid']);
  return playerUid.isEmpty;
}

String worldFirstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

List<String> worldOrderedNonEmptyStrings(Iterable<String?> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || !seen.add(trimmed)) continue;
    result.add(trimmed);
  }
  return result;
}

bool worldIsCurrentUserCharacter(
  Map<String, dynamic> character,
  String currentUid,
) {
  final playerUid = worldMapString(character, const ['player_uid']);
  return currentUid.isNotEmpty &&
      playerUid.isNotEmpty &&
      playerUid == currentUid;
}

bool worldIsCharacterRole(Map<String, dynamic> character) {
  return worldMapString(character, const ['player_uid']).isEmpty;
}
