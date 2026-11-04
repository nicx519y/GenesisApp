import 'world_memory_models.dart';

/// Design examples, reachable only through kDebugMode previews. Hosts read them
/// via world_memory_debug_preview.dart; never import this file into stores or
/// the world_memory.dart public barrel.
abstract final class WorldMemoryPreviewData {
  static const _adrian = WorldMemoryPerson(
    id: 'you',
    name: 'Adrian',
    avatarAsset: 'assets/world_memory_preview/sq_char_2.jpg',
  );
  static const _vivienne = WorldMemoryPerson(
    id: 'vivienne',
    name: 'Vivienne Ashford',
    avatarAsset: 'assets/world_memory_preview/sq_char_1.jpg',
  );
  static const _sebastian = WorldMemoryPerson(
    id: 'sebastian',
    name: 'Sebastian Wilder',
    avatarAsset: 'assets/world_memory_preview/sq_char_3.jpg',
  );
  static const _dorian = WorldMemoryPerson(
    id: 'dorian',
    name: 'Dorian Ash',
    avatarAsset: 'assets/world_memory_preview/sq_char_4.jpg',
  );
  static const _noah = WorldMemoryPerson(
    id: 'noah',
    name: 'Noah Reed',
    avatarAsset: 'assets/world_memory_preview/sq_char_5.jpg',
  );

  static WorldMemorySnapshot live() => const WorldMemorySnapshot(
    hasStoryMemory: true,
    cast: _cast,
    events: _events,
    relations: _relations,
    summaryTicks: [
      WorldMemorySummaryTick(
        tickNo: 1,
        bodies: [
          'The Ashford engagement gala opened with Vivienne under every eye. '
              'Adrian claimed her first dance before her suitors could, and when '
              'Sebastian cut in, she chose to finish it with Adrian.',
        ],
      ),
      WorldMemorySummaryTick(
        tickNo: 2,
        bodies: [
          'Late in the evening Dorian Ash arrived uninvited, claiming Ashford '
              'blood. Sebastian wanted him gone, but Vivienne let him stay until '
              'the claim is checked.',
        ],
      ),
      WorldMemorySummaryTick(
        tickNo: 3,
        bodies: [
          'On the terrace, Vivienne admitted to Adrian that the merger frightens '
              'her more than any suitor, and the two agreed to be honest with each '
              'other.',
        ],
      ),
      WorldMemorySummaryTick(
        tickNo: 4,
        bodies: [
          'Sebastian has told Adrian he found a merger document Adrian must see.',
          'Vivienne has asked Adrian to meet her in the library, alone. She is '
              'waiting there now.',
        ],
      ),
    ],
  );

  static WorldMemorySnapshot fresh() => WorldMemorySnapshot(
    cast: [
      for (final character in _cast)
        WorldMemoryCharacter(
          person: character.person,
          identity: character.identity,
          isPlayer: character.isPlayer,
          fields: Map.unmodifiable({
            for (final entry in character.fields.entries)
              if (const {
                WorldMemoryField.age,
                WorldMemoryField.gender,
                WorldMemoryField.orientation,
                WorldMemoryField.appearance,
                WorldMemoryField.personality,
                WorldMemoryField.background,
              }.contains(entry.key))
                entry.key: WorldMemoryValue(entry.value.text),
          }),
        ),
    ],
  );

  static WorldMemorySnapshot departures() => live().copyWith(
    cast: [
      for (final character in _cast)
        if (character.person.id == 'noah' || character.person.id == 'dorian')
          WorldMemoryCharacter(
            person: character.person,
            identity: character.identity,
            fields: character.fields,
            updated: true,
            status: character.person.id == 'noah'
                ? WorldMemoryCharacterStatus.departed
                : WorldMemoryCharacterStatus.dead,
            now: character.person.id == 'noah'
                ? 'Left the estate for the city before dawn'
                : 'Last seen on the terrace, waiting for Adrian',
          )
        else
          character,
    ],
  );

