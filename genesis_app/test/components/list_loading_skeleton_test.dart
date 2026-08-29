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
          body: GenesisListLoadingSkeleton.originGrid(itemCount: 2),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('genesis-origin-grid-skeleton')),
      findsOneWidget,
    );
    final originGridPadding = tester.widget<SliverPadding>(
      find.byType(SliverPadding),
    );
    expect(originGridPadding.padding, const EdgeInsets.fromLTRB(2, 5, 2, 0));
    final firstItem = find
        .byKey(const ValueKey<String>('genesis-origin-grid-item-skeleton'))
        .first;
    final itemSize = tester.getSize(firstItem);
    expect(itemSize.width, greaterThan(100));
    expect(itemSize.height, closeTo(itemSize.width * 1.5 + 67, 0.01));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF111111),
      ),
      findsNothing,
    );
  });
}
