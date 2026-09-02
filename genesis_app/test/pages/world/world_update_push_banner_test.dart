import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/world/world_update_push_banner.dart';

void main() {
  testWidgets('world update push notices are shown sequentially', (
    WidgetTester tester,
  ) async {
    const notices = <WorldContentUpdateNotice>[
      WorldContentUpdateNotice(
        kind: WorldContentUpdateKind.location,
        entityId: 'loc-new',
        name: 'New Harbor',
        targetLocationId: 'loc-new',
        avatarUrl: '',
        tickCount: 3,
      ),
      WorldContentUpdateNotice(
        kind: WorldContentUpdateKind.character,
        entityId: 'char-new',
        name: 'New Wanderer',
        targetLocationId: 'loc-new',
        avatarUrl: '',
        tickCount: 3,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              WorldUpdatePushBannerQueue(
                top: 12,
                revision: 1,
                notices: notices,
                displayDuration: Duration(milliseconds: 50),
                transitionDuration: Duration(milliseconds: 20),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('New location'), findsOneWidget);
    expect(find.text('New Harbor'), findsOneWidget);
    expect(find.text('New Wanderer'), findsNothing);

    await tester.pump(const Duration(milliseconds: 55));
    await tester.pump(const Duration(milliseconds: 25));

    expect(find.text('New Harbor'), findsNothing);
    expect(find.text('New character'), findsOneWidget);
    expect(find.text('New Wanderer'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 55));
    await tester.pump(const Duration(milliseconds: 25));

    expect(
      find.byKey(const ValueKey<String>('world-update-push-banner')),
      findsNothing,
    );
  });
}
