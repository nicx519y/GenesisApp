import 'dart:convert';

import '../../network/json_utils.dart';
import '../../utils/genesis_ugc_text.dart';
import '../create/create_origin_draft_store.dart';

abstract class OriginDraftRepository {
  const OriginDraftRepository();

  bool get supportsTempDrafts;

  Future<CreateOriginDraft> loadDraft();

  Future<CreateOriginDraft> loadSummaryDraft();

  Future<List<CharacterDraft>> loadSavedCharacters();

  Future<void> saveTempDraft(CreateOriginDraft draft);

  Future<void> saveFinalDraft(CreateOriginDraft draft);

  bool hasSubmitChanges(CreateOriginDraft draft);
}

class CreateOriginDraftRepository extends OriginDraftRepository {
  const CreateOriginDraftRepository();

  @override
  bool get supportsTempDrafts => true;

  @override
  Future<CreateOriginDraft> loadDraft() => CreateOriginDraftStore.load();

  @override
  Future<CreateOriginDraft> loadSummaryDraft() =>
      CreateOriginDraftStore.loadFinal();

  @override
  Future<List<CharacterDraft>> loadSavedCharacters() =>
      CreateOriginDraftStore.loadFinalCharacters();

  @override
  Future<void> saveTempDraft(CreateOriginDraft draft) {
    return CreateOriginDraftStore.saveTemp(draft, syncedToFinal: false);
  }

  @override
  Future<void> saveFinalDraft(CreateOriginDraft draft) {
    return CreateOriginDraftStore.saveFinal(draft);
  }

  @override
  bool hasSubmitChanges(CreateOriginDraft draft) => true;
}

class MemoryOriginDraftRepository extends OriginDraftRepository {
  MemoryOriginDraftRepository({required CreateOriginDraft initialDraft})
    : _originalDraft = initialDraft.normalized(),
      _draft = initialDraft.normalized();

  CreateOriginDraft _originalDraft;
  CreateOriginDraft _draft;

  @override
  bool get supportsTempDrafts => false;

  @override
  Future<CreateOriginDraft> loadDraft() async => _draft;

  @override
  Future<CreateOriginDraft> loadSummaryDraft() async => _draft;

