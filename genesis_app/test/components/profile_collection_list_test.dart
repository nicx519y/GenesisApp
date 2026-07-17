import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/me/profile_collection_list.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  testWidgets('renders collection items without borders', (
    WidgetTester tester,
  ) async {
    final items = List<GenesisProfileCollectionItemData>.generate(
      8,
      (index) => GenesisProfileCollectionItemData(
        imageUrl: '',
        title: 'Origin $index',
        subtitle: 'World seed $index',
        onTap: () {},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 140,
            child: ProfileCollectionList(items: items, emptyText: 'Empty'),
          ),
        ),
      ),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.clipBehavior, Clip.hardEdge);
    expect(
      listView.padding,
      const EdgeInsets.only(
        top: 12,
        bottom: 16 + ProfileCollectionList.minSystemNavigationBottomPadding,
      ),
    );

    final firstItem = find.byType(GenesisProfileCollectionListItem).first;
    final itemMaterial = find
        .descendant(of: firstItem, matching: find.byType(Material))
        .evaluate()
        .map((element) => element.widget)
        .whereType<Material>()
        .firstWhere((material) => material.shape is RoundedRectangleBorder);
    final shape = itemMaterial.shape as RoundedRectangleBorder;
    expect(shape.side, BorderSide.none);
    expect(shape.borderRadius, const BorderRadius.all(Radius.circular(14)));
    final imageTop = tester.getTopLeft(find.byType(GenesisListImage).first).dy;
    final titleTop = tester.getTopLeft(find.text('Origin 0')).dy;
    expect(titleTop, closeTo(imageTop, 0.1));

    await tester.drag(find.byType(ListView), const Offset(0, -90));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders profile collection stat assets through svg', (
    WidgetTester tester,
  ) async {
    final items = [
      GenesisProfileCollectionItemData(
        imageUrl: '',
        title: 'Origin',
        subtitle: 'World seed',
        stats: const [
          GenesisProfileCollectionStat(
            iconAsset: characterStatIconAsset,
            preserveIconAssetColor: true,
            value: 7,
          ),
        ],
        onTap: () {},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 140,
            child: ProfileCollectionList(items: items, emptyText: 'Empty'),
          ),
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, moreOrLessEquals(13.75));
    expect(svg.height, moreOrLessEquals(13.75));
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('notifies after a collection item finishes collapsing', (
    WidgetTester tester,
  ) async {
    var isCollapsing = false;
    var collapsedCount = 0;
    late StateSetter updateHost;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return ProfileCollectionList(
                items: [
                  GenesisProfileCollectionItemData(
                    animationKey: 'w_delete',
                    imageUrl: '',
                    title: 'Deleted World',
                    subtitle: 'World subtitle',
                    isCollapsing: isCollapsing,
                    onCollapsed: () => collapsedCount += 1,
                  ),
                ],
                emptyText: 'Empty',
              );
            },
          ),
        ),
      ),
    );

    updateHost(() => isCollapsing = true);
    await tester.pump();
    expect(
      tester
          .widget<GenesisProfileCollectionListItem>(
            find.byType(GenesisProfileCollectionListItem),
          )
          .item
          .isCollapsing,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 500));

    final itemFinder = find.byType(GenesisProfileCollectionListItem);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: itemFinder, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, greaterThan(0.6));
    expect(opacity.opacity, lessThan(1));

    await tester.pumpAndSettle();

    expect(collapsedCount, 1);
    expect(find.text('Deleted World'), findsNothing);
  });
}
