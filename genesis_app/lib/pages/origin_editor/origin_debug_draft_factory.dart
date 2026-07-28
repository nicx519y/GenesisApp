import 'dart:convert';
import 'dart:math';

import '../create/create_origin_draft_store.dart';
import 'origin_debug_content_config.dart' as debug_content;

CreateOriginDraft generateRandomCreateOriginDraft(
  CreateOriginDraft current, {
  Random? random,
  DateTime? now,
}) {
  final currentOriginId = current.basics.originId.trim();
  return _generateRandomOriginDraft(
    originId: currentOriginId.isEmpty ? null : currentOriginId,
    random: random,
    now: now,
  );
}

CreateOriginDraft generateRandomEditOriginDraft(
  CreateOriginDraft current, {
  Random? random,
  DateTime? now,
}) {
  final generated = _generateRandomOriginDraft(
    originId: current.basics.originId,
    originVersion: current.basics.originVersion,
    random: random,
    now: now,
  );
  return _preserveEditEntityIdentity(current, generated);
}

CreateOriginDraft _preserveEditEntityIdentity(
  CreateOriginDraft current,
  CreateOriginDraft generated,
) {
  final existingCharacters = current.characters
      .where((item) => item.charId.trim().isNotEmpty)
      .toList(growable: false);
  final characters = existingCharacters.isEmpty
      ? generated.characters
      : <CharacterDraft>[
          for (int index = 0; index < existingCharacters.length; index++)
            generated.characters[index % generated.characters.length].copyWith(
              charId: existingCharacters[index].charId.trim(),
              name:
                  '${generated.characters[index % generated.characters.length].name} ${index + 1}',
            ),
        ];

  final generatedByLevel = <int, List<LocationDraft>>{
    for (final level in const <int>[1, 2, 3])
      level: generated.locations
          .where((item) => item.level == level)
          .toList(growable: false),
  };
  final existingLocations = current.locations
      .where((item) => item.locationId.trim().isNotEmpty)
      .toList(growable: false);
  final locations = <LocationDraft>[];
  final levelOrdinals = <int, int>{};
  for (final existing in existingLocations) {
    final level = existing.level;
    final templates = generatedByLevel[level];
    final ordinal = levelOrdinals.update(
      level,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    final template = templates == null || templates.isEmpty
        ? generated.locations.last
        : templates[ordinal % templates.length];
    locations.add(
      existing.copyWith(
        name: '${template.name} ${ordinal + 1}',
        description: level == 3 ? template.description : existing.description,
        imageUrl: level == 3 ? template.imageUrl : existing.imageUrl,
        initialCharacterIds: const <String>[],
      ),
    );
  }
  locations.addAll(
    _additionalDebugLocations(
      currentLocations: locations,
      generatedLocations: generated.locations,
      minimumLeafCount: 6,
    ),
  );

  final leafLocations = locations
      .where((item) => item.level == 3)
      .toList(growable: false);
  final bindingsByLocationId = <String, List<String>>{
    for (final location in leafLocations) location.locationId: <String>[],
  };
  for (int index = 0; index < characters.length; index++) {
    bindingsByLocationId[leafLocations[index % leafLocations.length]
            .locationId]!
        .add(characters[index].charId);
  }
  final locationsWithBindings = locations
      .map(
        (item) => item.copyWith(
          initialCharacterIds:
              bindingsByLocationId[item.locationId] ?? const <String>[],
        ),
      )
      .toList(growable: false);
  final openingLocation = leafLocations.first;
  final openingCharacter = characters.first;

  return generated.copyWith(
    characters: characters,
    locations: locationsWithBindings,
    opening: OpeningDraft(
      locationId: openingLocation.locationId,
      locationName: openingLocation.name,
      dialogue: <OpeningDialogueDraft>[
        generated.opening.dialogue.first,
        OpeningDialogueDraft(
          type: OpeningDialogueDraft.characterType,
          characterId: openingCharacter.charId,
          content: generated.opening.dialogue[1].content,
        ),
        generated.opening.dialogue.last,
      ],
    ),
  );
}

List<LocationDraft> _additionalDebugLocations({
  required List<LocationDraft> currentLocations,
  required List<LocationDraft> generatedLocations,
  required int minimumLeafCount,
}) {
  final currentLeafCount = currentLocations
      .where((item) => item.level == 3)
      .length;
  final missingLeafCount = minimumLeafCount - currentLeafCount;
  if (missingLeafCount <= 0) return const <LocationDraft>[];

  final generatedById = <String, LocationDraft>{
    for (final location in generatedLocations) location.locationId: location,
  };
  final requiredIds = <String>{};
  final selectedLeaves = generatedLocations
      .where((item) => item.level == 3)
      .take(missingLeafCount);
  for (final leaf in selectedLeaves) {
    requiredIds.add(leaf.locationId);
    final district = generatedById[leaf.parentLocationId];
    if (district == null) continue;
    requiredIds.add(district.locationId);
    if (district.parentLocationId.isNotEmpty) {
      requiredIds.add(district.parentLocationId);
    }
  }
  return generatedLocations
      .where((item) => requiredIds.contains(item.locationId))
      .toList(growable: false);
}

CreateOriginDraft _generateRandomOriginDraft({
  String? originId,
  String originVersion = '',
  Random? random,
  DateTime? now,
}) {
  final randomSource = random ?? Random();
  final timestamp = (now ?? DateTime.now()).toUtc();
  final token =
      '${timestamp.microsecondsSinceEpoch.toRadixString(36)}'
      '-${randomSource.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  final templates = debug_content.originDebugContentTemplates;
  if (templates.isEmpty) {
    throw StateError('Debug Origin content is unavailable in release builds.');
  }
  final theme = templates[randomSource.nextInt(templates.length)];

  final localOriginId = originId?.trim().isNotEmpty == true
      ? originId!.trim()
      : 'origin_debug_$token';
  final firstCharacterId = 'char_debug_${token}_1';
  final secondCharacterId = 'char_debug_${token}_2';
  final imageSeed = 'worldo-debug-$token';
  final imageLockBase = randomSource.nextInt(900000) + 100000;
  final locations = <LocationDraft>[];
  final leafLocations = <LocationDraft>[];
  var leafIndex = 0;
  for (int regionIndex = 0; regionIndex < theme.regions.length; regionIndex++) {
    final region = theme.regions[regionIndex];
    final level1Id = 'Loc_debug_${token}_${regionIndex + 1}';
    locations.add(
      LocationDraft(locationId: level1Id, level: 1, name: region.name),
    );
    for (
      int districtIndex = 0;
      districtIndex < region.districts.length;
      districtIndex++
    ) {
      final district = region.districts[districtIndex];
      final level2Id = '${level1Id}_${districtIndex + 1}';
      locations.add(
        LocationDraft(
          locationId: level2Id,
          parentLocationId: level1Id,
          level: 2,
          name: district.name,
        ),
      );
      for (
        int locationIndex = 0;
        locationIndex < district.locations.length;
        locationIndex++
      ) {
        final location = district.locations[locationIndex];
        final level3Id = '${level2Id}_${locationIndex + 1}';
        final leaf = LocationDraft(
          locationId: level3Id,
          parentLocationId: level2Id,
          level: 3,
          imageUrl: _debugLocationImageUrl(
            leafIndex: leafIndex,
            imageLockBase: imageLockBase,
            keywords: location.imageKeywords,
          ),
          name: location.name,
          description: location.description,
          initialCharacterIds: switch (leafIndex) {
            0 => <String>[firstCharacterId],
            1 => <String>[secondCharacterId],
            _ => const <String>[],
          },
        );
        locations.add(leaf);
        leafLocations.add(leaf);
        leafIndex++;
      }
    }
  }
  final openingLocation = leafLocations.first;

  return CreateOriginDraft(
    basics: BasicsDraft(
      originId: localOriginId,
      originVersion: originVersion.trim(),
      originName:
          '${theme.name} ${timestamp.second.toString().padLeft(2, '0')}',
      worldView: theme.worldView,
      worldLogic: theme.worldLogic,
      metricJson: jsonEncode(const <String, dynamic>{
        'mode': 'qualitative',
        'label': 'Momentum',
        'label_note': 'Tracks how close each character is to their goal.',
        'unit': '%',
        'range': <int>[0, 100],
        'default': 20,
      }),
      startedAt: 'Day 1, 08:00',
      tickDurationTime: '1 day',
      coverImageUrl: 'https://picsum.photos/seed/$imageSeed-cover/800/1200',
    ),
    characters: <CharacterDraft>[
      CharacterDraft(
        charId: firstCharacterId,
        avatarUrl:
            'https://loremflickr.com/1080/1080/portrait,person/all'
            '?lock=${imageLockBase + 1}',
        name: theme.firstCharacterName,
        identity: theme.firstCharacterIdentity,
        personality: 'Observant, decisive, and quietly compassionate.',
        bio: theme.firstCharacterBio,
        goal: theme.firstCharacterGoal,
      ),
      CharacterDraft(
        charId: secondCharacterId,
        avatarUrl:
            'https://loremflickr.com/1080/1080/anime,character/all'
            '?lock=${imageLockBase + 2}',
        name: theme.secondCharacterName,
        identity: theme.secondCharacterIdentity,
        personality: 'Inventive, skeptical, and loyal under pressure.',
        bio: theme.secondCharacterBio,
        goal: theme.secondCharacterGoal,
      ),
    ],
    locations: locations,
    opening: OpeningDraft(
      locationId: openingLocation.locationId,
      locationName: openingLocation.name,
      dialogue: <OpeningDialogueDraft>[
        OpeningDialogueDraft(
          type: OpeningDialogueDraft.narratorType,
          content: theme.openingNarration,
        ),
        OpeningDialogueDraft(
          type: OpeningDialogueDraft.characterType,
          characterId: firstCharacterId,
          content: theme.openingDialogue,
        ),
        OpeningDialogueDraft(
          type: OpeningDialogueDraft.imageType,
          content: 'https://picsum.photos/seed/$imageSeed-opening/1200/675',
        ),
      ],
    ),
    storyEvents: theme.storyEvents
        .map((event) => StoryEventDraft(event: event))
        .toList(growable: false),
    basicsSaved: true,
    charactersSaved: true,
    locationsSaved: true,
    openingSaved: true,
    storyEventsSaved: true,
  );
}

String _debugLocationImageUrl({
  required int leafIndex,
  required int imageLockBase,
  required String keywords,
}) {
  final normalizedKeywords = keywords
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .join(',');
  final safeKeywords = normalizedKeywords.isEmpty
      ? 'landscape,architecture'
      : normalizedKeywords;
  return 'https://loremflickr.com/1080/1080/$safeKeywords/all'
      '?lock=${imageLockBase + 10 + leafIndex}';
}
