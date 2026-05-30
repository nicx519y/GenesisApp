import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'create_origin_id_utils.dart';

class CreateOriginDraftStore {
  static const String _storageKey = 'create_origin_draft_v1';
  static const String _tempTableKey = 'create_origin_temp_table_v1';
  static const String _finalTableKey = 'create_origin_final_table_v1';

  static Future<CreateOriginDraft> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return CreateOriginDraft.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CreateOriginDraft.fromJson(decoded);
      }
      if (decoded is Map) {
        return CreateOriginDraft.fromJson(
          decoded.map((k, v) => MapEntry('$k', v)),
        );
      }
      return CreateOriginDraft.empty();
    } catch (_) {
      return CreateOriginDraft.empty();
    }
  }

  static Future<void> save(CreateOriginDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(draft.toJson()));
  }

  static Future<void> saveTemp(
    CreateOriginDraft draft, {
    required bool syncedToFinal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final table = _decodeTable(prefs.getString(_tempTableKey));
    table[_rowIdFor(draft)] = {
      'synced_to_final': syncedToFinal,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'draft': draft.toJson(),
    };
    await prefs.setString(_tempTableKey, jsonEncode(table));
    await save(draft);
  }

  static Future<void> saveFinal(CreateOriginDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final rowId = _rowIdFor(draft);
    final finalTable = _decodeTable(prefs.getString(_finalTableKey));
    finalTable[rowId] = {
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'draft': draft.toJson(),
    };

    final tempTable = _decodeTable(prefs.getString(_tempTableKey));
    tempTable[rowId] = {
      'synced_to_final': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'draft': draft.toJson(),
    };

    await prefs.setString(_finalTableKey, jsonEncode(finalTable));
    await prefs.setString(_tempTableKey, jsonEncode(tempTable));
    await save(draft);
  }

  static Future<CreateOriginDraft> loadFinal() async {
    final prefs = await SharedPreferences.getInstance();
    final table = _decodeTable(prefs.getString(_finalTableKey));
    if (table.isEmpty) return CreateOriginDraft.empty();

    final current = await load();
    final rowId = _rowIdFor(current);
    final row = table[rowId] ?? table['pending_origin'];
    final draft = _draftFromTableRow(row);
    if (draft != null) return draft;

    for (final value in table.values) {
      final fallbackDraft = _draftFromTableRow(value);
      if (fallbackDraft != null) return fallbackDraft;
    }
    return CreateOriginDraft.empty();
  }

  static Future<List<CharacterDraft>> loadFinalCharacters() async {
    final draft = await loadFinal();
    if (!draft.charactersSaved) return const <CharacterDraft>[];
    return draft.characters
        .where(
          (item) =>
              item.charId.trim().isNotEmpty && item.name.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_tempTableKey);
    await prefs.remove(_finalTableKey);
  }

  static Map<String, dynamic> _decodeTable(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.map((k, v) => MapEntry('$k', v));
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  static CreateOriginDraft? _draftFromTableRow(Object? row) {
    final rowMap = _asMap(row);
    if (rowMap.isEmpty) return null;
    final draftMap = _asMap(rowMap['draft']);
    if (draftMap.isEmpty) return null;
    return CreateOriginDraft.fromJson(draftMap);
  }

  static String _rowIdFor(CreateOriginDraft draft) {
    final originId = draft.basics.originId.trim();
    if (originId.isNotEmpty) return originId;
    return 'pending_origin';
  }
}

class CreateOriginDraft {
  const CreateOriginDraft({
    required this.basics,
    required this.characters,
    required this.locations,
    required this.storyEvents,
    required this.basicsSaved,
    required this.charactersSaved,
    required this.locationsSaved,
    required this.storyEventsSaved,
  });

  final BasicsDraft basics;
  final List<CharacterDraft> characters;
  final List<LocationDraft> locations;
  final List<StoryEventDraft> storyEvents;
  final bool basicsSaved;
  final bool charactersSaved;
  final bool locationsSaved;
  final bool storyEventsSaved;

  factory CreateOriginDraft.empty() {
    return const CreateOriginDraft(
      basics: BasicsDraft(),
      characters: <CharacterDraft>[CharacterDraft()],
      locations: <LocationDraft>[LocationDraft()],
      storyEvents: <StoryEventDraft>[StoryEventDraft()],
      basicsSaved: false,
      charactersSaved: false,
      locationsSaved: false,
      storyEventsSaved: false,
    );
  }

  factory CreateOriginDraft.fromJson(Map<String, dynamic> json) {
    final charactersRaw = json['characters'];
    final locationsRaw = json['locations'];
    final storyEventsRaw = json['story_events'];

    return CreateOriginDraft(
      basics: BasicsDraft.fromJson(_asMap(json['basics'])),
      characters: _asList(charactersRaw)
          .map((item) => CharacterDraft.fromJson(_asMap(item)))
          .toList(growable: false),
      locations: _asList(locationsRaw)
          .map((item) => LocationDraft.fromJson(_asMap(item)))
          .toList(growable: false),
      storyEvents: _asList(storyEventsRaw)
          .map((item) => StoryEventDraft.fromJson(_asMap(item)))
          .toList(growable: false),
      basicsSaved: _asBool(json['basics_saved']),
      charactersSaved: _asBool(json['characters_saved']),
      locationsSaved: _asBool(json['locations_saved']),
      storyEventsSaved: _asBool(json['story_events_saved']),
    ).normalized();
  }

  Map<String, dynamic> toJson() {
    return {
      'basics': basics.toJson(),
      'characters': characters.map((item) => item.toJson()).toList(),
      'locations': locations.map((item) => item.toJson()).toList(),
      'story_events': storyEvents.map((item) => item.toJson()).toList(),
      'basics_saved': basicsSaved,
      'characters_saved': charactersSaved,
      'locations_saved': locationsSaved,
      'story_events_saved': storyEventsSaved,
    };
  }

  CreateOriginDraft copyWith({
    BasicsDraft? basics,
    List<CharacterDraft>? characters,
    List<LocationDraft>? locations,
    List<StoryEventDraft>? storyEvents,
    bool? basicsSaved,
    bool? charactersSaved,
    bool? locationsSaved,
    bool? storyEventsSaved,
  }) {
    return CreateOriginDraft(
      basics: basics ?? this.basics,
      characters: characters ?? this.characters,
      locations: locations ?? this.locations,
      storyEvents: storyEvents ?? this.storyEvents,
      basicsSaved: basicsSaved ?? this.basicsSaved,
      charactersSaved: charactersSaved ?? this.charactersSaved,
      locationsSaved: locationsSaved ?? this.locationsSaved,
      storyEventsSaved: storyEventsSaved ?? this.storyEventsSaved,
    ).normalized();
  }

  CreateOriginDraft normalized() {
    return CreateOriginDraft(
      basics: basics,
      characters: characters.isEmpty
          ? const <CharacterDraft>[CharacterDraft()]
          : characters,
      locations: locations.isEmpty
          ? const <LocationDraft>[LocationDraft()]
          : locations,
      storyEvents: storyEvents.isEmpty
          ? const <StoryEventDraft>[StoryEventDraft()]
          : storyEvents,
      basicsSaved: basicsSaved,
      charactersSaved: charactersSaved,
      locationsSaved: locationsSaved,
      storyEventsSaved: storyEventsSaved,
    );
  }

  CreateOriginDraft pruneLocationBindings(Set<String> validCharacterIds) {
    return copyWith(
      locations: locations
          .map((item) => item.pruneCharacterBindings(validCharacterIds))
          .toList(growable: false),
    );
  }

  bool get hasAllSectionsSaved {
    return basicsSaved && charactersSaved && locationsSaved && storyEventsSaved;
  }

  bool get hasRequiredSectionsSaved {
    return basicsSaved && charactersSaved && locationsSaved;
  }

  List<String> validateForSubmit() {
    final errors = <String>[];

    if (!hasRequiredSectionsSaved) {
      final missing = <String>[
        if (!basicsSaved) 'Basics',
        if (!charactersSaved) 'Characters',
        if (!locationsSaved) 'Locations',
      ];
      errors.add('Please save ${missing.join(', ')} before creating.');
    }

    if (basics.originName.trim().isEmpty) {
      errors.add('Basics: Origin Name is required.');
    }
    if (basics.worldView.trim().isEmpty) {
      errors.add('Basics: World View is required.');
    }
    if (basics.coverImageUrl.trim().isEmpty) {
      errors.add('Basics: Cover Image is required.');
    }
    if (basics.metricJson.trim().isNotEmpty) {
      try {
        jsonDecode(basics.metricJson);
      } catch (_) {
        errors.add('Basics: Metric must be valid JSON.');
      }
    }

    for (int i = 0; i < characters.length; i++) {
      final item = characters[i];
      if (item.name.trim().isEmpty) {
        errors.add('Characters #${i + 1}: Name is required.');
      }
      if (item.identity.trim().isEmpty) {
        errors.add('Characters #${i + 1}: Identity is required.');
      }
      if (item.personality.trim().isEmpty) {
        errors.add('Characters #${i + 1}: Personality is required.');
      }
    }

    for (int i = 0; i < locations.length; i++) {
      final item = locations[i];
      if (item.name.trim().isEmpty) {
        errors.add('Locations #${i + 1}: Location Name is required.');
      }
    }

    return errors;
  }

  Map<String, dynamic> toCreateOriginPayload({String uid = 'anonymous'}) {
    final payload = <String, dynamic>{
      if (basics.originId.trim().isNotEmpty)
        'origin_id': basics.originId.trim(),
      'name': basics.originName.trim(),
      'world_view': basics.worldView.trim(),
      'world_setting': basics.worldLogic.trim(),
      'cover': basics.coverImageUrl.trim(),
      'character_list': characters
          .map(
            (item) => <String, dynamic>{
              if (item.charId.trim().isNotEmpty) 'char_id': item.charId.trim(),
              'name': item.name.trim(),
              'identity': item.identity.trim(),
              'tagline': item.personality.trim(),
              'description': item.bio.trim(),
              'goal': item.goal.trim(),
              'avatar': item.avatarUrl.trim(),
            },
          )
          .toList(growable: false),
      'location_list': _createLocationPayloadList(uid: uid),
      'event_list': storyEvents
          .map((item) => item.event.trim())
          .where((text) => text.isNotEmpty)
          .map((text) => <String, dynamic>{'content': text})
          .toList(growable: false),
    };

    if (basics.metricJson.trim().isNotEmpty) {
      try {
        payload['metric'] = jsonDecode(basics.metricJson);
      } catch (_) {
        payload['metric_json'] = basics.metricJson.trim();
      }
    }

    return payload;
  }

  List<Map<String, dynamic>> _createLocationPayloadList({required String uid}) {
    final originId = basics.originId.trim();
    final rootId = 'root_${originId.isEmpty ? 'origin' : originId}';
    final userLocations = locations
        .where((item) => item.name.trim().isNotEmpty)
        .toList(growable: false);
    final userLocationIds = userLocations
        .map((item) => item.locationId.trim())
        .where((id) => id.isNotEmpty && id != rootId)
        .toSet();

    final normalizedLocations = userLocations
        .where((item) => item.locationId.trim() != rootId)
        .map((item) {
          final parentId = item.parentLocationId.trim();
          return item.copyWith(
            parentLocationId:
                parentId.isEmpty || !userLocationIds.contains(parentId)
                ? rootId
                : parentId,
          );
        })
        .toList(growable: true);

    final childParentIds = normalizedLocations
        .map((item) => item.parentLocationId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    var generatedIndex = 0;
    for (final item in List<LocationDraft>.from(normalizedLocations)) {
      if (item.parentLocationId.trim() != rootId) continue;
      if (childParentIds.contains(item.locationId.trim())) continue;
      final timestamp = DateTime.now().toUtc().add(
        Duration(microseconds: generatedIndex++),
      );
      normalizedLocations.add(
        item.copyWith(
          locationId: createUidTimestampHashId(
            uid: uid,
            timestamp: timestamp,
            prefix: 'location',
          ),
          parentLocationId: item.locationId.trim(),
        ),
      );
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'location_id': rootId,
        'location_pid': '',
        'name': basics.originName.trim(),
        'image': basics.coverImageUrl.trim(),
        'description': basics.worldView.trim(),
        'initial_character_ids': const <String>[],
      },
      for (final item in normalizedLocations)
        <String, dynamic>{
          if (item.locationId.trim().isNotEmpty)
            'location_id': item.locationId.trim(),
          'location_pid': item.parentLocationId.trim(),
          'name': item.name.trim(),
          'image': item.imageUrl.trim(),
          'description': item.description.trim(),
          'initial_character_ids': item.initialCharacterIds,
        },
    ];
  }
}

class BasicsDraft {
  const BasicsDraft({
    this.originId = '',
    this.originName = '',
    this.worldView = '',
    this.worldLogic = '',
    this.metricJson = '',
    this.coverImageUrl = '',
  });

  final String originId;
  final String originName;
  final String worldView;
  final String worldLogic;
  final String metricJson;
  final String coverImageUrl;

  factory BasicsDraft.fromJson(Map<String, dynamic> json) {
    return BasicsDraft(
      originId: _asString(json['origin_id']),
      originName: _asString(json['origin_name']),
      worldView: _asString(json['world_view']),
      worldLogic: _asString(json['world_logic']),
      metricJson: _asString(json['metric_json']),
      coverImageUrl: _asString(json['cover_image_url']),
    );
  }

  BasicsDraft copyWith({
    String? originId,
    String? originName,
    String? worldView,
    String? worldLogic,
    String? metricJson,
    String? coverImageUrl,
  }) {
    return BasicsDraft(
      originId: originId ?? this.originId,
      originName: originName ?? this.originName,
      worldView: worldView ?? this.worldView,
      worldLogic: worldLogic ?? this.worldLogic,
      metricJson: metricJson ?? this.metricJson,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'origin_id': originId,
      'origin_name': originName,
      'world_view': worldView,
      'world_logic': worldLogic,
      'metric_json': metricJson,
      'cover_image_url': coverImageUrl,
    };
  }
}

class CharacterDraft {
  const CharacterDraft({
    this.charId = '',
    this.avatarUrl = '',
    this.name = '',
    this.identity = '',
    this.personality = '',
    this.bio = '',
    this.goal = '',
  });

  final String charId;
  final String avatarUrl;
  final String name;
  final String identity;
  final String personality;
  final String bio;
  final String goal;

  factory CharacterDraft.fromJson(Map<String, dynamic> json) {
    return CharacterDraft(
      charId: _asString(json['char_id']),
      avatarUrl: _asString(json['avatar_url']),
      name: _asString(json['name']),
      identity: _asString(json['identity']),
      personality: _asString(json['personality']),
      bio: _asString(json['bio']),
      goal: _asString(json['goal']),
    );
  }

  CharacterDraft copyWith({
    String? charId,
    String? avatarUrl,
    String? name,
    String? identity,
    String? personality,
    String? bio,
    String? goal,
  }) {
    return CharacterDraft(
      charId: charId ?? this.charId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      name: name ?? this.name,
      identity: identity ?? this.identity,
      personality: personality ?? this.personality,
      bio: bio ?? this.bio,
      goal: goal ?? this.goal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'char_id': charId,
      'avatar_url': avatarUrl,
      'name': name,
      'identity': identity,
      'personality': personality,
      'bio': bio,
      'goal': goal,
    };
  }
}

class LocationDraft {
  const LocationDraft({
    this.locationId = '',
    this.parentLocationId = '',
    this.imageUrl = '',
    this.name = '',
    this.description = '',
    this.initialCharacterIds = const <String>[],
  });

  final String locationId;
  final String parentLocationId;
  final String imageUrl;
  final String name;
  final String description;
  final List<String> initialCharacterIds;

  factory LocationDraft.fromJson(Map<String, dynamic> json) {
    return LocationDraft(
      locationId: _asString(json['location_id']),
      parentLocationId: _asString(json['location_pid']),
      imageUrl: _asString(json['image_url']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      initialCharacterIds: _asList(json['initial_character_ids'])
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  LocationDraft copyWith({
    String? locationId,
    String? parentLocationId,
    String? imageUrl,
    String? name,
    String? description,
    List<String>? initialCharacterIds,
  }) {
    return LocationDraft(
      locationId: locationId ?? this.locationId,
      parentLocationId: parentLocationId ?? this.parentLocationId,
      imageUrl: imageUrl ?? this.imageUrl,
      name: name ?? this.name,
      description: description ?? this.description,
      initialCharacterIds: initialCharacterIds ?? this.initialCharacterIds,
    );
  }

  LocationDraft pruneCharacterBindings(Set<String> validCharacterIds) {
    return copyWith(
      initialCharacterIds: initialCharacterIds
          .where(validCharacterIds.contains)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'location_pid': parentLocationId,
      'image_url': imageUrl,
      'name': name,
      'description': description,
      'initial_character_ids': initialCharacterIds,
    };
  }
}

class StoryEventDraft {
  const StoryEventDraft({this.event = ''});

  final String event;

  factory StoryEventDraft.fromJson(Map<String, dynamic> json) {
    return StoryEventDraft(event: _asString(json['event']));
  }

  StoryEventDraft copyWith({String? event}) {
    return StoryEventDraft(event: event ?? this.event);
  }

  Map<String, dynamic> toJson() {
    return {'event': event};
  }
}

List<dynamic> _asList(Object? raw) => raw is List ? raw : const <dynamic>[];

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry('$k', v));
  return const <String, dynamic>{};
}

String _asString(Object? raw) => raw?.toString() ?? '';

bool _asBool(Object? raw) => raw == true;
