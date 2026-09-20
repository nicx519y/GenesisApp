import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_geometry_cache.dart';

void main() {
  test('geometry versions use values, stable estimates and protected LRU', () {
    final cache = LocationChatGeometryCache(capacity: 3);
    cache.report('a', (390, 1.0), 60);
    expect(cache.read('a', (390, 1.0)), 60);
    cache.reportBubbleBottom('a', 48);
    expect(cache.bubbleBottom('a', (390, 1.0)), 48);
    expect(cache.bubbleBottom('a', (390, 1.2)), isNull);
    expect(cache.read('a', (391, 1.0)), isNull);
    expect(cache.read('a', (390, 1.2)), isNull);
    expect(cache.extent('unknown', 1, 600), 60);
    cache.report('b', 1, 180);
    expect(cache.extent('unknown', 1, 300), 60);
    cache.protectedKeys.add('a');
    cache.report('c', 1, 70);
    cache.report('d', 1, 80);
    expect(cache.length, 3);
    expect(cache.read('a', (390, 1.0)), 60);
    expect(cache.read('b', 1), isNull);
  });

  for (final count in [200, 2000]) {
    testWidgets(
      'only visible rows and the active offscreen target layout ($count)',
      (tester) async {
        final cache = LocationChatGeometryCache();
        final layouts = <int, int>{};
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final children = List.generate(
          count,
          (i) => _LayoutCounter(
            onLayout: () => layouts.update(i, (n) => n + 1, ifAbsent: () => 1),
          ),
        );
        var revision = 0;
        var height = 360.0;
        Widget build() => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              height: height,
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  for (var i = 0; i < count; i++)
                    LocationChatCachedSliver(
                      key: ValueKey(i),
                      cache: cache,
                      identity: i,
                      version: (390, i == count - 1 ? revision : 0),
                      pinned: i == count - 1,
                      builder: (_) => i == count - 1
                          ? SizedBox(height: 60.0 + revision)
                          : children[i],
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpWidget(build());
        expect(layouts.length, lessThan(30));
        expect(layouts.containsKey(count ~/ 2), isFalse);
        final initial = Map.of(layouts);
        for (var frame = 0; frame < 20; frame++) {
          revision++;
          await tester.pumpWidget(build());
        }
        // Unchanged paragraphs keep their RenderObject layout; chunks only
        // change the explicitly pinned row, not every loaded message.
        expect(layouts, initial);
        height = 200;
        await tester.pumpWidget(build());
        expect(layouts.keys.every((i) => initial.containsKey(i)), isTrue);
        expect(cache.length, lessThanOrEqualTo(512));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _LayoutCounter extends LeafRenderObjectWidget {
  const _LayoutCounter({required this.onLayout});
  final VoidCallback onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) => _Counter(onLayout);
}

class _Counter extends RenderBox {
  _Counter(this.onLayout);
  final VoidCallback onLayout;
  @override
  void performLayout() {
    onLayout();
    size = constraints.constrain(const Size(390, 60));
  }
}
