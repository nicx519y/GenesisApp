/// Presentation data only. The host maps verified data into these types;
/// constructors never fetch, infer, or populate example story content.
enum WorldMemorySection { recap, cast, bonds }

enum WorldMemoryChange { none, added, updated }

enum WorldMemoryCharacterStatus { active, departed, dead }

enum WorldMemoryRelationGroup { towardPlayer, betweenCharacters }

enum WorldMemoryField {
  age,
  gender,
  orientation,
  appearance,
  personality,
  background,
  likesDislikes,
  boundaries,
  goodToKnow,
  arc,
  definingMoment,
}

class WorldMemoryValue {
  const WorldMemoryValue(this.text, {this.updated = false});
  final String text;
  final bool updated;
}

class WorldMemoryPerson {
  const WorldMemoryPerson({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.avatarAsset = '',
  });
  final String id;
  final String name;
  final String avatarUrl;

  /// Optional registered local asset. Kept distinct from network identity.
  final String avatarAsset;
}

class WorldMemoryEvent {
  const WorldMemoryEvent({
    required this.id,
    required this.timeLabel,
    required this.order,
    required this.body,
    this.participants = const [],
    this.change = WorldMemoryChange.none,
  });
  final String id;
  final String timeLabel;

  /// Chronology supplied by the adapter; never parsed from [timeLabel].
  final num order;
  final String body;
  final List<WorldMemoryPerson> participants;
  final WorldMemoryChange change;
}

class WorldMemoryCharacter {
  const WorldMemoryCharacter({
    required this.person,
    this.identity = '',
    this.isPlayer = false,
    this.status = WorldMemoryCharacterStatus.active,
    this.now = '',
    this.towardYou = '',
    this.fields = const {},
    this.updated = false,
  });
  final WorldMemoryPerson person;
  final String identity;
  final bool isPlayer;
  final WorldMemoryCharacterStatus status;
  final String now;
  final String towardYou;
  final Map<WorldMemoryField, WorldMemoryValue> fields;
  final bool updated;

  bool get hasLeft => status != WorldMemoryCharacterStatus.active;
}

class WorldMemoryRelation {
  const WorldMemoryRelation({
    required this.id,
    required this.group,
    required this.from,
    required this.to,
    required this.body,
    this.updated = false,
  });
  final String id;
  final WorldMemoryRelationGroup group;
  final WorldMemoryPerson from;
  final WorldMemoryPerson to;
  final String body;
  final bool updated;
}

class WorldMemorySummaryTick {
  const WorldMemorySummaryTick({required this.tickNo, required this.bodies});
  final int tickNo;
  final List<String> bodies;
}

/// Lists/maps are read-only presentation inputs. Callers should replace a
/// snapshot when data changes; the view never mutates its supplied collections.
class WorldMemorySnapshot {
  const WorldMemorySnapshot({
    this.events = const [],
    this.cast = const [],
    this.relations = const [],
    this.summaryTicks = const [],
    this.hasStoryMemory = false,
  });
  const WorldMemorySnapshot.empty()
    : events = const [],
      cast = const [],
      relations = const [],
      summaryTicks = const [],
      hasStoryMemory = false;

  final List<WorldMemoryEvent> events;
  final List<WorldMemoryCharacter> cast;
  final List<WorldMemoryRelation> relations;

  /// Oldest first, as the recap reads.
  final List<WorldMemorySummaryTick> summaryTicks;
  final bool hasStoryMemory;

  WorldMemorySnapshot copyWith({
    List<WorldMemorySummaryTick>? summaryTicks,
    List<WorldMemoryEvent>? events,
    List<WorldMemoryCharacter>? cast,
    List<WorldMemoryRelation>? relations,
    bool? hasStoryMemory,
  }) => WorldMemorySnapshot(
    events: events ?? this.events,
    cast: cast ?? this.cast,
    relations: relations ?? this.relations,
    summaryTicks: summaryTicks ?? this.summaryTicks,
    hasStoryMemory: hasStoryMemory ?? this.hasStoryMemory,
  );
}
