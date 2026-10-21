import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_projection.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_section_participation.dart';
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

  test('History Enter copy maps to the shared location entry payload', () {
    for (final verb in ['entered', 'came to']) {
      final enter = historyMessage(
        'enter',
        type: 'user',
        content: 'Role $verb Place A',
      );
      final vms = project([
        historyMessage('tick', type: 'tick'),
        enter,
      ], revision: verb.hashCode);
      final vm = vms.first;
      expect(vm.isUserEnterLocation, isTrue);
      expect(
        vm.timelinePayload,
        ChatUserEnterLocationPayloadVm(
          characterId: 'c1',
          toLocationId: 'A',
          text: enter.content,
        ),
      );
      expect(p.rows.first.message.type, 'user');
      expect(vms.last.isTick, isTrue);
      expect(p.rows.map((r) => r.sectionId).toSet(), hasLength(1));
    }
  });

  test(
    'ordinary speech, narration and ambiguous locations keep normal bubbles',
    () {
      final rows = [
        historyMessage(
          'speech',
          type: 'user',
          content: 'I entered Place A yesterday',
        ),
        historyMessage(
          'other-name',
          type: 'user',
          content: 'Someone else entered Place A',
        ),
        historyMessage(
          'multiline',
          type: 'user',
          content: 'Role entered Place A\nThen said hello',
        ),
        historyMessage(
          'multiple-locations',
          type: 'user',
          content: 'Role entered Place A',
          locations: ['A', 'B'],
        ),
        historyMessage(
          'no-location',
          type: 'user',
          content: 'Role entered Place A',
          locations: [],
        ),
        historyMessage('character', content: 'Role entered Place A'),
        WorldHistoryMessage.fromJson({
          ...historyJson(
            'narration',
            type: 'user',
            content: 'Role entered Place A',
          ),
          'message_type': 'narration',
        }),
      ];
      expect(project(rows).every((m) => !m.isUserEnterLocation), isTrue);
    },
  );

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
      final vms = project([
        historyMessage('user-b', type: 'user', locations: ['B']),
        row,
        historyMessage('user-a', type: 'user'),
      ]).where((m) => m.isTick).toList();
      expect(vms.length, 2);
      final a = vms.first.timelinePayload as ChatTickPayloadVm;
      final b = vms.last.timelinePayload as ChatTickPayloadVm;
      expect(vms.last.currentTime, 'Day 5');
      expect(vms.last.tickNo, 0);
      expect(b.globalText, 'The rain begins.');
      expect(b.globalStatuses.single.content, 'Rain');
      expect(b.hasStoryEvents, isFalse);
      expect(a.storyEvents!.paragraphs.single.visibilityLabel, 'future_value');
      expect(a.storyEvents!.paragraphs.single.statuses.single.content, 'Wary');
      expect(a.charactersMoved, isNull);
      expect(p.rows.map((r) => r.locationId), ['A', 'A', 'B', 'B']);
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
        final vm = project([
          row,
          historyMessage('user', type: 'user'),
        ], revision: text.hashCode).firstWhere((m) => m.isTick);
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
      final rows = [
        row,
        historyMessage('user', type: 'user', locations: ['B']),
      ];
      project(rows, world: historyWorld(locations: 1));
      expect(p.metadata.locations['B'], isNull);
      project(rows, world: historyWorld(locations: 2));
      expect(p.metadata.locations['B']!.name, 'Place B');
      expect(identical(decoded, row.tick), isTrue);
      expect(p.rows.every((r) => r.locationId == 'B'), isTrue);
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
      rows.add(historyMessage('user', type: 'user'));
      final first = project(rows, world: world);
      expect(first.length, 151);
      for (final m in first.where((m) => m.senderType == 'tick')) {
        expect(m.isTick, isTrue);
      }
      final reads = chars.reads, parses = p.parsedMessageCount;
      expect(reads, lessThan(500));
      expect(p.metadata.buildCount, 1);
      final next = project(rows, world: world.copyWith(currentTime: 'Day 99'));
      for (final m in next.where((m) => m.senderType == 'tick')) {
        expect(m.isTick, isTrue);
      }
      expect(identical(first, next), isTrue);
      expect(chars.reads, reads);
      expect(p.parsedMessageCount, parses);
      expect(p.metadata.buildCount, 1);
    },
  );

  test(
    'Tick labels use stored tick/sub_tick values for aggregate and legacy content',
    () {
      for (final content in [tickContent(), 'Historical plain Tick']) {
        final vms = project([
          historyMessage(
            'sub',
            type: 'tick',
            tick: 7,
            subTick: 3,
            content: content,
          ),
          historyMessage('main', type: 'tick', tick: 7, content: content),
          historyMessage('zero', type: 'tick', tick: 0, content: content),
          historyMessage('user', type: 'user', tick: 42, subTick: 9),
        ], revision: content.hashCode);
        expect(vms.where((m) => m.isTick).map((m) => (m.tickNo, m.subTickNo)), [
          (0, 0),
          (7, 0),
          (7, 3),
        ]);
      }
    },
  );

  test('any user in the continuous location section admits all its Ticks', () {
    final newestFirst = [
      historyMessage('tick-3', type: 'tick'),
      historyMessage('narrator', type: 'narrator'),
      historyMessage('tick-2', type: 'tick'),
      historyMessage('user', type: 'user'),
      historyMessage('tick-1', type: 'tick'),
    ];
    project(newestFirst);
    expect(p.rows.map((r) => r.message.id), [
      'tick-1',
      'user',
      'tick-2',
      'narrator',
      'tick-3',
    ]);
    expect(p.rows.map((r) => r.sectionId).toSet(), hasLength(1));
  });

  for (final userAfter in [false, true]) {
    test(
      'world Ticks stay in their participating fold; userAfter=$userAfter',
      () {
        const locations = [
          'loc_1_1_1',
          'loc_1_1_2',
          'loc_1_2_1',
          'loc_1_3_1',
          'loc_1_4_1',
          'loc_1_5_1',
          'loc_1_6_1',
          'loc_1_7_1',
          'loc_1_8_1',
        ];
        final user = historyMessage(
          'user',
          type: 'user',
          locations: ['loc_1_2_1'],
        );
        final chronological = [
          if (!userAfter) user,
          for (var i = 1; i <= 3; i++)
            historyMessage('tick-$i', type: 'tick', locations: locations),
          if (userAfter) user,
          historyMessage('reply', locations: ['loc_1_2_1']),
        ];
        project(chronological.reversed.toList());
        expect(
          p.rows
              .where((r) => r.message.type == 'tick')
              .map((r) => r.message.id),
          ['tick-1', 'tick-2', 'tick-3'],
        );
        expect(p.rows.every((r) => r.locationId == 'loc_1_2_1'), isTrue);
        expect(p.rows.map((r) => r.sectionId).toSet(), hasLength(1));
        expect(p.parsedTickCount, 0);
      },
    );
  }

  test('consecutive shared Ticks aggregate into both participating folds', () {
    project([
      historyMessage('user-b', type: 'user', locations: ['B']),
      historyMessage('tick-2', type: 'tick', locations: ['A', 'B']),
      historyMessage('tick-1', type: 'tick', locations: ['A', 'B']),
      historyMessage('user-a', type: 'user'),
    ]);
    expect(p.rows.map((r) => (r.message.id, r.locationId)), [
      ('user-a', 'A'),
      ('tick-1', 'A'),
      ('tick-2', 'A'),
      ('tick-1', 'B'),
      ('tick-2', 'B'),
      ('user-b', 'B'),
    ]);
    final sections = <String, List<HistoryDisplayRow>>{};
    for (final row in p.rows) {
      (sections[row.sectionId] ??= []).add(row);
    }
    expect(sections, hasLength(2));
    expect(
      sections.values.every(
        (rows) => rows.any((r) => r.message.type == 'user'),
      ),
      isTrue,
    );
  });

  test('revisiting a location does not inherit an earlier section user', () {
    project([
      historyMessage('later-tick', type: 'tick'),
      historyMessage('later-character'),
      historyMessage('forest', locations: ['B']),
      historyMessage('earlier-tick', type: 'tick'),
      historyMessage('user', type: 'user'),
    ]);
    expect(p.rows.map((r) => r.message.id), [
      'user',
      'earlier-tick',
      'forest',
      'later-character',
    ]);
  });

  test('hidden Tick-only sections keep the surrounding visits separate', () {
    project([
      historyMessage('later-character'),
      historyMessage('later-tick', type: 'tick'),
      historyMessage('hidden-forest', type: 'tick', locations: ['B']),
      historyMessage('user', type: 'user'),
    ]);
    expect(p.rows.map((r) => r.message.id), ['user', 'later-character']);
    expect(p.rows.first.sectionId, isNot(p.rows.last.sectionId));
  });

  test('character, narrator and version-hidden users cannot admit Ticks', () {
    project([
      historyMessage('tick', type: 'tick'),
      historyMessage('character'),
      historyMessage('narrator', type: 'narrator'),
      historyMessage('hidden-user', type: 'user', version: 1000),
    ]);
    expect(p.rows.map((r) => r.message.id), ['narrator', 'character']);
  });

  test('cross-page section extends incrementally and survives body eviction', () {
    final tick = historyMessage('tick', type: 'tick');
    final user = historyMessage('user', type: 'user');
    final participation = HistorySectionParticipation(appVersion: 999)
      ..appendOlder([tick]);
    List<ChatMessageVm> render(int revision) => p.project(
      newestFirst: [tick],
      dataRevision: revision,
      world: historyWorld(),
      uid: 'me',
      appVersion: 999,
      sectionParticipation: participation,
    );
    expect(render(1), isEmpty);
    participation.appendOlder([tick, user]); // Overlap is deduplicated.
    expect(render(2).single.isTick, isTrue);
    // The user's page body is absent from projection, but the section survives.
    participation.appendOlder([
      historyMessage('boundary', locations: ['B']),
      historyMessage('other-tick', type: 'tick'),
    ]);
    expect(render(3).single.isTick, isTrue);
    expect(participation.includesTick('other-tick', 'A'), isFalse);
    participation.clear();
    expect(render(4), isEmpty);
  });

  test(
    'metadata iteration does not resolve Tick bodies; content edits invalidate',
    () {
      final world = historyWorld();
      final messages = [
        historyMessage('user', type: 'user'),
        for (var i = 0; i < 100; i++)
          historyMessage('tick-$i', type: 'tick', content: 'original-$i'),
      ];
      final vms = project(messages, world: world).toList();
      for (final vm in vms) {
        vm.isSystem;
        vm.isTimelineEvent;
        vm.timelinePayloadVersion;
        vm.currentTimeVersion;
      }
      expect(p.parsedTickCount, 0);
      final tick = vms.firstWhere((m) => m.isTick);
      final version = tick.timelinePayloadVersion;
      expect(
        (tick.timelinePayload as ChatTickPayloadVm).fallbackContent,
        startsWith('original-'),
      );
      tick.currentTime;
      tick.timelinePayload;
      expect(p.parsedTickCount, 1);
      expect(tick.timelinePayloadVersion, version);
      final changed = project(
        [
          historyMessage('user', type: 'user'),
          historyMessage('tick-99', type: 'tick', content: 'edited'),
        ],
        world: world,
        revision: 2,
      ).firstWhere((m) => m.isTick);
      expect(p.parsedTickCount, 1);
      expect(
        (changed.timelinePayload as ChatTickPayloadVm).fallbackContent,
        'edited',
      );
      expect(p.parsedTickCount, 2);
      changed.timelinePayload = ChatTickPayloadVm(fallbackContent: 'assigned');
      changed.currentTime = 'changed time';
      expect(
        (changed.timelinePayload as ChatTickPayloadVm).fallbackContent,
        'assigned',
      );
      expect(changed.currentTime, 'changed time');
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
