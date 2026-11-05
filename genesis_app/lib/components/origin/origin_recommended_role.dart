import '../../network/models/origin.dart';
import 'origin_role_draft.dart';

/// A page-local view of the original preset; never changes the Origin template.
class OriginRecommendedRole {
  const OriginRecommendedRole._(this.character, this.role);

  final OriginCharacter character;
  final OriginCustomRoleDraft role;

  String get characterId => character.characterId.trim();

  static OriginRecommendedRole? resolve(
    Iterable<OriginCharacter> characters, {
    OriginCustomRoleDraft? profile,
    OriginCustomRoleDraft? editedRole,
    String? editedCharacterId,
  }) {
    final character = characters
        .where(
          (item) => item.isRecommended && item.characterId.trim().isNotEmpty,
        )
        .firstOrNull;
    if (character == null) return null;
    final name = character.name.trim();
    final role =
        editedCharacterId == character.characterId.trim() && editedRole != null
        ? OriginCustomRoleDraft(
            name: editedRole.name,
            avatarUrl: editedRole.avatarUrl,
            identity: editedRole.identity,
            personality: editedRole.personality,
            bio: editedRole.bio,
            goal: character.goal,
          )
        : OriginCustomRoleDraft(
            name: name.isEmpty || name == '{{user}}'
                ? profile?.name ?? ''
                : name,
            avatarUrl: character.avatar.trim().isEmpty
                ? profile?.avatarUrl ?? ''
                : character.avatar,
            identity: character.identity,
            personality: character.brief,
            bio: character.description,
            goal: character.goal,
          );
    return OriginRecommendedRole._(character, role);
  }

  OriginRoleLaunchSelection toLaunchSelection() =>
      OriginRoleLaunchSelection.preset(
        characterId,
        presetCharacterOverride: {
          'name': role.name.trim(),
          'identity': role.identity.trim(),
          'personality': role.personality.trim(),
          // description is the response spelling of bio. Current backend
          // accepts this compatibility field but ignores it (see checkpoint).
          'bio': role.bio,
          // Empty is explicit: deleting an image must not inherit the preset.
          'avatar': role.avatarUrl.trim().isEmpty
              ? <String, dynamic>{}
              : role.avatarUrl.trim(),
        },
      );
}
