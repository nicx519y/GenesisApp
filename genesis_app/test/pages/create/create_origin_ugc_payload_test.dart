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

    final location = (payload['location_list'] as List).single as Map;
    expect(location['location_id'], 'loc-1');
    expect(location['name'], '  Location  ');
    expect(location['description'], 'Top\nBottom');

    final event = (payload['event_list'] as List).single as Map;
    expect(event['content'], '  Event\ncontinues  ');
  });
}
