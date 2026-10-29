import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_recommended_role.dart';
import 'package:genesis_flutter_android/components/origin/origin_role_draft.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';

void main() {
  const profile = OriginCustomRoleDraft(
    name: 'Player',
    avatarUrl: 'profile.png',
    identity: 'Profile identity',
    personality: 'Profile personality',
  );

  OriginCharacter character({
    String name = 'Hero',
    String avatar = 'hero.png',
  }) => OriginCharacter.fromJson({
    'char_id': 'char_2',
    'is_recommend': 1,
    'name': name,
    'avatar': avatar,
    'identity': 'Detective',
    'brief': 'Curious',
    'description': 'Complete\nrole setting',
    'goal': 'Find the key',
    'initial_location_id': 'loc_1',
  });

  test('name fallback preserves the recommended image and role data', () {
    for (final missingName in ['', '  ', '{{user}}', ' {{user}} ']) {
      final original = character(name: missingName);
      final merged = OriginRecommendedRole.resolve([
        original,
      ], profile: profile)!;
      expect(merged.characterId, 'char_2');
      expect(merged.role.name, 'Player');
      expect(merged.role.avatarUrl, 'hero.png');
      expect(merged.role.identity, 'Detective');
      expect(merged.role.personality, 'Curious');
      expect(merged.role.bio, 'Complete\nrole setting');
      expect(merged.role.goal, 'Find the key');
      expect(merged.character.goal, 'Find the key');
      expect(original.name, missingName);
    }
  });

  test('image fallback preserves the recommended name', () {
    final merged = OriginRecommendedRole.resolve([
      character(avatar: ''),
    ], profile: profile)!;
    expect(merged.role.name, 'Hero');
    expect(merged.role.avatarUrl, 'profile.png');
  });

  test('both missing fields are filled independently', () {
    final merged = OriginRecommendedRole.resolve([
      character(name: '{{user}}', avatar: ''),
    ], profile: profile)!;
    expect(merged.role.name, 'Player');
    expect(merged.role.avatarUrl, 'profile.png');
  });

  test('complete recommendation keeps its fields without a loaded profile', () {
    final merged = OriginRecommendedRole.resolve([character()])!;
    expect(merged.role.name, 'Hero');
    expect(merged.role.avatarUrl, 'hero.png');
  });

  test('no recommendation leaves the original custom-role path available', () {
    expect(OriginRecommendedRole.resolve([], profile: profile), isNull);
    expect(
      OriginRecommendedRole.resolve([
        OriginCharacter.fromJson({'char_id': 'regular', 'name': 'Other'}),
      ], profile: profile),
      isNull,
    );
  });

  test('edits keep the preset ID and explicitly clear optional fields', () {
    const edited = OriginCustomRoleDraft(name: 'Renamed');
    final merged = OriginRecommendedRole.resolve(
      [character()],
      profile: profile,
      editedRole: edited,
      editedCharacterId: 'char_2',
    )!;
    final selection = merged.toLaunchSelection();
    expect(selection.presetCharacterId, 'char_2');
    expect(selection.customRole, isNull);
    expect(selection.presetCharacterOverride, {
      'name': 'Renamed',
      'identity': '',
      'personality': '',
      'bio': '',
      'avatar': <String, dynamic>{},
    });
    expect(selection.presetCharacterOverride, isNot(contains('setting')));
    expect(selection.presetCharacterOverride, isNot(contains('goal')));
    expect(merged.character.name, 'Hero');
    expect(merged.character.goal, 'Find the key');
    expect(merged.role.goal, 'Find the key');
  });

  test('a different recommendation never inherits another character edits', () {
    final merged = OriginRecommendedRole.resolve(
      [character()],
      profile: profile,
      editedRole: const OriginCustomRoleDraft(name: 'Wrong role'),
      editedCharacterId: 'char_1',
    )!;
    expect(merged.role.name, 'Hero');
  });

  test('description and bio keep the complete setting separate from brief', () {
    final setting = List.filled(1200, '完整\n').join();
    for (final key in ['description', 'bio']) {
      final original = OriginCharacter.fromJson({
        'char_id': 'char_1',
        'is_recommend': 1,
        'name': 'Hero',
        'brief': 'Public personality',
        key: setting,
        'goal': 'Original goal',
      });
      final merged = OriginRecommendedRole.resolve([original])!;
      expect(original.description, setting);
      expect(merged.role.bio, setting);
      expect(merged.role.personality, 'Public personality');
      expect(
        merged.toLaunchSelection().presetCharacterOverride!['bio'],
        setting,
      );
      expect(
        merged.toLaunchSelection().presetCharacterOverride,
        isNot(contains('goal')),
      );
      expect(merged.role.goal, 'Original goal');
    }
  });
}
