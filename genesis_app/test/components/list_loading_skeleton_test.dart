import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/list_loading_skeleton.dart';

void main() {
  testWidgets('renders list loading skeleton variants', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisListLoadingSkeleton.worldList(itemCount: 2),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('genesis-world-list-skeleton')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisListLoadingSkeleton.popularOriginList(itemCount: 2),
        ),
      ),
    );
    expect(
      find.byKey(
        const ValueKey<String>('genesis-popular-origin-list-skeleton'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisListLoadingSkeleton.originGrid(itemCount: 2),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('genesis-origin-grid-skeleton')),
      findsOneWidget,
    );
    final firstCover = find
        .byKey(const ValueKey<String>('genesis-origin-grid-cover-skeleton'))
        .first;
    final coverSize = tester.getSize(firstCover);
    expect(coverSize.width, greaterThan(100));
    expect(coverSize.height, 220);
  });
}
