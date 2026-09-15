import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Measures the gem card's note against the width it actually gets, so the
/// copy can be chosen knowing where it wraps. The card hangs under the benefit
/// text column, and every entry point insets the page by 16.
void main() {
  const pageInset = 16.0; // wallet page, purchase sheet and the login gate
  const gutter = 31.0; // 20 check column + 11 gap
  const cardGap = 10.0;
  const cardPadding = 24.0; // 12 either side

  double noteWidth(double screenWidth) =>
      (screenWidth - pageInset * 2 - gutter - cardGap) / 2 - cardPadding;

  const screens = <double>[320, 360, 390, 430];
  const notes = <String>[
    // Shipped, then the design's own longer wording they were cut from.
    'extra, daily check-in',
    'claimed monthly',
    'extra, every daily check-in',
    'claimed once a month',
  ];
  const sizes = <double>[12];

  testWidgets('gem card note line count', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
      await font.load();
    });

    final buffer = StringBuffer();
    for (final screen in screens) {
      final width = noteWidth(screen);
      buffer.writeln('screen $screen -> note box ${width.toStringAsFixed(1)}');
      for (final size in sizes) {
        for (final note in notes) {
          final painter = TextPainter(
            text: TextSpan(
              text: note,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: size,
                height: 1.3,
                fontWeight: FontWeight.w400,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: width);
          final lines = painter.computeLineMetrics().length;
          final intrinsic = (TextPainter(
            text: painter.text,
            textDirection: TextDirection.ltr,
          )..layout()).width;
          buffer.writeln(
            '  ${size.toStringAsFixed(0)}px  lines=$lines  '
            'needs=${intrinsic.toStringAsFixed(1)}  "$note"',
          );
        }
      }
    }
    debugPrint(buffer.toString());
  });
}