  @override
  Future<List<CharacterDraft>> loadSavedCharacters() async {
    if (!_draft.charactersSaved) return const <CharacterDraft>[];
    return _draft.characters
        .where(
          (item) =>
              item.charId.trim().isNotEmpty && item.name.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveTempDraft(CreateOriginDraft draft) async {
    _draft = draft.normalized();
  }

  @override
  Future<void> saveFinalDraft(CreateOriginDraft draft) async {
    _draft = draft.normalized();
  }

  @override
  bool hasSubmitChanges(CreateOriginDraft draft) {
    return !originDraftContentEquals(_originalDraft, draft.normalized());
  }

  List<String> deletedCharacterIds(CreateOriginDraft draft) {
    return _deletedIds(
      _originalDraft.characters.map((item) => item.charId),
      draft.normalized().characters.map((item) => item.charId),
    );
  }

  List<String> deletedLocationIds(CreateOriginDraft draft) {
    return _deletedIds(
      _originalDraft.locations.map((item) => item.locationId),
      draft.normalized().locations.map((item) => item.locationId),
    );
  }

  void markCurrentAsOriginal() {
    _originalDraft = _draft.normalized();
  }

  bool basicsChanged(CreateOriginDraft draft) {
    return jsonEncode(_originalDraft.basics.toJson()) !=
        jsonEncode(draft.normalized().basics.toJson());
  }

  bool charactersChanged(CreateOriginDraft draft) {
    return jsonEncode(
          _originalDraft.characters.map((item) => item.toJson()).toList(),
        ) !=
        jsonEncode(
          draft.normalized().characters.map((item) => item.toJson()).toList(),
        );
  }

  bool locationsChanged(CreateOriginDraft draft) {
    return jsonEncode(
          _originalDraft.locations.map((item) => item.toJson()).toList(),
        ) !=
        jsonEncode(
          draft.normalized().locations.map((item) => item.toJson()).toList(),
        );
  }

  bool storyEventsChanged(CreateOriginDraft draft) {
    return jsonEncode(
          _originalDraft.storyEvents.map((item) => item.toJson()).toList(),
        ) !=
        jsonEncode(
          draft.normalized().storyEvents.map((item) => item.toJson()).toList(),
        );
  }
}

List<String> _deletedIds(
  Iterable<String> originalIds,
  Iterable<String> nextIds,
) {
  final next = nextIds
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
  return originalIds
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && !next.contains(item))
      .toList(growable: false);
}

bool originDraftContentEquals(CreateOriginDraft a, CreateOriginDraft b) {
  return jsonEncode(_contentJson(a.normalized())) ==
      jsonEncode(_contentJson(b.normalized()));
}

Map<String, dynamic> _contentJson(CreateOriginDraft draft) {
  return {
    'basics': draft.basics.toJson(),
    'characters': draft.characters.map((item) => item.toJson()).toList(),
    'locations': draft.locations.map((item) => item.toJson()).toList(),
    'story_events': draft.storyEvents.map((item) => item.toJson()).toList(),
  };
}

CreateOriginDraft originDraftFromV1Detail(Map<String, dynamic> raw) {
  final origin = raw['origin'] is Map
      ? asJsonMap(raw['origin'])
      : raw['info'] is Map
      ? asJsonMap(raw['info'])
      : raw;
  final originId = asString(
    origin['oid'],
    fallback: asString(origin['origin_id']),
  );
  final metric = raw['metric'] ?? origin['metric'];

  final characterRaw = raw['character_list'] ?? raw['characters'];
  final characters = characterRaw is List
      ? asJsonList(characterRaw)
            .map((item) => _characterDraftFromV1(asJsonMap(item)))
            .toList(growable: false)
      : const <CharacterDraft>[];

  final characterLocationIds = <String, List<String>>{};
  if (characterRaw is List) {
    for (final item in asJsonList(characterRaw)) {
      final map = asJsonMap(item);
      final charId = asString(
        map['character_id'],
        fallback: asString(map['char_id']),
      ).trim();
      final locationId = asString(
        map['location_id'],
        fallback: asString(map['initial_location_id']),
      ).trim();
      if (charId.isEmpty || locationId.isEmpty) continue;
      characterLocationIds
          .putIfAbsent(locationId, () => <String>[])
          .add(charId);
    }
  }

  final locationRaw = raw['location_list'] ?? raw['locations'];
  final rootLocationId = 'root_${originId.isEmpty ? 'origin' : originId}';
  final locations = locationRaw is List
      ? asJsonList(locationRaw)
            .map((item) => asJsonMap(item))
            .where(
              (item) => asString(item['location_id']).trim() != rootLocationId,
            )
            .map(
              (item) => _locationDraftFromV1(
                item,
                characterLocationIds: characterLocationIds,
              ),
            )
            .toList(growable: false)
      : const <LocationDraft>[];

  final eventRaw =
      raw['event_list'] ?? raw['events'] ?? origin['events'] ?? raw['ticks'];
  final events = eventRaw is List
      ? asJsonList(eventRaw)
            .map(_storyEventDraftFromV1)
            .where((item) => item.event.trim().isNotEmpty)
            .toList(growable: false)
      : const <StoryEventDraft>[];

  return CreateOriginDraft(
    basics: BasicsDraft(
      originId: originId,
      originVersion: asString(origin['origin_version']),
      originName: decodeGenesisUgcTextForDisplay(
        asString(
          origin['name'],
          fallback: asString(origin['origin_name'], fallback: originId),
        ),
      ),
      worldView: decodeGenesisUgcTextForDisplay(
        asString(
          origin['world_view'],
          fallback: asString(
            origin['brief'],
            fallback: asString(origin['setting']),
          ),
        ),
      ),
      worldLogic: decodeGenesisUgcTextForDisplay(
        asString(
          origin['world_setting'],
          fallback: asString(
            origin['setting'],
            fallback: asString(
              origin['display_subtitle'],
              fallback: asString(origin['brief']),
            ),
          ),
        ),
      ),
      metricJson: metric is Map && metric.isNotEmpty
          ? jsonEncode(decodeGenesisUgcValueForDisplay(asJsonMap(metric)))
          : '',
      startedAt: asString(
        origin['started_at'],
        fallback: asString(origin['start_time']),
      ),
      tickDurationTime: asString(origin['tick_duration_time']),
      tickDurationDays: _nullableInt(origin['tick_duration_days']),
      coverImageUrl: asImageUrl(origin['cover'], fallback: origin['map_url']),
    ),
    characters: characters.isEmpty
        ? const <CharacterDraft>[CharacterDraft()]
        : characters,
    locations: locations.isEmpty
        ? const <LocationDraft>[LocationDraft()]
        : locations,
    storyEvents: events.isEmpty
        ? const <StoryEventDraft>[StoryEventDraft()]
        : events,
    basicsSaved: true,
    charactersSaved: true,
    locationsSaved: true,
    storyEventsSaved: true,
  ).normalized();
}

int? _nullableInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString().trim());
}

