import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_projection.dart';
import 'history_fixtures.dart';

class CountingList extends ListBase<Map<String, dynamic>> {
  CountingList(this.items);
  final List<Map<String, dynamic>> items;
  int reads = 0;
  @override
  int get length => items.length;
  @override
  set length(int value) => throw UnsupportedError('read-only');
  @override
  Map<String, dynamic> operator [](int index) {
    reads++;
    return items[index];
  }

  @override
  void operator []=(int index, Map<String, dynamic> value) =>
      throw UnsupportedError('read-only');
}

void main() {
  late WorldHistoryProjection p;
  setUp(() {
    p = WorldHistoryProjection();
  });
  List<ChatMessageVm> project(
    List<WorldHistoryMessage> rows, {
    int revision = 1,
    WorldDetail? world,
    int version = 999,
  }) => p.project(
    newestFirst: rows,
    dataRevision: revision,
    world: world ?? historyWorld(),
    uid: 'me',
    appVersion: version,
  );

  test('server order beats ID and time; refs expand in original order', () {
    final rows = [
      historyMessage('1', locations: ['B', 'A']),
      historyMessage('9999999999999999999999'),
      historyMessage('1'),
      historyMessage('8', locations: []),
    ];
    final vms = project(rows);
    expect(p.rows.map((r) => (r.message.id, r.locationId)), [
      ('8', ''),
      ('9999999999999999999999', 'A'),
      ('1', 'B'),
      ('1', 'A'),
    ]);
    expect(vms.map((m) => m.localId).toSet().length, 4);
    expect(
      vms.every(
        (m) => m.globalMessageId == 0 && m.roundId.isEmpty && m.tickNo == 0,
      ),
      isTrue,
    );
  });

  test(
    'multilocation Tick B retains shared time/global/status without events',
    () {
      final row = historyMessage(
        'tick',
        type: 'tick',
        locations: ['A', 'B'],
        content: tickContent(
          statuses: [
            {
              'owner': 'world',
              'icon': '☔',
              'form': 'Weather',
              'content': 'Rain',
            },
          ],
          events: [
            {
              'location_id': 'A',
              'timestamp': 'Day 4',
              'visibility': 'future_value',
              'visible_to': null,
              'text': 'Only A',
              'clue': 'A clue',
              'cast': null,
              'status': [
                {'owner': 'c1', 'icon': 'x', 'form': 'Mood', 'content': 'Wary'},
              ],
            },
          ],
          moves: [
            {'char_id': 'c1', 'old_loc_id': 'A', 'to_loc_id': 'C'},
          ],
        ),
      );
      final vms = project([row]);
      expect(vms.length, 2);
      final a = vms.first.timelinePayload as ChatTickPayloadVm;
      final b = vms.last.timelinePayload as ChatTickPayloadVm;
      expect(vms.last.currentTime, 'Day 5');
      expect(vms.last.tickNo, -1);
      expect(b.globalText, 'The rain begins.');
      expect(b.globalStatuses.single.content, 'Rain');
      expect(b.hasStoryEvents, isFalse);
      expect(a.storyEvents!.paragraphs.single.visibilityLabel, 'future_value');
      expect(a.storyEvents!.paragraphs.single.statuses.single.content, 'Wary');
      expect(a.charactersMoved!.movements.single.toLocationName, 'C');
      expect(p.rows.map((r) => r.locationId), ['A', 'B']);
    },
  );

  test(
    'null and omitted optional arrays; invalid/plain/non-Tick preserve raw',
    () {
      final valid = WorldHistoryTick.tryDecode(
        '''{"current_time":"x","global":"g","story_events":[{"location_id":"A","timestamp":"t","visibility":"unknown","visible_to":null,"text":"event","clue":""}],"characters_moved":null}''',
      )!;
      expect(valid.globalStatus, isEmpty);
      expect(valid.events.single.cast, isEmpty);
      expect(valid.events.single.statuses, isEmpty);
      expect(valid.movements, isEmpty);
      for (final text in ['plain text', '{broken', '{}', '[1]', '42']) {
        final row = historyMessage(text, type: 'tick', content: text);
        final vm = project([row], revision: text.hashCode).single;
        expect((vm.timelinePayload as ChatTickPayloadVm).fallbackContent, text);
      }
      final normal = historyMessage('normal', content: tickContent());
      expect(normal.tick, isNull);
      expect(project([normal]).single.text, normal.content);
    },
  );

  test(
    'new metadata updates names without redecoding Tick or changing refs',
    () {
      final row = historyMessage(
        'tick',
        type: 'tick',
        locations: ['B'],
        content: tickContent(),
      );
      final decoded = row.tick;
      project([row], world: historyWorld(locations: 1));
      expect(p.metadata.locations['B'], isNull);
      project([row], world: historyWorld(locations: 2));
      expect(p.metadata.locations['B']!.name, 'Place B');
      expect(identical(decoded, row.tick), isTrue);
      expect(p.rows.single.locationId, 'B');
      project(
        [
          historyMessage('old', locations: ['A']),
        ],
        revision: 2,
        world: historyWorld(locations: 3),
      );
      expect(p.rows.map((r) => r.locationId), ['A']);
    },
  );

  test(
    '150 messages / 100 characters share index; clock update does zero reparse',
    () {
      final chars = CountingList(
        List.generate(100, (i) => {'char_id': 'c$i', 'name': 'Role $i'}),
      );
      final world = historyWorld().copyWith(characters: chars);
      final rows = List.generate(
        150,
        (i) => historyMessage('$i', type: 'tick', content: tickContent()),
      );
      final first = project(rows, world: world);
      for (final m in first) {
        expect(m.isTick, isTrue);
      }
      final reads = chars.reads, parses = p.parsedMessageCount;
      expect(reads, lessThan(500));
      expect(p.metadata.buildCount, 1);
      final next = project(rows, world: world.copyWith(currentTime: 'Day 99'));
      for (final m in next) {
        expect(m.isTick, isTrue);
      }
      expect(identical(first, next), isTrue);
      expect(chars.reads, reads);
      expect(p.parsedMessageCount, parses);
      expect(p.metadata.buildCount, 1);
    },
  );

  test('shared render window reuses VMs beyond the LRU limit', () {
    final world = historyWorld();
    final rows = List.generate(500, (i) => historyMessage('$i'));
    final mounted = project(rows, world: world).toList();
    final parses = p.parsedMessageCount;
    final next = project(
      rows,
      world: world.copyWith(currentTime: 'Day 88'),
    ).toList();
    expect(p.parsedMessageCount, parses);
    expect(next, mounted);
    expect(p.cacheSize, 300);
  });

  test(
    'LRU and released pages clear derived data; version filter does not fetch',
    () {
      final rows = List.generate(500, (i) => historyMessage('$i'));
      final vms = project(rows);
      for (final m in vms) {
        expect(m.senderId, 'c1');
      }
      expect(p.cacheSize, 300);
      project(
        [historyMessage('too-new', version: 100)],
        revision: 2,
        version: 1,
      );
      expect(p.rows, isEmpty);
      expect(p.cacheSize, 0);
      p.clear();
      expect(p.byId, isEmpty);
    },
  );
}
