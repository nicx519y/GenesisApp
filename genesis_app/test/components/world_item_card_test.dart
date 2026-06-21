import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/home/world_item_card.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_image_radii.dart';

void main() {
  testWidgets('renders last progress time from last tick created_at', (
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
      'last_tick': {
        'tick_no': 3,
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
    expect(
      _horizontalGap(
        tester,
        find.byIcon(MyFlutterApp.lastProgress),
        find.text('Last Progress'),
      ),
      8,
    );
    expect(find.text('2999-1-1'), findsOneWidget);
    expect(find.text('Tick 3 · Day 3, 08:00'), findsOneWidget);
    expect(find.text('The city chooses a new route.'), findsOneWidget);

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

    final titleLeft = tester.getTopLeft(find.text('Alpha World')).dx;
    final bodyLeft = tester
        .getTopLeft(find.text('The city chooses a new route.'))
        .dx;
    expect(bodyLeft, lessThan(titleLeft));
  });
}

double _horizontalGap(WidgetTester tester, Finder left, Finder right) {
  final leftRect = tester.getRect(left);
  final rightRect = tester.getRect(right);
  return rightRect.left - leftRect.right;
}
