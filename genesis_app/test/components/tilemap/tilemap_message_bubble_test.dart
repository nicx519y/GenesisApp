import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_message_bubble.dart';
import 'package:genesis_flutter_android/components/world_map_contract.dart';

void main() {
  test('Tilemap bubble pagination follows the legacy playback rules', () {
    final content = List<String>.filled(40, 'word').join(' ');
    final pages = tilemapMessageBubblePages(content);

    expect(pages, hasLength(greaterThan(1)));
    expect(pages.every((page) => page.length <= 144), isTrue);
    expect(pages.join(' '), content);
  });

  test('Tilemap bubble anchor targets the matching wrapped avatar', () {
    final anchor = tilemapMessageBubbleAvatarTopLeft(
      locationBubbleAnchor: const Offset(200, 100),
      avatarIndex: 3,
      avatarCount: 4,
    );

    expect(anchor.dx, 179);
    expect(anchor.dy, closeTo(182.93, 0.001));
  });

  testWidgets('Tilemap bubble playback shows a gap and loops', (tester) async {
    const bubble = WorldMapMessageBubble(
      characterId: 'char_1',
      content: 'Tilemap hello',
    );

    Widget harness({bool paused = false}) {
      return MaterialApp(
        home: TilemapMessageBubblePlayback(
          messageBubbles: const [bubble],
          visibleCharacterIds: const {'char_1'},
          paused: paused,
          builder: (context, activeBubble) {
            return Text(activeBubble?.content ?? 'hidden');
          },
        ),
      );
    }

    await tester.pumpWidget(harness());
    expect(find.text('Tilemap hello'), findsOneWidget);

    await tester.pump(tilemapMessageBubbleDisplayDuration);
    expect(find.text('hidden'), findsOneWidget);

    await tester.pump(tilemapMessageBubbleGapDuration);
    expect(find.text('Tilemap hello'), findsOneWidget);

    await tester.pumpWidget(harness(paused: true));
    expect(find.text('hidden'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tilemap character bubble first pins its body to the viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 500,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TilemapCharacterMessageBubble(
                text: 'Near the edge',
                avatarTopLeft: Offset(50, 100),
                viewportWidth: 300,
                onTap: null,
              ),
            ],
          ),
        ),
      ),
    );

    final body = find.byKey(
      const ValueKey<String>('tilemap-character-message-bubble-body'),
    );
    expect(body, findsOneWidget);
    expect(tester.getTopLeft(body).dx, 8);
  });

  testWidgets(
    'Tilemap character bubble follows an avatar past the left pointer limit',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            height: 500,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                TilemapCharacterMessageBubble(
                  text: 'Past the left edge',
                  avatarTopLeft: Offset(0, 100),
                  viewportWidth: 300,
                  onTap: null,
                ),
              ],
            ),
          ),
        ),
      );

      final bodyRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tilemap-character-message-bubble-body'),
        ),
      );
      final pointerRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tilemap-character-message-bubble-pointer'),
        ),
      );

      expect(bodyRect.left, lessThan(8));
      expect(
        pointerRect.center.dx - bodyRect.left,
        closeTo(bodyRect.width / 4, 0.01),
      );
      expect(pointerRect.center.dx, closeTo(21, 0.01));
    },
  );

  testWidgets(
    'Tilemap character bubble follows an avatar past the right pointer limit',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            height: 500,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                TilemapCharacterMessageBubble(
                  text: 'Past the right edge',
                  avatarTopLeft: Offset(270, 100),
                  viewportWidth: 300,
                  onTap: null,
                ),
              ],
            ),
          ),
        ),
      );

      final bodyRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tilemap-character-message-bubble-body'),
        ),
      );
      final pointerRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tilemap-character-message-bubble-pointer'),
        ),
      );

      expect(bodyRect.right, greaterThan(292));
      expect(
        pointerRect.center.dx - bodyRect.left,
        closeTo(bodyRect.width * 3 / 4, 0.01),
      );
      expect(pointerRect.center.dx, closeTo(291, 0.01));
    },
  );
}
