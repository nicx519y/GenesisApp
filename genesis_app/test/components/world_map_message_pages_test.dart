import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map_contract.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_message_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initial bubble and timed page changes preserve emoji', (
    tester,
  ) async {
    final content = List.filled(101, '👨‍👩‍👧‍👦').join();
    await tester.pumpWidget(
      MaterialApp(
        home: TilemapMessageBubblePlayback(
          messageBubbles: [
            WorldMapMessageBubble(characterId: 'c', content: content),
          ],
          visibleCharacterIds: const {'c'},
          paused: false,
          builder: (context, bubble) => Text(bubble?.content ?? ''),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.byType(Text).first).data!;
      expect(text.characters.every((c) => c == '👨‍👩‍👧‍👦'), isTrue);
      await tester.pump(tilemapMessageBubbleDisplayDuration);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final grapheme in ['😀', '👨‍👩‍👧‍👦', '🇨🇳', 'e\u0301']) {
    test('pagination preserves complete $grapheme graphemes', () {
      final content = List.filled(101, grapheme).join();
      final pages = splitWorldMapMessageBubblePages(content);
      expect(pages.length, greaterThan(1));
      expect(pages.join(), content);
      for (final page in pages) {
        expect(page, isNotEmpty);
        expect(
          page.characters.every((character) => character == grapheme),
          isTrue,
        );
      }
    });
  }

  test('malformed input is repaired before measurement', () {
    expect(splitWorldMapMessageBubblePages('a\uD800b\uDC00'), ['a�b�']);
  });

  test('an oversized grapheme still makes progress', () {
    final pages = splitWorldMapMessageBubblePages(
      '👨‍👩‍👧‍👦🇨🇳',
      textScaler: TextScaler.linear(100),
    );
    expect(pages, ['👨‍👩‍👧‍👦', '🇨🇳']);
  });

  testWidgets('width measurement repairs malformed input', (tester) async {
    late double width;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            width = resolveWorldMapMessageBubbleWidth(context, 'bad\uD800');
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(width, inInclusiveRange(36, worldMapMessageBubbleMaxWidth));
  });
}
