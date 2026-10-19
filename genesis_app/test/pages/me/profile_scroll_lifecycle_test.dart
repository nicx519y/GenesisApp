import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/me/user_profile_content.dart';

void main() {
  testWidgets('detail return preserves the profile scroll position', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: UserProfileContent(data: _data(20), isActiveListenable: active),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    final nested = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    final outer = nested.outerController.position;
    final inner = nested.innerController.position;
    final outerOffset = outer.pixels;
    final innerOffset = inner.pixels;
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detail')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(nested.outerController.position, same(outer));
    expect(nested.innerController.position, same(inner));
    expect(outer.pixels, outerOffset);
    expect(inner.pixels, innerOffset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final depart in [false, true]) {
    testWidgets(
      'profile navigation waits for inner dimensions, depart=$depart',
      (tester) async {
        final active = ValueNotifier(true);
        final reselected = ValueNotifier(0);
        addTearDown(active.dispose);
        addTearDown(reselected.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserProfileContent(
                data: _data(20),
                isActiveListenable: active,
                reselectionListenable: reselected,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        final nested = tester.state<NestedScrollViewState>(
          find.byType(NestedScrollView),
        );
        final outer = nested.outerController.position;
        expect(outer.pixels, greaterThan(outer.minScrollExtent));
        final pending = nested.innerController.createScrollPosition(
          const ClampingScrollPhysics(),
          outer.context,
          null,
        );
        nested.innerController.attach(pending);
        try {
          if (depart) {
            active.value = false;
          } else {
            reselected.value++;
          }
          expect(tester.takeException(), isNull);
        } finally {
          nested.innerController.detach(pending);
          pending.dispose();
        }
        await tester.pumpAndSettle();
        if (depart) expect(outer.pixels, outer.minScrollExtent);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final switchTab in [false, true]) {
    testWidgets(
      'unlaid inner position during ballistic scroll, switch=$switchTab',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserProfileContent(
                data: _data(20),
                originTabLabel: 'Worldo',
                worldTabLabel: 'Playing',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.fling(
          find.byType(CustomScrollView).last,
          const Offset(0, -80),
          1200,
        );
        final nested = tester.state<NestedScrollViewState>(
          find.byType(NestedScrollView),
        );
        final outer = nested.outerController.position;
        // The new Tab's Scrollable attaches before its first content-dimensions pass.
        // Reproduce that exact framework phase deterministically rather than relying
        // on platform-dependent frame timing.
        expect(outer.isScrollingNotifier.value, isTrue);
        if (switchTab) {
          tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(1);
        }
        final pending = nested.innerController.createScrollPosition(
          const ClampingScrollPhysics(),
          outer.context,
          null,
        );
        nested.innerController.attach(pending);
        expect(pending.hasContentDimensions, isFalse);
        try {
          void relayout() => outer.applyContentDimensions(
            outer.minScrollExtent,
            outer.maxScrollExtent + 1,
          );
          if (switchTab) {
            expect(relayout, returnsNormally);
          } else {
            Object? failure;
            StackTrace? stack;
            try {
              relayout();
            } catch (error, trace) {
              failure = error;
              stack = trace;
            }
            expect(failure.toString(), contains('Null check operator'));
            expect(
              stack.toString(),
              contains('_NestedScrollCoordinator._getMetrics'),
            );
          }
        } finally {
          nested.innerController.detach(pending);
          pending.dispose();
        }
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'profile retains its inner position across empty loading and data',
    (tester) async {
      var count = 0;
      var loading = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return UserProfileContent(
                  data: _data(count),
                  originsLoading: loading,
                );
              },
            ),
          ),
        ),
      );
      final nested = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView),
      );
      expect(nested.innerController.positions.length, 1);
      final initial = nested.innerController.positions.single;
      for (final size in [20, 0, 1, 0]) {
        update(() {
          count = size;
          loading = false;
        });
        await tester.pump();
        expect(nested.innerController.positions.single, same(initial));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'fling then switch collection while results arrive has no unlaid metrics',
    (tester) async {
      var count = 20;
      late StateSetter update;
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return UserProfileContent(
                  data: _data(count),
                  originTabLabel: 'Worldo',
                  worldTabLabel: 'Playing',
                  isActiveListenable: active,
                  onRefresh: () async {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.fling(
          find.byType(CustomScrollView).last,
          const Offset(0, -300),
          2200,
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.drag(
          find.byType(TabBarView),
          Offset(i.isEven ? -600 : 600, 0),
        );
        update(() => count = i.isEven ? 0 : 20);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
          i.isEven ? 1 : 0,
        );
      }
      active.value = false;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

UserProfileData _data(int count) => UserProfileData(
  avatarUrl: '',
  displayName: 'User',
  uid: 'user',
  followingCount: 0,
  followerCount: 0,
  origins: List.generate(
    count,
    (i) => UserProfileOriginItem(
      originId: i,
      oid: 'o_$i',
      title: 'Worldo $i',
      subtitle: '',
      imageUrl: '',
      copyCount: 0,
      interactCount: 0,
      characterCount: 0,
    ),
  ),
  worlds: const [],
);
