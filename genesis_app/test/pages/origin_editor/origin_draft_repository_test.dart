import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_draft_repository.dart';

void main() {
  group('V2 foredit child-page mapping', () {
    test('maps nested detail without inventing legacy edit fields', () {
      final draft = originDraftFromV2ForEdit({
        ..._forEditData(),
        'ticks': const [
          {
            'tick_no': 2,
            'tick_result': {
              'narrator': 'Runtime history is not a story event.',
            },
          },
        ],
      });

      expect(draft.basics.originId, 'o_edit');
      expect(draft.basics.originName, 'Editable Origin');
      expect(draft.basics.worldView, 'A public brief.');
      expect(draft.basics.worldLogic, isEmpty);
      expect(draft.basics.coverImageUrl, 'cover.webp');
      expect(draft.characters.single.personality, 'Patient');
      expect(draft.characters.single.bio, isEmpty);
      expect(draft.locations.single.initialCharacterIds, ['char_mira']);
      expect(draft.storyEvents.single.event, isEmpty);
      expect(draft.storyEventsSaved, isTrue);
    });
  });

  group('Origin edit Opening restoration', () {
    test('restores a complete init_location_group from foredit', () {
      final draft = originDraftFromV2ForEdit({
        ..._forEditData(),
        'init_location_group': {
          'location_id': 'loc_archive',
          'location_name': 'Untrusted response name',
          'initial_dialogue': const [
            {'char_id': 'nar', 'content': 'The archive opens.'},
            {'char_id': 'char_mira', 'content': 'Keep your voice down.'},
            {'char_id': 'nar_pic', 'content': 'https://cdn.test/opening.webp'},
          ],
        },
      });

      expect(draft.openingSaved, isTrue);
      expect(draft.opening.locationId, 'loc_archive');
      expect(draft.opening.locationName, 'Archive');
      expect(
        draft.opening.dialogue
            .map((item) => (item.type, item.characterId, item.content))
            .toList(),
        [
          ('narrator', '', 'The archive opens.'),
          ('character', 'char_mira', 'Keep your voice down.'),
          ('image', '', 'https://cdn.test/opening.webp'),
        ],
      );
    });

    test('rejects an incomplete or invalid foredit Opening as a whole', () {
      final draft = originDraftFromV2ForEdit({
        ..._forEditData(),
        'init_location_group': {
          'location_id': 'loc_archive',
          'initial_dialogue': const [
            {'char_id': 'nar', 'content': 'Valid first line.'},
            {'char_id': 'char_missing', 'content': 'Unknown character.'},
          ],
        },
      });

      expect(draft.openingSaved, isFalse);
      expect(draft.opening.locationId, isEmpty);
      expect(draft.opening.dialogue, isEmpty);
    });

    test('keeps the legacy image char_id readable', () {
      final draft = originDraftFromV2ForEdit({
        ..._forEditData(),
        'init_location_group': {
          'location_id': 'loc_archive',
          'initial_dialogue': const [
            {'char_id': 'image', 'content': 'legacy-opening.webp'},
          ],
        },
      });

      expect(draft.openingSaved, isTrue);
      expect(draft.opening.dialogue.single.type, 'image');
      expect(draft.opening.dialogue.single.content, 'legacy-opening.webp');
    });

    test(
      'falls back to tick 1 location_groups and preserves dialogue order',
      () {
        final initialDraft = originDraftFromV2ForEdit(_forEditData());

        final restored = restoreOriginDraftOpeningFromDetail(initialDraft, {
          'ticks': [
            {
              'tick_no': 2,
              'status': 10,
              'tick_result': {
                'location_groups': [
                  {
                    'location_id': 'loc_archive',
                    'initial_dialogue': [
                      {'char_id': 'nar', 'content': 'Later tick.'},
                    ],
                  },
                ],
              },
            },
            {
              'tick_no': 1,
              'status': 10,
              'tick_result': {
                'location_groups': [
                  {
                    'location_id': 'unknown_location',
                    'initial_dialogue': [
                      {'char_id': 'nar', 'content': 'Invalid group.'},
                    ],
                  },
                  {
                    'location_id': 'loc_archive',
                    'location_name': 'Server-side stale name',
                    'initial_dialogue': [
                      {'char_id': 'nar_pic', 'content': 'opening.webp'},
                      {'char_id': 'char_mira', 'content': 'Welcome.'},
                      {'char_id': 'nar', 'content': 'Dust rises.'},
                    ],
                  },
                ],
              },
            },
          ],
        });

        expect(restored.openingSaved, isTrue);
        expect(restored.opening.locationName, 'Archive');
        expect(restored.opening.dialogue.map((item) => item.type).toList(), [
          'image',
          'character',
          'narrator',
        ]);
        expect(restored.opening.dialogue.map((item) => item.content).toList(), [
          'opening.webp',
          'Welcome.',
          'Dust rises.',
        ]);
      },
    );

    test(
      'keeps Opening unsaved when detail cannot restore valid tick 1 data',
      () {
        final initialDraft = originDraftFromV2ForEdit(_forEditData());

        final restored = restoreOriginDraftOpeningFromDetail(initialDraft, {
          'ticks': [
            {
              'tick_no': 2,
              'tick_result': {
                'location_groups': [
                  {
                    'location_id': 'loc_archive',
                    'initial_dialogue': [
                      {'char_id': 'nar', 'content': 'Not the initial tick.'},
                    ],
                  },
                ],
              },
            },
          ],
        });

        expect(restored.openingSaved, isFalse);
        expect(restored.hasRequiredSectionsSaved, isFalse);
        expect(
          restored.validateForSubmit(),
          contains(contains('Please save Opening')),
        );
      },
    );
  });
}

Map<String, dynamic> _forEditData() {
  return {
    'info': {
      'origin_id': 'o_edit',
      'origin_name': 'Editable Origin',
      'origin_version': '3',
      'brief': 'A public brief.',
      'cover': {
        'sm_url': 'cover_400.webp',
        'xl_url': 'cover.webp',
        'object_key': 'covers/cover.webp',
      },
    },
    'stats': const <String, Object?>{},
    'characters': const [
      {
        'char_id': 'char_mira',
        'name': 'Mira',
        'identity': 'Archivist',
        'brief': 'Patient',
        'initial_location_id': 'loc_archive',
        'location_id': 'loc_elsewhere',
      },
    ],
    'locations': const [
      {
        'location_id': 'loc_archive',
        'level': 3,
        'location_name': 'Archive',
        'location_description': 'A quiet tower.',
      },
    ],
    'ticks': const <Object?>[],
  };
}
