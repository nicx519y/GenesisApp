import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';

void main() {
  test('origin payload preserves UGC backslashes and normalizes newlines', () {
    const draft = CreateOriginDraft(
      basics: BasicsDraft(
        originName: '  World name  ',
        worldView: 'First\r\nSecond',
        worldLogic: r'Literal \n and \u300c',
        coverImageUrl: ' https://cdn.example.com/cover.png ',
      ),
      characters: <CharacterDraft>[
        CharacterDraft(
          charId: ' char-1 ',
          name: '  Character  ',
          identity: r'Identity \n',
          personality: '*calm*',
          bio: 'Bio\rline',
          goal: r'Keep \u300c literal',
          avatarUrl: ' https://cdn.example.com/avatar.png ',
          isRecommend: 1,
        ),
      ],
      locations: <LocationDraft>[
        LocationDraft(
          locationId: ' loc-1 ',
          name: '  Location  ',
          description: 'Top\r\nBottom',
        ),
      ],
      storyEvents: <StoryEventDraft>[
        StoryEventDraft(event: '  Event\r\ncontinues  '),
      ],
      basicsSaved: true,
      charactersSaved: true,
      locationsSaved: true,
      storyEventsSaved: true,
    );

    final payload = draft.toCreateOriginPayload();
    expect(payload['name'], '  World name  ');
    expect(payload['world_view'], 'First\nSecond');
    expect(payload['world_setting'], r'Literal \n and \u300c');

    final character = (payload['character_list'] as List).single as Map;
    expect(character['char_id'], 'char-1');
    expect(character['name'], '  Character  ');
    expect(character['identity'], r'Identity \n');
    expect(character['description'], 'Bio\nline');
    expect(character['goal'], r'Keep \u300c literal');
    expect(character['is_recommend'], 1);

    final location = (payload['location_list'] as List).single as Map;
    expect(location['location_id'], 'loc-1');
    expect(location['name'], '  Location  ');
    expect(location['description'], 'Top\nBottom');

    final event = (payload['event_list'] as List).single as Map;
    expect(event['content'], '  Event\ncontinues  ');
  });

  test('complete saved opening maps to ordered initial dialogue', () {
    final draft = CreateOriginDraft.empty().copyWith(
      opening: const OpeningDraft(
        locationId: ' location-raw ',
        dialogue: <OpeningDialogueDraft>[
          OpeningDialogueDraft(
            type: OpeningDialogueDraft.narratorType,
            content:
                r'First \n'
                '\r\nSecond',
          ),
          OpeningDialogueDraft(
            type: OpeningDialogueDraft.imageType,
            content: ' https://cdn.example.com/opening.png ',
          ),
          OpeningDialogueDraft(
            type: OpeningDialogueDraft.characterType,
            characterId: ' character-raw ',
            content: 'Hello\rworld',
          ),
        ],
      ),
      openingSaved: true,
    );

    final payload = draft.toCreateOriginPayload();
    final opening = payload['init_location_group'] as Map;
    expect(opening['location_id'], 'location-raw');

    final dialogue = opening['initial_dialogue'] as List;
    expect(dialogue, <Map<String, dynamic>>[
      <String, dynamic>{
        'char_id': 'nar',
        'content':
            r'First \n'
            '\nSecond',
      },
      <String, dynamic>{
        'char_id': 'nar_pic',
        'content': 'https://cdn.example.com/opening.png',
      },
      <String, dynamic>{'char_id': 'character-raw', 'content': 'Hello\nworld'},
    ]);
  });

  test('location payload preserves flat hierarchy links and order', () {
    final draft = CreateOriginDraft.empty().copyWith(
      locations: const <LocationDraft>[
        LocationDraft(locationId: 'scene', level: 1, name: 'Scene'),
        LocationDraft(
          locationId: 'area',
          parentLocationId: 'scene',
          level: 2,
          name: 'Area',
        ),
        LocationDraft(
          locationId: 'room',
          parentLocationId: 'area',
          level: 3,
          name: 'Room',
        ),
      ],
      locationsSaved: true,
    );

    final locations =
        draft.toCreateOriginPayload()['location_list'] as List<dynamic>;
    expect(
      locations
          .map(
            (item) => (
              id: (item as Map<String, dynamic>)['location_id'],
              pid: item['location_pid'],
              level: item['level'],
            ),
          )
          .toList(),
      <({String id, String? pid, int level})>[
        (id: 'scene', pid: null, level: 1),
        (id: 'area', pid: 'scene', level: 2),
        (id: 'room', pid: 'area', level: 3),
      ],
    );
  });

  test('opening payload requires both saved and complete state', () {
    final completeOpening = CreateOriginDraft.empty().copyWith(
      opening: const OpeningDraft(
        locationId: 'location-1',
        dialogue: <OpeningDialogueDraft>[
          OpeningDialogueDraft(
            type: OpeningDialogueDraft.narratorType,
            content: 'Ready',
          ),
        ],
      ),
    );
    final incompleteOpening = completeOpening.copyWith(
      opening: const OpeningDraft(
        locationId: 'location-1',
        dialogue: <OpeningDialogueDraft>[
          OpeningDialogueDraft(
            type: OpeningDialogueDraft.characterType,
            content: 'Missing character',
          ),
        ],
      ),
      openingSaved: true,
    );

    expect(
      completeOpening.toCreateOriginPayload(),
      isNot(contains('init_location_group')),
    );
    expect(
      incompleteOpening.toCreateOriginPayload(),
      isNot(contains('init_location_group')),
    );
  });

  test('submission rejects more than one recommended character', () {
    final errors = CreateOriginDraft.empty()
        .copyWith(
          characters: const <CharacterDraft>[
            CharacterDraft(
              name: 'Ari',
              identity: 'Guide',
              personality: 'Calm',
              isRecommend: 1,
            ),
            CharacterDraft(
              name: 'Bex',
              identity: 'Scout',
              personality: 'Bold',
              isRecommend: 1,
            ),
          ],
        )
        .validateForSubmit();

    expect(
      errors,
      contains('Characters: Only one character can be recommended.'),
    );
  });
}
