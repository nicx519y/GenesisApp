import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_detail_tags.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('detail tags stay within two rows at text scale $scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(scale),
                boldText: true,
              ),
              child: const DefaultTextStyle(
                style: TextStyle(letterSpacing: 2, wordSpacing: 3),
                child: SizedBox(
                  width: 220,
                  child: GenesisDetailTags(
                    tags: [
                      'Fantasy',
                      'Adventure',
                      '一个非常长的中文标签，用来验证单个标签溢出的处理',
                      'Mystery',
                      'Romance',
                      'Science fiction',
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final labels = find.descendant(
        of: find.byType(GenesisDetailTags),
        matching: find.byType(Text),
      );
      final tops = <double>{};
      for (final element in labels.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        tops.add(rect.top);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(220));
      }
      final paragraphs = find.descendant(
        of: find.byType(GenesisDetailTags),
        matching: find.byType(RichText),
      );
      for (final element in paragraphs.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(paragraph.size.width),
        );
      }
      expect(find.text('一个非常长的中文标签，用来验证单个标签溢出的处理'), findsNothing);
      expect(tops.length, 2);
      expect(labels.evaluate().length, lessThan(6));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('blank detail tags occupy no space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GenesisDetailTags(tags: ['', '  ']),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(GenesisDetailTags)), Size.zero);
  });
}
