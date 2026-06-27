import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/pages/origin/origin_world_page.dart';

void main() {
  test('origin detail sheet uses main ui horizontal padding', () {
    expect(originDetailSheetHorizontalPaddingForTesting, 12);
  });

  test('origin detail sheet header sizing matches design', () {
    expect(originDetailSheetHeaderHeightForTesting, 20);
    expect(originDetailSheetHeaderBodyGapForTesting, 12);
    expect(originDetailSheetHandleTopOffsetForTesting, 2);
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
          description: '',
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
}