  static const _cast = [
    WorldMemoryCharacter(
      person: _adrian,
      isPlayer: true,
      updated: true,
      identity: 'Heir to a rival empire',
      now: 'Agreed to meet Vivienne alone in the library',
      fields: {
        WorldMemoryField.age: WorldMemoryValue('27'),
        WorldMemoryField.gender: WorldMemoryValue('Male'),
        WorldMemoryField.appearance: WorldMemoryValue(
          'Black hair, sharp dark suit, loosened tie',
        ),
        WorldMemoryField.personality: WorldMemoryValue(
          'Cold, polished, efficient',
        ),
        WorldMemoryField.likesDislikes: WorldMemoryValue(
          'Late-night chess; dislikes champagne',
          updated: true,
        ),
        WorldMemoryField.arc: WorldMemoryValue(
          'From calculated suitor to genuinely curious',
        ),
        WorldMemoryField.definingMoment: WorldMemoryValue(
          'Asked Vivienne to dance before anyone else',
        ),
      },
    ),
    WorldMemoryCharacter(
      person: _vivienne,
      updated: true,
      identity: 'Sole heir to the Ashford estate',
      now: 'Waiting in the library with something to show him',
      fields: {
        WorldMemoryField.age: WorldMemoryValue('24'),
        WorldMemoryField.gender: WorldMemoryValue('Female'),
        WorldMemoryField.appearance: WorldMemoryValue(
          'Long dark waves, cream knit, an easy smile',
        ),
        WorldMemoryField.personality: WorldMemoryValue(
          'Warm on the surface, guarded underneath',
        ),
        WorldMemoryField.background: WorldMemoryValue(
          'Raised to marry for the family name; lost her mother young.',
        ),
        WorldMemoryField.likesDislikes: WorldMemoryValue(
          'Old jazz records, night walks in the gardens',
        ),
        WorldMemoryField.boundaries: WorldMemoryValue(
          'Being treated as part of the merger',
        ),
        WorldMemoryField.arc: WorldMemoryValue(
          'Testing who wants her, not the estate',
        ),
        WorldMemoryField.definingMoment: WorldMemoryValue(
          'Left the ballroom mid-toast to find Adrian',
        ),
      },
    ),
    WorldMemoryCharacter(
      person: _sebastian,
      identity: 'Ashford family friend and banker',
      now: 'Holding a merger document he wants Adrian to see',
      fields: {
        WorldMemoryField.age: WorldMemoryValue('28'),
        WorldMemoryField.gender: WorldMemoryValue('Male'),
        WorldMemoryField.appearance: WorldMemoryValue(
          'Neat black hair, white shirt, restless hands',
        ),
        WorldMemoryField.personality: WorldMemoryValue(
          'Charming and watchful; hides worry with jokes',
        ),
        WorldMemoryField.background: WorldMemoryValue(
          'Grew up beside Vivienne as the families’ favourite son.',
        ),
        WorldMemoryField.likesDislikes: WorldMemoryValue('Sailing'),
        WorldMemoryField.definingMoment: WorldMemoryValue(
          'Cut in on Vivienne’s first dance',
        ),
      },
    ),
    WorldMemoryCharacter(
      person: _dorian,
      identity: 'Uninvited guest claiming Ashford blood',
      now: 'Waiting on the terrace for Adrian',
      fields: {
        WorldMemoryField.gender: WorldMemoryValue('Male'),
        WorldMemoryField.appearance: WorldMemoryValue(
          'Black sweater, silver chain, a fresh scar',
        ),
        WorldMemoryField.personality: WorldMemoryValue(
          'Reckless, magnetic, keeps secrets',
        ),
        WorldMemoryField.boundaries: WorldMemoryValue(
          'Questions about his father',
        ),
        WorldMemoryField.definingMoment: WorldMemoryValue(
          'Walked into the gala without an invitation',
        ),
      },
    ),
    WorldMemoryCharacter(
      person: _noah,
      identity: 'Gardener’s son turned architect',
      now: 'Avoiding the party in the gardens',
      fields: {
        WorldMemoryField.age: WorldMemoryValue('26'),
        WorldMemoryField.gender: WorldMemoryValue('Male'),
        WorldMemoryField.appearance: WorldMemoryValue(
          'Fair hair tied back, worn linen jacket',
        ),
        WorldMemoryField.personality: WorldMemoryValue('Quiet, steady, proud'),
        WorldMemoryField.background: WorldMemoryValue(
          'Spent every childhood summer in the Ashford gardens.',
        ),
        WorldMemoryField.likesDislikes: WorldMemoryValue(
          'Sketching, old roses',
        ),
      },
    ),
  ];

