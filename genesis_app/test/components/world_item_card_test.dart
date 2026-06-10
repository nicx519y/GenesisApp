import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/home/world_item_card.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';

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
    expect(find.text('just now'), findsOneWidget);
    expect(find.text('The city chooses a new route.'), findsOneWidget);

    final thumbnails = tester.widgetList<GenesisListImage>(
      find.byType(GenesisListImage),
    );
    expect(
      thumbnails.any(
        (image) =>
            image.width == 60 &&
            image.height == 60 &&
            image.borderRadius == BorderRadius.zero,
      ),
      isTrue,
    );
  });
}
