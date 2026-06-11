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
    final worldThumbnail = find
        .byKey(const ValueKey<String>('genesis-world-list-thumbnail-skeleton'))
        .first;
    expect(tester.getSize(worldThumbnail), const Size(60, 60));

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
    final popularThumbnail = find
        .byKey(
          const ValueKey<String>(
            'genesis-popular-origin-list-thumbnail-skeleton',
          ),
        )
        .first;
    expect(tester.getSize(popularThumbnail), const Size(60, 60));
    final popularHero = find
        .byKey(const ValueKey<String>('genesis-popular-origin-hero-skeleton'))
        .first;
    expect(tester.getSize(popularHero), const Size(107, 160.5));

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
    expect(coverSize.height, closeTo(coverSize.width * 1.5, 0.01));
  });
}
