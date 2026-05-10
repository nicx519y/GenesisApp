import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CreateOriginDraftStore {
  static const String _storageKey = 'create_origin_draft_v1';

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

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
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

  bool get hasAllSectionsSaved {
    return basicsSaved && charactersSaved && locationsSaved && storyEventsSaved;
  }

  List<String> validateForSubmit() {
    final errors = <String>[];

    if (!hasAllSectionsSaved) {
      errors.add('Please save all sections before creating.');
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

  Map<String, dynamic> toCreateOriginPayload() {
    final payload = <String, dynamic>{
      'title': basics.originName.trim(),
      'description': basics.worldView.trim(),
      'world_view': basics.worldView.trim(),
      'world_setting': basics.worldLogic.trim(),
      'cover_image_url': basics.coverImageUrl.trim(),
      'npcs': characters
          .map(
            (item) => <String, dynamic>{
              'name': item.name.trim(),
              'identity': item.identity.trim(),
              'tagline': item.personality.trim(),
              'intro': item.bio.trim(),
              'goal': item.goal.trim(),
              'avatar_url': item.avatarUrl.trim(),
              'avatar': item.avatarUrl.trim(),
            },
          )
          .toList(growable: false),
      'locations': locations
          .map(
            (item) => <String, dynamic>{
              'name': item.name.trim(),
              'image_url': item.imageUrl.trim(),
              'description': item.description.trim(),
              'initial_character_indexes': item.initialCharacterIndexes,
            },
          )
          .toList(growable: false),
      'events': storyEvents
          .map((item) => item.event.trim())
          .where((text) => text.isNotEmpty)
          .toList(growable: false),
      'launch_world_name': basics.originName.trim(),
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
}

class BasicsDraft {
  const BasicsDraft({
    this.originName = '',
    this.worldView = '',
    this.worldLogic = '',
    this.metricJson = '',
    this.coverImageUrl = '',
  });

  final String originName;
  final String worldView;
  final String worldLogic;
  final String metricJson;
  final String coverImageUrl;

  factory BasicsDraft.fromJson(Map<String, dynamic> json) {
    return BasicsDraft(
      originName: _asString(json['origin_name']),
      worldView: _asString(json['world_view']),
      worldLogic: _asString(json['world_logic']),
      metricJson: _asString(json['metric_json']),
      coverImageUrl: _asString(json['cover_image_url']),
    );
  }

  BasicsDraft copyWith({
    String? originName,
    String? worldView,
    String? worldLogic,
    String? metricJson,
    String? coverImageUrl,
  }) {
    return BasicsDraft(
      originName: originName ?? this.originName,
      worldView: worldView ?? this.worldView,
      worldLogic: worldLogic ?? this.worldLogic,
      metricJson: metricJson ?? this.metricJson,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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

  factory CharacterDraft.fromJson(Map<String, dynamic> json) {
    return CharacterDraft(
      avatarUrl: _asString(json['avatar_url']),
      name: _asString(json['name']),
      identity: _asString(json['identity']),
      personality: _asString(json['personality']),
      bio: _asString(json['bio']),
      goal: _asString(json['goal']),
    );
  }

  CharacterDraft copyWith({
    String? avatarUrl,
    String? name,
    String? identity,
    String? personality,
    String? bio,
    String? goal,
  }) {
    return CharacterDraft(
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
    this.imageUrl = '',
    this.name = '',
    this.description = '',
    this.initialCharacterIndexes = const <int>[],
  });

  final String imageUrl;
  final String name;
  final String description;
  final List<int> initialCharacterIndexes;

  factory LocationDraft.fromJson(Map<String, dynamic> json) {
    return LocationDraft(
      imageUrl: _asString(json['image_url']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      initialCharacterIndexes: _asList(
        json['initial_character_indexes'],
      ).map((item) => int.tryParse('$item') ?? 0).toList(growable: false),
    );
  }

  LocationDraft copyWith({
    String? imageUrl,
    String? name,
    String? description,
    List<int>? initialCharacterIndexes,
  }) {
    return LocationDraft(
      imageUrl: imageUrl ?? this.imageUrl,
      name: name ?? this.name,
      description: description ?? this.description,
      initialCharacterIndexes:
          initialCharacterIndexes ?? this.initialCharacterIndexes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image_url': imageUrl,
      'name': name,
      'description': description,
      'initial_character_indexes': initialCharacterIndexes,
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
