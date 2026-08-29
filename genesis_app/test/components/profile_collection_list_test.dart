import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/me/profile_collection_list.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  testWidgets('pull to refresh uses the page surface and keeps its shadow', (
    WidgetTester tester,
  ) async {
    const pageSurface = Color(0xFFF8F8F8);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: pageSurface),
        home: Scaffold(
          body: ProfileCollectionList(
            items: const [],
            emptyText: 'Empty',
            onRefresh: () async {},
          ),
        ),
      ),
    );

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    expect(indicator.backgroundColor, pageSurface);
    expect(indicator.elevation, greaterThan(0));
  });

  testWidgets('uses the full screen DPR for profile collection images', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Scaffold(
            body: ProfileCollectionList(
              items: const [
                GenesisProfileCollectionItemData(
                  imageUrl: '',
                  title: 'Origin',
                  subtitle: 'World seed',
                ),
              ],
              emptyText: 'Empty',
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<GenesisListImage>(find.byType(GenesisListImage))
          .maxDevicePixelRatio,
      3,
    );
  });

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

  testWidgets('supports the shared My Worlds card geometry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: ProfileCollectionList(
              topPadding: 10,
              itemSpacing: 30,
              items: [
                GenesisProfileCollectionItemData(
                  imageUrl: '',
                  title: 'World One',
                  subtitle: 'WID: wid_1\nOwner: Owner One',
                  statsText: 'Tick 1 · 2 Messages',
                  useWorldCardLayout: true,
                ),
              ],
              emptyText: 'Empty',
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<GenesisListImage>(
      find.byType(GenesisListImage),
    );
    expect(image.width, 60);
    expect(image.height, 90);
    final subtitle = tester.widget<Text>(find.text('Owner: Owner One'));
    expect(subtitle.style?.fontSize, 12);
    expect(subtitle.style?.height, 1.2);
    expect(subtitle.style?.color, const Color(0xFF888888));
    final stats = tester.widget<Text>(find.text('Tick 1 · 2 Messages'));
    expect(stats.style?.fontSize, 12);
    expect(stats.style?.height, 1.2);
    expect(stats.style?.color, const Color(0xFF666666));
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(
      list.padding,
      const EdgeInsets.only(
        top: 10,
        bottom: 16 + ProfileCollectionList.minSystemNavigationBottomPadding,
      ),
    );
    final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    expect(boxes.any((box) => box.width == 14), isTrue);
    expect(boxes.where((box) => box.height == 4), hasLength(3));
  });

  testWidgets('supports the shared Worldo card geometry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: GenesisProfileCollectionListItem(
              item: GenesisProfileCollectionItemData(
                imageUrl: '',
                title: 'Worldo One',
                subtitle: 'OID: oid_1\nLatest Version: V1',
                stats: [
                  GenesisProfileCollectionStat(
                    iconAsset: characterStatIconAsset,
                    value: 1,
                  ),
                ],
                useOriginCardLayout: true,
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<GenesisListImage>(
      find.byType(GenesisListImage),
    );
    expect(image.width, 60);
    expect(image.height, 90);
    final oid = tester.widget<Text>(find.text('OID: oid_1'));
    expect(find.textContaining('Originator:'), findsNothing);
    final version = tester.widget<Text>(find.text('Latest Version: V1'));
    expect(oid.style?.color, const Color(0xFF888888));
    expect(oid.style?.height, 1.2);
    expect(version.style?.color, const Color(0xFF888888));
    expect(version.style?.height, 1.2);
    final stat = tester.widget<Text>(find.text('1'));
    expect(stat.style?.color, const Color(0xFF666666));
    expect(stat.style?.height, 1.2);
    final statIcon = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(statIcon.width, 12);
    expect(statIcon.height, 12);
    expect(
      statIcon.colorFilter,
      const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn),
    );
    final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    expect(boxes.any((box) => box.width == 14), isTrue);
    expect(boxes.where((box) => box.height == 4), hasLength(3));
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
    expect(svg.width, moreOrLessEquals(11));
    expect(svg.height, moreOrLessEquals(11));
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('edit action is independent from the collection item tap', (
    WidgetTester tester,
  ) async {
    var itemTapCount = 0;
    var editTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileCollectionList(
            items: [
              GenesisProfileCollectionItemData(
                animationKey: 'oid_1',
                imageUrl: '',
                title: 'Editable Worldo',
                subtitle: 'World seed',
                onTap: () => itemTapCount += 1,
                onEdit: () => editTapCount += 1,
              ),
            ],
            emptyText: 'Empty',
          ),
        ),
      ),
    );

    final editAction = find.byKey(
      const ValueKey<String>('profile-collection-item-edit-oid_1'),
    );
    expect(editAction, findsOneWidget);
    final editIcon = tester.widget<SvgPicture>(
      find.descendant(of: editAction, matching: find.byType(SvgPicture)),
    );
    expect(editIcon.bytesLoader, isA<SvgAssetLoader>());
    expect(editIcon.width, 16);
    expect(editIcon.height, 16);

    await tester.tap(editAction);
    expect(editTapCount, 1);
    expect(itemTapCount, 0);

    await tester.tap(
      find.descendant(
        of: find.byType(GenesisProfileCollectionListItem),
        matching: find.byType(InkWell),
      ),
    );
    expect(itemTapCount, 1);
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