CharacterDraft _characterDraftFromV1(Map<String, dynamic> raw) {
  return CharacterDraft(
    charId: asString(raw['character_id'], fallback: asString(raw['char_id'])),
    avatarUrl: asImageUrl(raw['avatar']),
    name: decodeGenesisUgcTextForDisplay(asString(raw['name'])),
    identity: decodeGenesisUgcTextForDisplay(asString(raw['identity'])),
    personality: decodeGenesisUgcTextForDisplay(
      asString(
        raw['personality'],
        fallback: asString(raw['tagline'], fallback: asString(raw['brief'])),
      ),
    ),
    bio: decodeGenesisUgcTextForDisplay(
      asString(
        raw['bio'],
        fallback: asString(
          raw['description'],
          fallback: asString(raw['brief'], fallback: asString(raw['tagline'])),
        ),
      ),
    ),
    goal: decodeGenesisUgcTextForDisplay(asString(raw['goal'])),
  );
}

LocationDraft _locationDraftFromV1(
  Map<String, dynamic> raw, {
  required Map<String, List<String>> characterLocationIds,
}) {
  final locationId = asString(raw['location_id']).trim();
  final initialCharacterIdsRaw = raw['initial_character_ids'];
  final initialCharacterIds = initialCharacterIdsRaw is List
      ? asJsonList(initialCharacterIdsRaw)
            .map((item) => '$item'.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : characterLocationIds[locationId] ?? const <String>[];

  return LocationDraft(
    locationId: locationId,
    imageUrl: asImageUrl(raw['image'], fallback: raw['icon']),
    name: decodeGenesisUgcTextForDisplay(
      asString(raw['name'], fallback: asString(raw['location_name'])),
    ),
    description: decodeGenesisUgcTextForDisplay(
      asString(
        raw['description'],
        fallback: asString(
          raw['location_description'],
          fallback: asString(raw['location_summary']),
        ),
      ),
    ),
    initialCharacterIds: initialCharacterIds,
  );
}

StoryEventDraft _storyEventDraftFromV1(Object? raw) {
  if (raw is! Map) {
    return StoryEventDraft(
      event: decodeGenesisUgcTextForDisplay(asString(raw)),
    );
  }
  final map = asJsonMap(raw);
  final tickResult = map['tick_result'] is Map
      ? asJsonMap(map['tick_result'])
      : const <String, dynamic>{};
  return StoryEventDraft(
    event: decodeGenesisUgcTextForDisplay(
      asString(
        map['content'],
        fallback: asString(
          map['event'],
          fallback: asString(
            map['text'],
            fallback: asString(
              map['summary'],
              fallback: asString(
                map['narrator'],
                fallback: asString(tickResult['narrator']),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
