import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/discuss/story_badge.dart';

void main() {
  testWidgets('renders tick chip with shared discuss style', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: DiscussStoryBadge(count: 124))),
      ),
    );

    final badge = find.byType(DiscussStoryBadge);
    final container = tester.widget<Container>(
      find.descendant(of: badge, matching: find.byType(Container)),
    );
    final decoration = container.decoration! as BoxDecoration;
    final borderRadius = decoration.borderRadius! as BorderRadius;
    final padding = container.padding! as EdgeInsetsDirectional;
    final icon = tester.widget<Icon>(find.byType(Icon));
    final text = tester.widget<Text>(find.text('124'));

    expect(decoration.color, const Color(0xFFFEF3C7));
    expect(borderRadius.topLeft.x, 5);
    expect(padding.start, 5);
    expect(padding.end, 7);
    expect(padding.top, 2);
    expect(padding.bottom, 2);
    expect(icon.size, 9);
    expect(icon.color, const Color(0xFF92400E));
    expect(text.style?.fontSize, 11);
    expect(text.style?.fontWeight, FontWeight.w500);
    expect(text.style?.color, const Color(0xFF92400E));
  });
}