  static const _vivienneShort = WorldMemoryPerson(
    id: 'vivienne',
    name: 'Vivienne',
    avatarAsset: 'assets/world_memory_preview/sq_char_1.jpg',
  );
  static const _sebastianShort = WorldMemoryPerson(
    id: 'sebastian',
    name: 'Sebastian',
    avatarAsset: 'assets/world_memory_preview/sq_char_3.jpg',
  );
  static const _dorianShort = WorldMemoryPerson(
    id: 'dorian',
    name: 'Dorian',
    avatarAsset: 'assets/world_memory_preview/sq_char_4.jpg',
  );
  static const _noahShort = WorldMemoryPerson(
    id: 'noah',
    name: 'Noah',
    avatarAsset: 'assets/world_memory_preview/sq_char_5.jpg',
  );

  static const _events = [
    WorldMemoryEvent(
      id: 'library',
      timeLabel: 'Day 2, 01:00',
      order: 5,
      change: WorldMemoryChange.added,
      participants: [_vivienneShort, _adrian],
      body:
          'Vivienne privately asked Adrian to meet her in the library, alone. He agreed; she is waiting there now.',
    ),
    WorldMemoryEvent(
      id: 'document',
      timeLabel: 'Day 2, 00:45',
      order: 4,
      change: WorldMemoryChange.updated,
      participants: [_sebastianShort, _adrian],
      body:
          'Sebastian messaged Adrian that he found a merger document Adrian must see. They have not met yet.',
    ),
    WorldMemoryEvent(
      id: 'terrace',
      timeLabel: 'Day 1, 23:40 → Day 2, 00:30',
      order: 3,
      participants: [_vivienneShort, _adrian],
      body:
          'Vivienne slipped out to the terrace and Adrian followed. She admitted she fears the merger more than any suitor; they agreed to be honest.',
    ),
    WorldMemoryEvent(
      id: 'arrival',
      timeLabel: 'Day 1, 23:10',
      order: 2,
      participants: [_dorianShort, _sebastianShort, _vivienneShort],
      body:
          'Dorian arrived uninvited, claiming Ashford blood. Sebastian tried to have him removed; Vivienne let him stay until it is checked.',
    ),
    WorldMemoryEvent(
      id: 'dance',
      timeLabel: 'Day 1, 20:00 → 22:30',
      order: 1,
      participants: [_vivienneShort, _adrian, _sebastianShort],
      body:
          'At the gala, Adrian asked Vivienne to dance before her suitors could. Sebastian cut in; she chose to finish the dance with Adrian.',
    ),
  ];

  static const _relations = [
    WorldMemoryRelation(
      id: 'vivienne-you',
      group: WorldMemoryRelationGroup.towardPlayer,
      from: _vivienneShort,
      to: _adrian,
      updated: true,
      body:
          'Vivienne trusts Adrian enough to meet alone, but keeps testing whether he wants her or the estate.',
    ),
    WorldMemoryRelation(
      id: 'sebastian-you',
      group: WorldMemoryRelationGroup.towardPlayer,
      from: _sebastianShort,
      to: _adrian,
      body:
          'Sebastian is courteous to Adrian but suspects he is courting Vivienne only to close the deal.',
    ),
    WorldMemoryRelation(
      id: 'dorian-you',
      group: WorldMemoryRelationGroup.towardPlayer,
      from: _dorianShort,
      to: _adrian,
      body:
          'Dorian sees Adrian as a useful rival: someone to trade secrets with, never to trust.',
    ),
    WorldMemoryRelation(
      id: 'vivienne-sebastian',
      group: WorldMemoryRelationGroup.betweenCharacters,
      from: _vivienneShort,
      to: _sebastianShort,
      body:
          'Childhood friends. Sebastian is protective of Vivienne; she leans on him but senses he wants more.',
    ),
    WorldMemoryRelation(
      id: 'sebastian-dorian',
      group: WorldMemoryRelationGroup.betweenCharacters,
      from: _sebastianShort,
      to: _dorianShort,
      body:
          'Open hostility. Sebastian calls Dorian a fraud; Dorian enjoys provoking him in public.',
    ),
    WorldMemoryRelation(
      id: 'vivienne-noah',
      group: WorldMemoryRelationGroup.betweenCharacters,
      from: _vivienneShort,
      to: _noahShort,
      body:
          'An easy closeness from summers in the gardens that neither of them has put a name to.',
    ),
  ];
}
