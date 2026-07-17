import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/recent_chat_marker.dart';

void main() {
  testWidgets('activity tags use distinct icons and colors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RecentChatTag(label: 'Last Message'),
              RecentChatTag(label: 'Last Tick'),
              RecentChatTag(label: 'Last Launch'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(RecentChatIcon), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    expect(_tagColor(tester, 'last-message'), const Color(0xFFE8F5EF));
    expect(_tagColor(tester, 'last-tick'), const Color(0xFFEAF2FF));
    expect(_tagColor(tester, 'last-launch'), const Color(0xFFFFF0E3));
  });
}

Color? _tagColor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey<String>('recent-activity-tag-$key')),
  );
  return (container.decoration as BoxDecoration?)?.color;
}
