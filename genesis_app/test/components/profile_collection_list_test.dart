import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/me/profile_collection_list.dart';
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

    await tester.drag(find.byType(ListView), const Offset(0, -90));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
