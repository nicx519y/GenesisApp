import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_message_bubble.dart';
import 'package:genesis_flutter_android/components/world_map_contract.dart';

void main() {
  test('Tilemap bubble pagination follows the legacy playback rules', () {
    final content = List<String>.filled(40, 'word').join(' ');
    final pages = tilemapMessageBubblePages(content);

    expect(pages, hasLength(greaterThan(1)));
    expect(pages.join(' '), content);
  });

  test('Tilemap bubble anchor targets the matching wrapped avatar', () {
    final anchor = tilemapMessageBubbleAvatarTopLeft(
      locationBubbleAnchor: const Offset(200, 100),
      avatarIndex: 3,
      avatarCount: 4,
    );

    expect(anchor.dx, 179);
    expect(anchor.dy, 152);
  });

  test('Tilemap bubble anchor includes wrapped location label overflow', () {
    final anchor = tilemapMessageBubbleAvatarTopLeft(
      locationBubbleAnchor: const Offset(200, 100),
      avatarIndex: 0,
      avatarCount: 1,
      locationLabelVerticalOverflow: 14.4,
    );

    expect(anchor.dy, 120.4);
  });

  testWidgets('Tilemap bubble playback shows a gap and loops', (tester) async {
    const bubble = WorldMapMessageBubble(
      characterId: 'char_1',
      content: 'Tilemap hello',
    );

    Widget harness({bool paused = false, bool frozen = false}) {
      return MaterialApp(
        home: TilemapMessageBubblePlayback(
          messageBubbles: const [bubble],
          visibleCharacterIds: const {'char_1'},
          paused: paused,
          frozen: frozen,
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

  testWidgets('Tilemap bubble freeze keeps the current bubble visible', (
    tester,
  ) async {
    const bubble = WorldMapMessageBubble(
      characterId: 'char_1',
      content: 'Frozen Tilemap bubble',
    );

    Widget harness({required bool frozen}) {
      return MaterialApp(
        home: TilemapMessageBubblePlayback(
          messageBubbles: const [bubble],
          visibleCharacterIds: const {'char_1'},
          paused: false,
          frozen: frozen,
          builder: (context, activeBubble) {
            return Text(activeBubble?.content ?? 'hidden');
          },
        ),
      );
    }

    await tester.pumpWidget(harness(frozen: true));
    await tester.pump(tilemapMessageBubbleDisplayDuration * 2);
    expect(find.text('Frozen Tilemap bubble'), findsOneWidget);

    await tester.pumpWidget(harness(frozen: false));
    await tester.pump(tilemapMessageBubbleDisplayDuration);
    expect(find.text('hidden'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tilemap bubble restarts its timer after reactivation', (
    tester,
  ) async {
    const bubble = WorldMapMessageBubble(
      characterId: 'char_1',
      content: 'Reactivated Tilemap bubble',
    );
    final playbackKey = GlobalKey();

    Widget harness({required bool movePlayback}) {
      final playback = TilemapMessageBubblePlayback(
        key: playbackKey,
        messageBubbles: const [bubble],
        visibleCharacterIds: const {'char_1'},
        paused: false,
        builder: (context, activeBubble) {
          return Text(activeBubble?.content ?? 'hidden');
        },
      );
      return MaterialApp(
        home: movePlayback
            ? Align(alignment: Alignment.bottomCenter, child: playback)
            : Padding(padding: EdgeInsets.zero, child: playback),
      );
    }

    await tester.pumpWidget(harness(movePlayback: false));
    await tester.pump(
      tilemapMessageBubbleDisplayDuration - const Duration(seconds: 1),
    );

    await tester.pumpWidget(harness(movePlayback: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reactivated Tilemap bubble'), findsOneWidget);

    await tester.pump(
      tilemapMessageBubbleDisplayDuration - const Duration(seconds: 1),
    );
    expect(find.text('hidden'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tilemap bubble marks only continuation pages to keep width', (
    tester,
  ) async {
    final content = '${List<String>.filled(29, 'word').join(' ')} tail';
    WorldMapMessageBubble? activeBubble;

    await tester.pumpWidget(
      MaterialApp(
        home: TilemapMessageBubblePlayback(
          messageBubbles: [
            WorldMapMessageBubble(characterId: 'char_1', content: content),
          ],
          visibleCharacterIds: const {'char_1'},
          paused: false,
          builder: (context, active) {
            activeBubble = active;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(activeBubble?.preservePageWidth, isFalse);

    await tester.pump(tilemapMessageBubbleDisplayDuration);
    expect(activeBubble?.content, isNotEmpty);
    expect(activeBubble?.preservePageWidth, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tilemap character bubble adapts short single-page content', (
    tester,
  ) async {
    const text = 'who are you';

    Widget harness({bool preservePageWidth = false}) {
      return MaterialApp(
        home: SizedBox(
          width: 300,
          height: 500,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TilemapCharacterMessageBubble(
                text: text,
                avatarTopLeft: const Offset(120, 100),
                viewportWidth: 300,
                preservePageWidth: preservePageWidth,
                onTap: null,
              ),
            ],
          ),
        ),
      );
    }

    const bodyKey = ValueKey<String>('tilemap-character-message-bubble-body');
    await tester.pumpWidget(harness());
    final adaptiveWidth = tester.getSize(find.byKey(bodyKey)).width;
    final adaptiveTextHeight = tester.getSize(find.text(text)).height;

    await tester.pumpWidget(harness(preservePageWidth: true));
    final preservedWidth = tester.getSize(find.byKey(bodyKey)).width;

    expect(adaptiveWidth, lessThan(worldMapMessageBubbleMaxWidth));
    expect(adaptiveTextHeight, lessThan(20));
    expect(preservedWidth, worldMapMessageBubbleMaxWidth);
  });

  testWidgets(
    'Tilemap adaptive bubble keeps fitting Chinese text on one line',
    (tester) async {
      const text = '艾达正在检查店铺门口。';
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            height: 500,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                TilemapCharacterMessageBubble(
                  text: text,
                  avatarTopLeft: Offset(120, 100),
                  viewportWidth: 300,
                  onTap: null,
                ),
              ],
            ),
          ),
        ),
      );

      final textSize = tester.getSize(find.text(text));
      final bodySize = tester.getSize(
        find.byKey(
          const ValueKey<String>('tilemap-character-message-bubble-body'),
        ),
      );

      expect(textSize.height, lessThan(20));
      expect(bodySize.width, lessThan(worldMapMessageBubbleMaxWidth));
    },
  );

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
                preservePageWidth: true,
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
                  preservePageWidth: true,
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
                  preservePageWidth: true,
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
