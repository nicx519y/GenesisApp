import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/pages/origin/origin_world_page.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_radii.dart';

void main() {
  final originSectionsSource = File(
    'lib/pages/origin/origin_world_sections.dart',
  );

  test('origin detail sheet uses main ui horizontal padding', () {
    expect(originDetailSheetHorizontalPaddingForTesting, 12);
  });

  test('origin detail sheet header sizing matches design', () {
    expect(originDetailSheetHeaderHeightForTesting, 30);
    expect(originDetailSheetHeaderBodyGapForTesting, 0);
    expect(originDetailSheetHandleTopOffsetForTesting, 2);
    expect(GenesisRadii.sheetTopRadiusValue, 18);
  });

  test('origin detail sections use main ui spacing', () {
    expect(originDetailSectionGapForTesting, 24);
    expect(originDetailSectionTitleIconGapForTesting, 8);
  });

  test('origin location opening preview keeps every initial dialogue line', () {
    final messages = originLocationOpeningPreviewMessagesForTesting(
      [
        {
          'tick_no': 1,
          'tick_result': {
            'current_time': 'Day 1, 08:30',
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'nar',
                    'char_name': 'narrator',
                    'content': 'The diner lights hum as Sam unlocks the door.',
                  },
                  {
                    'char_id': 'char_1',
                    'char_name': 'Sam',
                    'content': 'Coffee is on. Keep the sign lit.',
                  },
                  {'char_id': 'char_2', 'char_name': 'Riley', 'content': ''},
                ],
              },
              {
                'location_id': 'loc_2',
                'initial_dialogue': [
                  {
                    'char_id': 'char_3',
                    'char_name': 'Wrong Location',
                    'content': 'This should not be shown.',
                  },
                ],
              },
            ],
          },
        },
      ],
      const ['loc_1'],
    );

    expect(messages.first.senderType, 'tick');
    expect(messages.first.content, 'Day 1, 08:30');
    expect(messages.skip(1).map((message) => message.content), [
      'The diner lights hum as Sam unlocks the door.',
      'Coffee is on. Keep the sign lit.',
    ]);
    expect(messages[1].senderType, 'narrator');
    expect(messages.last.senderType, 'character');
    expect(messages.skip(1).map((message) => message.currentTime), [
      'Day 1, 08:30',
      'Day 1, 08:30',
    ]);
  });

  test('origin location opening preview prefers tick one location group', () {
    final messages = originLocationOpeningPreviewMessagesForTesting(
      [
        {
          'tick_no': 2,
          'tick_result': {
            'current_time': 'Later time.',
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'char_1',
                    'char_name': 'Sam',
                    'content': 'Later line.',
                  },
                ],
              },
            ],
          },
        },
        {
          'tick_no': 1,
          'tick_result': {
            'current_time': 'Opening time.',
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'char_1',
                    'char_name': 'Sam',
                    'content': 'Opening line.',
                  },
                ],
              },
            ],
          },
        },
      ],
      const ['loc_1'],
    );

    expect(messages.first.content, 'Opening time.');
    expect(messages.last.content, 'Opening line.');
    expect(messages.last.currentTime, 'Opening time.');
  });

  test('origin location opening preview resolves character avatars', () {
    final messages = originLocationOpeningPreviewMessagesForTesting(
      [
        {
          'tick_no': 1,
          'tick_result': {
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'char_1',
                    'char_name': 'Sam',
                    'content': 'Opening line.',
                  },
                ],
              },
            ],
          },
        },
      ],
      const ['loc_1'],
    );

    final entities = originLocationOpeningPreviewEntitiesForTesting(
      [
        OriginCharacter(
          id: 7,
          characterId: 'char_1',
          originId: 1,
          name: 'Sam',
          avatar: 'https://example.com/sam.png',
          tags: '',
          currentLocationId: 0,
          initialLocationId: 0,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      messages,
      'loc_1',
    );

    expect(entities.single.id, 'char_1');
    expect(entities.single.avatarUrl, 'https://example.com/sam.png');
    expect(entities.single.isAi, isTrue);
  });

  test('origin location parses dialogue lines', () {
    final location = OriginLocation.fromJson(const {
      'id': 12,
      'origin_id': 1,
      'location_id': 'loc_1',
      'location_name': 'Town Square',
      'dialogue': [
        {
          'char_id': 'char_1',
          'char_name': 'Casey',
          'content': 'Doors open at eight.',
        },
      ],
    });

    expect(location.dialogue, hasLength(1));
    expect(location.dialogue.single.charId, 'char_1');
    expect(location.dialogue.single.charName, 'Casey');
    expect(location.dialogue.single.content, 'Doors open at eight.');
  });

  test('origin map bubbles use location dialogue and character avatar ids', () {
    final origin = _originDetail(
      characters: [
        OriginCharacter(
          id: 7,
          characterId: 'char_1',
          originId: 1,
          name: 'Casey',
          avatar: '',
          tags: '',
          currentLocationId: 12,
          initialLocationId: 12,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      locations: [
        OriginLocation.fromJson(const {
          'id': 12,
          'origin_id': 1,
          'location_id': 'loc_1',
          'location_name': 'Town Square',
          'dialogue': [
            {
              'char_id': 'char_1',
              'content': '*Casey flips the sign.* 「Open before sunrise.」',
            },
            {'char_id': 'nar', 'content': 'Narration should not show.'},
            {'char_id': 'missing', 'content': 'Missing character.'},
            {'char_id': 'char_1', 'content': ''},
          ],
        }),
      ],
    );

    final bubbles = originMapMessageBubblesForTesting(origin);

    expect(bubbles, hasLength(1));
    expect(bubbles.single.characterId, '7');
    expect(bubbles.single.content, 'Open before sunrise.');
  });

  test('origin character tagline reads brief directly', () {
    final character = OriginCharacter.fromJson(const {
      'character_id': 'char_1',
      'name': 'Sam',
      'identity': 'Archivist',
      'tagline': 'Old tagline should be ignored',
      'brief': 'Brief from API',
      'description': 'Description should be ignored',
      'goal': 'Protect the archive',
    });

    expect(character.tagline, 'Brief from API');
  });

  test(
    'origin character section omits description and uses unified body rhythm',
    () {
      final source = originSectionsSource.readAsStringSync();
      final characterRow = source.substring(
        source.indexOf('class _OriginCharacterRow'),
        source.indexOf('class _OriginCharacterPortrait'),
      );
      final bodyStyle = source.substring(
        source.indexOf('const _bodyTextStyle'),
        source.indexOf('const _mutedBodyTextStyle'),
      );

      expect(characterRow, isNot(contains('visibleDescription')));
      expect(characterRow, isNot(contains('character.description')));
      expect(characterRow, isNot(contains('_sameCharacterText')));
      expect(characterRow, isNot(contains('SizedBox(height: 9)')));
      expect(characterRow, contains("Text('Goal: \$goal'"));
      expect(bodyStyle, contains('height: 1.4'));
      expect(bodyStyle, isNot(contains('height: 1.45')));
      expect(bodyStyle, isNot(contains('height: 1.35')));
      expect(source, isNot(contains('bool _sameCharacterText')));
    },
  );
}

OriginDetail _originDetail({
  required List<OriginCharacter> characters,
  required List<OriginLocation> locations,
}) {
  return OriginDetail(
    id: 1,
    oid: 'o_test',
    name: 'Origin',
    description: '',
    mapImage: '',
    worldMap: '',
    worldView: '',
    copyCount: 0,
    interactCount: 0,
    tags: const <String>[],
    createdAt: null,
    updatedAt: null,
    characters: characters,
    locations: locations,
  );
}
