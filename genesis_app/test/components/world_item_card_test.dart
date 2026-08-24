import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/home/world_item_card.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';

WorldListItem _item({
  String narrator = 'The city chooses a new route.',
  int tickNo = 3,
  int subTickNo = 2,
  Map<String, dynamic>? myCharacter = const <String, dynamic>{
    'char_id': 'c_self',
    'player_uid': 'u_mock',
    'player_username': 'Mock User',
    'name': 'Self Hero',
    'avatar': {'sm_url': '', 'xl_url': '', 'object_key': ''},
    'metric_value': 0,
  },
}) {
  return WorldListItem.fromJson(<String, dynamic>{
    'info': {
      'world_id': 'w_alpha',
      'world_name': 'Alpha World',
      'cover': '',
      'owner_uid': 'u_owner',
      'owner_name': 'Owner',
      'updated_at': '2020-01-02T00:00:00Z',
      'metric': {'label': 'Goal Progress', 'unit': '%', 'default': 42},
    },
    'stats': {
      'tick_cnt': 3,
      'connect_cnt': 4,
      'character_cnt': 5,
      'player_cnt': 6,
    },
    'last_tick': {
      'tick_no': tickNo,
      'sub_tick_no': subTickNo,
      'current_time': 'Day 3, 08:00',
      'created_at': '2020-01-02T00:00:00Z',
      'narrator': narrator,
    },
    if (myCharacter != null) 'my_character': myCharacter,
  });
}

Future<void> _pump(WidgetTester tester, WorldListItem item) {
  return tester.pumpWidget(
    MaterialApp(
      theme: GenesisTheme.worldoDark(),
      home: Scaffold(
        body: SizedBox(width: 390, child: WorldItemCard(item: item)),
      ),
    ),
  );
}

GenesisSemanticColors get _dark =>
    GenesisTheme.worldoDark().extension<GenesisSemanticColors>()!;

