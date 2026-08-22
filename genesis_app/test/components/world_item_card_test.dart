import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/home/world_item_card.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_image_radii.dart';

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
  testWidgets('9l row uses a 52x78 cover thumbnail', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, _item());

    final thumb = tester.widget<GenesisListImage>(
      find.byType(GenesisListImage).first,
    );
    expect(thumb.width, 52);
    expect(thumb.height, 78);
    expect(
      thumb.borderRadius,
      BorderRadius.circular(GenesisImageRadii.contentValue),
    );
    expect(thumb.maxDevicePixelRatio, 3);
  });

  testWidgets('world name is a 15/800 content title', (tester) async {
    await _pump(tester, _item());

    final title = tester.widget<Text>(find.text('Alpha World'));
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(title.style?.height, 1.1);
    expect(title.style?.color, _dark.textPrimary);
    expect(title.maxLines, 1);
  });

  testWidgets('story summary is two lines of 11/1.45 secondary text', (
    tester,
  ) async {
    await _pump(tester, _item());

    final summary = tester.widget<Text>(
      find.text('The city chooses a new route.'),
    );
    expect(summary.style?.fontSize, 11);
    expect(summary.style?.height, 1.45);
    expect(summary.style?.color, _dark.textSecondary);
    expect(summary.maxLines, 2);
  });

  testWidgets('character row is a 20px red-ringed avatar with the tick state', (
    tester,
  ) async {
    await _pump(tester, _item());

    final avatar = tester.widget<GenesisCharacterAvatar>(
      find.byType(GenesisCharacterAvatar),
    );
    expect(avatar.size, 20);
    expect(avatar.borderRadius, 7);
    expect((avatar.border! as Border).top.color, _dark.primary);
    expect((avatar.border! as Border).top.width, 2);

    final name = tester.widget<Text>(find.text('Self Hero'));
    expect(name.style?.fontSize, 11);
    expect(name.style?.height, 1);
    expect(name.style?.fontWeight, FontWeight.w600);
    expect(name.style?.color, _dark.textBody);

    final tick = tester.widget<Text>(find.text('Tick 3-2'));
    expect(tick.style?.fontSize, 9.5);
    expect(tick.style?.fontWeight, FontWeight.w500);
    expect(tick.style?.color, _dark.textTimestamp);
  });

  testWidgets('a world that has not run shows Not started', (tester) async {
    await _pump(tester, _item(tickNo: 0, subTickNo: 0));

    expect(find.text('Not started'), findsOneWidget);
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
    expect(tester.getSize(find.byKey(const ValueKey<String>(
      'world-activity-dot',
    ))), const Size(6, 6));
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
    // The character row still renders.
    expect(find.text('Self Hero'), findsOneWidget);
  });

  testWidgets('character row is absent when the user has no character', (
    tester,
  ) async {
    await _pump(tester, _item(myCharacter: null));

    expect(find.byType(GenesisCharacterAvatar), findsNothing);
    expect(find.text('Alpha World'), findsOneWidget);
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
