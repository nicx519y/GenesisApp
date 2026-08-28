import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/home/world_item_card.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_avatar_radii.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_image_radii.dart';

void main() {
  testWidgets('renders the compact four-row My Worlds card', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    final item = WorldListItem.fromJson(const <String, dynamic>{
      'info': {
        'world_id': 'w_alpha',
        'world_name': 'Alpha World',
        'cover': '',
        'created_at': '2998-01-01T00:00:00Z',
        'last_active_at': '3000-01-01T00:00:00Z',
      },
      'stats': {'connect_cnt': 4},
      'last_tick': {
        'tick_no': 3,
        'sub_tick_no': 2,
        'created_at': '2999-01-01T00:00:00Z',
        'narrator':
            'The city chooses a new route while every district prepares for the next turn.',
      },
      'my_character': {
        'char_id': 'c_self',
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

    expect(item.cardTimestamp, '3000-01-01T00:00:00Z');
    expect(find.text('Alpha World'), findsOneWidget);
    expect(find.text('3000-1-1'), findsOneWidget);
    expect(find.text('2999-1-1'), findsNothing);
    expect(find.text('2998-1-1'), findsNothing);
    expect(find.text('Tick 3-2 · 4 Messages'), findsOneWidget);
    expect(find.text('Self Hero'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('world-card-character-name')),
          )
          .style
          ?.fontWeight,
      FontWeight.w400,
    );

    final tickMessages = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-card-tick-messages')),
    );
    expect(tickMessages.style?.color, const Color(0xFF666666));
    final coverRect = tester.getRect(find.byType(GenesisListImage).first);
    expect(coverRect.left, 0);

    final cover = tester.widget<GenesisListImage>(
      find.byType(GenesisListImage).first,
    );
    expect(cover.width, 60);
    expect(cover.height, 80);
    expect(
      cover.borderRadius,
      BorderRadius.circular(GenesisImageRadii.contentValue),
    );
    expect(cover.maxDevicePixelRatio, 3);

    final narrator = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-card-narrator')),
    );
    expect(narrator.maxLines, 2);
    expect(narrator.overflow, TextOverflow.ellipsis);
    expect(narrator.style?.color, const Color(0xFF666666));
    expect(narrator.style?.fontSize, 12);
    expect(narrator.style?.height, 1.2);
    expect(narrator.style?.fontWeight, FontWeight.w400);

    final avatar = tester.widget<GenesisCharacterAvatar>(
      find.byType(GenesisCharacterAvatar),
    );
    expect(avatar.size, 25);
    expect(avatar.borderRadius, GenesisAvatarRadii.character);
    expect(avatar.maxDevicePixelRatio, 3);

    final nameRect = tester.getRect(
      find.byKey(const ValueKey<String>('world-card-name')),
    );
    final timeRect = tester.getRect(
      find.byKey(const ValueKey<String>('world-card-time')),
    );
    final tickRect = tester.getRect(
      find.byKey(const ValueKey<String>('world-card-tick-messages')),
    );
    final narratorRect = tester.getRect(
      find.byKey(const ValueKey<String>('world-card-narrator')),
    );
    final characterRect = tester.getRect(
      find.byKey(const ValueKey<String>('world-card-character')),
    );

    expect(timeRect.right, 390);
    expect(timeRect.left, greaterThan(tickRect.left));
    expect(tickRect.top, greaterThan(nameRect.top));
    expect(timeRect.top, moreOrLessEquals(tickRect.top));
    expect(narratorRect.top, greaterThan(tickRect.top));
    expect(characterRect.top, greaterThan(narratorRect.top));
  });

  testWidgets('uses last_active_at instead of last tick time', (
    WidgetTester tester,
  ) async {
    final item = WorldListItem.fromJson(const <String, dynamic>{
      'info': {
        'world_id': 'w_alpha',
        'world_name': 'Alpha World',
        'cover': '',
        'created_at': '2998-01-01T00:00:00Z',
        'last_active_at': '2997-01-01T00:00:00Z',
      },
      'stats': {'connect_cnt': 1},
      'last_tick': {
        'tick_no': 3,
        'sub_tick_no': 0,
        'created_at': 0,
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

    expect(item.cardTimestamp, '2997-01-01T00:00:00Z');
    expect(item.cardTickLabel, 'Tick 3');
    expect(find.text('2997-1-1'), findsOneWidget);
    expect(find.text('2998-1-1'), findsNothing);
    expect(find.text('Tick 3 · 1 Message'), findsOneWidget);
    expect(find.textContaining('Tick 3-0'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('world-card-narrator')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('world-card-character')),
      findsNothing,
    );
  });

  testWidgets('wraps a long world name instead of truncating it', (
    WidgetTester tester,
  ) async {
    final item = WorldListItem.fromJson(const <String, dynamic>{
      'info': {
        'world_id': 'w_long_name',
        'world_name':
            'A World Name That Needs More Than One Line To Be Displayed',
        'created_at': '2998-01-01T00:00:00Z',
      },
      'stats': {'connect_cnt': 1},
      'last_tick': {'tick_no': 1, 'sub_tick_no': 0},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 260, child: WorldItemCard(item: item)),
        ),
      ),
    );

    final name = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-card-name')),
    );
    expect(name.maxLines, isNull);
    expect(name.overflow, isNull);
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('world-card-name')))
          .height,
      greaterThan(16),
    );
  });

  test('treats Unix epoch last_active_at variants as empty', () {
    for (final emptyTimestamp in <Object>[0, '0', '1970-01-01T00:00:00Z']) {
      final item = WorldListItem.fromJson(<String, dynamic>{
        'info': {
          'world_id': 'w_alpha',
          'created_at': '2998-01-01T00:00:00Z',
          'last_active_at': emptyTimestamp,
        },
        'last_tick': {'created_at': '2999-01-01T00:00:00Z'},
      });

      expect(item.cardTimestamp, '2998-01-01T00:00:00Z');
    }
  });

  test('uses current stats subtick when last tick is still zero', () {
    final item = WorldListItem.fromJson({
      'info': {'world_id': 'w_subtick', 'world_name': 'Subtick World'},
      'stats': {'tick_cnt': 0, 'sub_tick_no': 1},
      'last_tick': {'tick_no': 0, 'sub_tick_no': 0},
    });

    expect(item.cardTickLabel, 'Tick 0-1');
  });
}
