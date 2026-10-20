import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_geometry_cache.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_virtual_slivers.dart';

void main() {
  testWidgets(
    'blocks retain extents across unmount, eviction, regrouping and edits',
    (tester) async {
      final cache = LocationChatGeometryCache()..report('seed', 0, 60);
      final archiveExtents = LocationChatVirtualExtentCache();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final ids = List.generate(2000, (i) => i);
      final extents = <int, ({double offset, double height})>{};
      var pinned = 1500;
      var revision = 0;
      final target = GlobalKey();
      Widget tree() => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            height: 360,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 17)),
                LocationChatVirtualSlivers(
                  extentCache: archiveExtents,
                  rows: [
                    for (final id in ids)
                      LocationChatCachedSliver(
                        cache: cache,
                        identity: id,
                        version: id == 1500 ? revision : 0,
                        pinned: id == pinned,
                        onExtent: (offset, height) =>
                            extents[id] = (offset: offset, height: height),
                        builder: (_) => SizedBox(
                          key: id == 1500 ? target : null,
                          height: id == 1500 ? 60 + revision * 40.0 : 60,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      void checkPosition() => expect(
        tester.getTopLeft(find.byKey(target)).dy,
        closeTo(extents[1500]!.offset - controller.offset, .01),
        reason: 'Nested pinned rows need their true content coordinate.',
      );
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      checkPosition();
      expect(
        find.byType(LocationChatCachedSliver).evaluate().length,
        lessThan(100),
      );
      expect(extents[1500]!.offset, closeTo(17 + 1500 * 60, .01));
      pinned = -1;
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      expect(find.byKey(target), findsNothing);
      cache.clear();
      for (final id in [700, 1500, 100, 1500]) {
        controller.jumpTo(extents[id]!.offset);
        await tester.pumpAndSettle();
        expect(extents[1500]!.offset, closeTo(17 + 1500 * 60, .01));
        if (id == 1500) checkPosition();
      }
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      ids.insert(0, -1); // Moves existing rows between ordinal blocks.
      pinned = 1500;
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      checkPosition();
      expect(extents[1500]!.offset, closeTo(17 + 1501 * 60, .01));
      revision++;
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      checkPosition();
      expect(extents[1500]!.height, 100);
      expect(extents[1501]!.offset - extents[1500]!.offset, 100);
      pinned = -1;
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      cache.clear();
      controller.jumpTo(extents[1500]!.offset);
      await tester.pumpAndSettle();
      checkPosition();
      expect(extents[1500]!.height, 100);
      expect(cache.length, lessThanOrEqualTo(512));
      final savedOffset = extents[1500]!.offset;
      await tester.pumpWidget(const SizedBox.shrink());
      cache.clear();
      pinned = 1500;
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      checkPosition();
      expect(extents[1500]!.offset, savedOffset);
      expect(extents[1500]!.height, 100);
      expect(archiveExtents.length, ids.length);
      ids.removeRange(0, 1900);
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      expect(archiveExtents.length, 101);
      expect(find.byKey(target), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      archiveExtents.clear();
      expect(archiveExtents.length, 0);
    },
  );
}
