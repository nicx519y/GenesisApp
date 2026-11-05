import 'package:flutter/foundation.dart';

@immutable
class OriginCustomRoleDraft {
  const OriginCustomRoleDraft({
    this.avatarUrl = '',
    this.name = '',
    this.identity = '',
    this.personality = '',
    this.bio = '',
    this.goal = '',
  });

  final String avatarUrl;
  final String name;
  final String identity;
  final String personality;
  final String bio;
  final String goal;

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'identity': identity.trim(),
    };
    if (avatarUrl.trim().isNotEmpty) payload['avatar'] = avatarUrl.trim();
    if (personality.trim().isNotEmpty) {
      payload['personality'] = personality.trim();
    }
    if (bio.trim().isNotEmpty) payload['bio'] = bio.trim();
    if (goal.trim().isNotEmpty) payload['goal'] = goal.trim();
    return payload;
  }
}

@immutable
class OriginRoleLaunchSelection {
  const OriginRoleLaunchSelection._({
    this.presetCharacterId,
    this.presetCharacterOverride,
    this.customRole,
    this.initialLocationId,
  });

  factory OriginRoleLaunchSelection.preset(
    String characterId, {
    String? initialLocationId,
    Map<String, dynamic>? presetCharacterOverride,
  }) => OriginRoleLaunchSelection._(
    presetCharacterId: characterId,
    presetCharacterOverride: presetCharacterOverride,
    initialLocationId: initialLocationId,
  );

  factory OriginRoleLaunchSelection.custom(OriginCustomRoleDraft role) =>
      OriginRoleLaunchSelection._(customRole: role);

  final String? presetCharacterId;
  final Map<String, dynamic>? presetCharacterOverride;
  final OriginCustomRoleDraft? customRole;
  final String? initialLocationId;
}
