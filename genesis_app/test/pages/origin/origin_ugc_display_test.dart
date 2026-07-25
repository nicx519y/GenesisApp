import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_draft_repository.dart';

void main() {
  test('origin response models preserve returned UGC backslashes', () {
    final detail = OriginDetail.fromJson({
      'oid': 'origin-1',
      'name': r'Name\nvalue',
      'description': r'Description\nvalue',
      'world_view': r'View\nvalue',
      'characters': [
        {
          'character_id': 'char-1',
          'name': r'Character\nname',
          'identity': r'Identity\nvalue',
          'brief': r'Tagline\nvalue',
          'goal': r'Goal\nvalue',
        },
      ],
      'locations': [
        {
          'location_id': 'loc-1',
          'name': r'Location\nname',
          'description': r'Location\ndescription',
        },
      ],
      'events': [
        {'content': r'Event\ncontent'},
      ],
    });

    expect(detail.name, r'Name\nvalue');
    expect(detail.description, r'Description\nvalue');
    expect(detail.worldView, r'View\nvalue');
    expect(detail.characters.single.name, r'Character\nname');
    expect(detail.characters.single.tags, r'Identity\nvalue');
    expect(detail.characters.single.tagline, r'Tagline\nvalue');
    expect(detail.characters.single.goal, r'Goal\nvalue');
    expect(detail.locations.single.name, r'Location\nname');
    expect(detail.locations.single.description, r'Location\ndescription');
    expect(detail.events.single.content, r'Event\ncontent');
  });

  test('edit draft preserves returned UGC before fields are rendered', () {
    final draft = originDraftFromV1Detail({
      'origin': {
        'oid': 'origin-1',
        'name': r'Name\nvalue',
        'world_view': r'View\nvalue',
        'world_setting': r'Setting\nvalue',
      },
      'metric': {'label': r'Metric\nlabel'},
      'character_list': [
        {
          'character_id': 'char-1',
          'name': r'Character\nname',
          'identity': r'Identity\nvalue',
          'personality': r'Personality\nvalue',
          'bio': r'Bio\nvalue',
          'goal': r'Goal\nvalue',
        },
      ],
      'location_list': [
        {
          'location_id': 'loc-1',
          'name': r'Location\nname',
          'description': r'Location\ndescription',
        },
      ],
      'event_list': [
        {'content': r'Event\ncontent'},
      ],
    });

    expect(draft.basics.originName, r'Name\nvalue');
    expect(draft.basics.worldView, r'View\nvalue');
    expect(draft.basics.worldLogic, r'Setting\nvalue');
    expect(draft.basics.metricJson, r'{"label":"Metric\\nlabel"}');
    expect(draft.characters.single.name, r'Character\nname');
    expect(draft.characters.single.identity, r'Identity\nvalue');
    expect(draft.characters.single.personality, r'Personality\nvalue');
    expect(draft.characters.single.bio, r'Bio\nvalue');
    expect(draft.characters.single.goal, r'Goal\nvalue');
    expect(draft.locations.single.name, r'Location\nname');
    expect(draft.locations.single.description, r'Location\ndescription');
    expect(draft.storyEvents.single.event, r'Event\ncontent');
  });
}
