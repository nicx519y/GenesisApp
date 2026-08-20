import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/components/home/world_item_card.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_image_radii.dart';

void main() {
  testWidgets('renders last progress time from last tick created_at', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    final item = WorldListItem.fromJson(const <String, dynamic>{
      'wid': 'w_alpha',
      'name': 'Alpha World',
      'cover': '',
      'created_uid': 'u_1',
      'created_user_name': 'Shawn',
      'created_at': '2020-01-01T00:00:00Z',
      'updated_at': '2020-01-02T00:00:00Z',
      'last_tick': {
        'tick_no': 3,
        'sub_tick_no': 2,
        'current_time': 'Day 3, 08:00',
        'created_at': '2999-01-01T00:00:00Z',
        'narrator': 'The city chooses a new route.',
      },
      'tick_cnt': 3,
      'connect_cnt': 4,
      'ai_character_cnt': 5,
      'player_cnt': 6,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 390, child: WorldItemCard(item: item)),
        ),
      ),
    );

    expect(find.text('Last Progress'), findsOneWidget);
    expect(find.text('Alpha World'), findsOneWidget);
    expect(find.text('#Alpha World'), findsNothing);
    expect(
      _horizontalGap(
        tester,
        find.byIcon(MyFlutterApp.lastProgress),
        find.text('Last Progress'),
      ),
      8,
    );
    expect(find.text('2999-1-1'), findsOneWidget);
    expect(find.text('Tick 3-2 · Day 3, 08:00'), findsOneWidget);
    expect(find.text('The city chooses a new route.'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text('The city chooses a new route.'))
          .style
          ?.height,
      1.25,
    );
    expect(
      tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .any(
            (svg) =>
                svg.bytesLoader.toString().contains(homeCharacterStatIconAsset),
          ),
      isTrue,
    );
    expect(
      tester.getTopLeft(find.byIcon(MyFlutterApp.lastProgress)).dy,
      tester.getRect(find.byType(GenesisListImage).first).bottom + 16,
    );

    final thumbnails = tester.widgetList<GenesisListImage>(
      find.byType(GenesisListImage),
    );
    expect(
      thumbnails.any(
        (image) =>
            image.width == 60 &&
            image.height == 60 &&
            image.borderRadius ==
                BorderRadius.circular(GenesisImageRadii.contentValue),
      ),
      isTrue,
    );
    expect(thumbnails.every((image) => image.maxDevicePixelRatio == 3), isTrue);

    final titleLeft = tester.getTopLeft(find.text('Alpha World')).dx;
    final bodyLeft = tester
        .getTopLeft(find.text('The city chooses a new route.'))
        .dx;
    expect(bodyLeft, lessThan(titleLeft));
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

  testWidgets('renders scene mine my_character without detail services', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    final item = WorldListItem.fromJson(const <String, dynamic>{
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
        'tick_no': 3,
        'current_time': 'Day 3, 08:00',
        'created_at': '2999-01-01T00:00:00Z',
        'narrator': 'The city chooses a new route.',
      },
      'my_character': {
        'char_id': 'c_self',
        'player_uid': 'u_mock',
        'player_username': 'Mock User',
        'name': 'Self Hero',
        'brief': 'Current user character.',
        'avatar': {'sm_url': '', 'xl_url': '', 'object_key': ''},
        'metric_value': 0,
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 390, child: WorldItemCard(item: item)),
        ),
      ),
    );

    expect(item.myCharacter?['char_id'], 'c_self');
    expect(item.metric['default'], 42);
    expect(_richTextFinder('Self Hero (Me)'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Goal Progress: 42%'), findsOneWidget);
    expect(
      tester
          .widget<GenesisCharacterAvatar>(find.byType(GenesisCharacterAvatar))
          .maxDevicePixelRatio,
      3,
    );
  });

  testWidgets('renders recent activity tag label after world name', (
    WidgetTester tester,
  ) async {
    final item = WorldListItem.fromJson(const <String, dynamic>{
      'wid': 'w_alpha',
      'name': 'Alpha World',
      'cover': '',
      'created_uid': 'u_1',
      'created_user_name': 'Shawn',
      'created_at': '2020-01-01T00:00:00Z',
      'updated_at': '2020-01-02T00:00:00Z',
      'tick_cnt': 3,
      'connect_cnt': 4,
      'ai_character_cnt': 5,
      'player_cnt': 6,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: WorldItemCard(
              item: item,
              recentActivityTagLabel: 'Last Tick',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Alpha World'), findsOneWidget);
    expect(find.text('Last Tick'), findsNothing);
    expect(find.text('Recent'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('recent-activity-tag-last-tick')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Recent')).dx,
      greaterThan(tester.getTopLeft(find.text('Alpha World')).dx),
    );
  });

  testWidgets('hides only last progress section when summary is empty', (
    WidgetTester tester,
  ) async {
    final item = WorldListItem.fromJson(const <String, dynamic>{
      'wid': 'w_empty_progress',
      'name': 'Quiet World',
      'cover': '',
      'updated_at': '2020-01-02T00:00:00Z',
      'last_tick': {
        'tick_no': 3,
        'current_time': 'Day 3, 08:00',
        'created_at': '2999-01-01T00:00:00Z',
        'narrator': '   ',
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 390, child: WorldItemCard(item: item)),
        ),
      ),
    );

    expect(find.text('Quiet World'), findsOneWidget);
    expect(find.text('Last Progress'), findsNothing);
    expect(find.text('Tick 3 · Day 3, 08:00'), findsNothing);
    expect(find.byIcon(MyFlutterApp.lastProgress), findsNothing);
  });

  testWidgets(
    'keeps character section 16px below summary when last progress is absent',
    (WidgetTester tester) async {
      final item = WorldListItem.fromJson(const <String, dynamic>{
        'info': {
          'world_id': 'w_empty_progress',
          'world_name': 'Quiet World',
          'cover': '',
          'owner_uid': 'u_owner',
          'owner_name': 'Owner',
          'metric': {'label': 'Goal Progress', 'unit': '%', 'default': 42},
        },
        'last_tick': {'narrator': '   '},
        'my_character': {
          'char_id': 'c_self',
          'player_uid': 'u_mock',
          'player_username': 'Mock User',
          'name': 'Self Hero',
          'avatar': {'sm_url': '', 'xl_url': '', 'object_key': ''},
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 390, child: WorldItemCard(item: item)),
          ),
        ),
      );

      final summaryBottom = tester
          .getRect(find.byType(GenesisListImage).first)
          .bottom;
      final characterTop = tester
          .getTopLeft(_richTextFinder('Self Hero (Me)'))
          .dy;

      expect(characterTop, summaryBottom + 18);
    },
  );
}

double _horizontalGap(WidgetTester tester, Finder left, Finder right) {
  final leftRect = tester.getRect(left);
  final rightRect = tester.getRect(right);
  return rightRect.left - leftRect.right;
}

Finder _richTextFinder(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );
}