void main() {
  testWidgets('row cover matches the Me list at 60x78', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, _item());

    final thumb = tester.widget<GenesisListImage>(
      find.byType(GenesisListImage).first,
    );
    expect(thumb.width, 60);
    expect(thumb.height, 78);
    expect(thumb.borderRadius, BorderRadius.circular(8));
    expect(thumb.maxDevicePixelRatio, 3);
  });

  testWidgets('world name is a 14/600 content title', (tester) async {
    await _pump(tester, _item());

    final title = tester.widget<Text>(find.text('Alpha World'));
    expect(title.style?.fontSize, 14);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.style?.height, 1.1);
    expect(title.style?.color, _dark.textPrimary);
    expect(title.maxLines, 1);
  });

  testWidgets('story summary is two lines of 12/1.3 secondary text', (
    tester,
  ) async {
    await _pump(tester, _item());

    final summary = tester.widget<Text>(
      find.text('The city chooses a new route.'),
    );
    expect(summary.style?.fontSize, 12);
    expect(summary.style?.height, 1.3);
    expect(summary.style?.color, _dark.textSecondary);
    expect(summary.maxLines, 2);
    expect(summary.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the character avatar sits on the cover, unringed', (
    tester,
  ) async {
    await _pump(tester, _item());

    final avatar = tester.widget<GenesisCharacterAvatar>(
      find.byType(GenesisCharacterAvatar),
    );
    expect(avatar.size, 20);
    expect(avatar.borderRadius, 7);
    expect(avatar.border, isNull);

    // Hangs past the cover's bottom-right corner by 4, less the 2px ring.
    final coverRect = tester.getRect(find.byType(GenesisListImage).first);
    final avatarRect = tester.getRect(find.byType(GenesisCharacterAvatar));
    expect(avatarRect.right, closeTo(coverRect.right + 2, 0.01));
    expect(avatarRect.bottom, closeTo(coverRect.bottom + 2, 0.01));
  });

  testWidgets('tick state and character read as one accent line', (
    tester,
  ) async {
    await _pump(tester, _item());

    final status = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-status-line')),
    );
    expect(status.data, 'Tick 3-2 · Self Hero');
    expect(status.style?.fontSize, 12);
    expect(status.style?.height, 1.45);
    expect(status.style?.fontWeight, FontWeight.w400);
    expect(status.style?.color, _dark.accentText);
  });

  testWidgets('a world that has not run shows Not started', (tester) async {
    await _pump(tester, _item(tickNo: 0, subTickNo: 0));

    // The tick state shares the single accent line with the player's
    // character, so it is not a standalone label any more.
    final status = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-status-line')),
    );
    expect(status.data, 'Not started · Self Hero');

    await _pump(tester, _item(tickNo: 0, subTickNo: 0, myCharacter: null));
    final soloStatus = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-status-line')),
    );
    expect(soloStatus.data, 'Not started');
  });

  testWidgets('the 9l row drops the role label and the metric line', (
    tester,
  ) async {
    await _pump(tester, _item());

    // These belonged to the old dense row and are not part of 9l.
    expect(find.text('Player'), findsNothing);
    expect(find.text('Goal Progress: 42%'), findsNothing);
    expect(find.textContaining('WID'), findsNothing);
    expect(find.textContaining('Owner'), findsNothing);
    expect(find.text('Last Progress'), findsNothing);
  });

  testWidgets('an active world is marked with a 6px red dot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: WorldItemCard(
              item: _item(),
              recentActivityTagLabel: 'Last Tick',
            ),
          ),
        ),
      ),
    );

    final dot = tester.widget<Container>(
      find.byKey(const ValueKey<String>('world-activity-dot')),
    );
    final decoration = dot.decoration! as BoxDecoration;
    expect(decoration.color, _dark.primary);
    expect(decoration.shape, BoxShape.circle);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('world-activity-dot'))),
      const Size(6, 6),
    );
  });

  testWidgets('a quiet world carries no activity dot', (tester) async {
    await _pump(tester, _item());

    expect(
      find.byKey(const ValueKey<String>('world-activity-dot')),
      findsNothing,
    );
  });

  testWidgets('summary is omitted when the world has no narration', (
    tester,
  ) async {
    await _pump(tester, _item(narrator: ''));

    expect(find.text('The city chooses a new route.'), findsNothing);
    // The status line still renders.
    expect(find.text('Tick 3-2 · Self Hero'), findsOneWidget);
  });

  testWidgets('without a character the line falls back to the tick alone', (
    tester,
  ) async {
    await _pump(tester, _item(myCharacter: null));

    expect(find.byType(GenesisCharacterAvatar), findsNothing);
    expect(find.text('Alpha World'), findsOneWidget);
    final status = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-status-line')),
    );
    expect(status.data, 'Tick 3-2');
  });

  testWidgets('summary and title share the same left edge', (tester) async {
    await _pump(tester, _item());

    final titleLeft = tester.getTopLeft(find.text('Alpha World')).dx;
    final bodyLeft = tester
        .getTopLeft(find.text('The city chooses a new route.'))
        .dx;
    expect(bodyLeft, titleLeft);
  });

  test('tickStateLabel keeps the sub-tick only when it is set', () {
    expect(_item(tickNo: 2, subTickNo: 3).tickStateLabel, 'Tick 2-3');
    expect(_item(tickNo: 3, subTickNo: 0).tickStateLabel, 'Tick 3');
    expect(_item(tickNo: 0, subTickNo: 0).tickStateLabel, 'Not started');
  });

  test('last progress omits the sub-tick suffix when it is zero', () {
    final item = WorldListItem.fromJson(const <String, dynamic>{
      'wid': 'w_alpha',
      'last_tick': {
        'tick_no': 3,
        'sub_tick_no': 0,
        'current_time': 'Day 3, 08:00',
      },
    });

    expect(item.lastProgressSubTickNo, 0);
    expect(item.progressTickTimeLabel, 'Tick 3 · Day 3, 08:00');
  });
}
