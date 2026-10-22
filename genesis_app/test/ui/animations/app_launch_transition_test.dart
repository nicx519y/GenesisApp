import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/animations/app_launch_transition/app_launch_transition.dart';

const _flightKey = ValueKey('app-launch-surface');

class _Probe extends StatefulWidget {
  const _Probe({required this.onInit, required this.onDispose});
  final VoidCallback onInit;
  final VoidCallback onDispose;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand(
    key: ValueKey('page-layout'),
    child: ColoredBox(color: Colors.green),
  );
}

void main() {
  late AppLaunchTransitionController controller;
  late StateSetter update;
  var reduced = false;
  var showSource = true;
  var sourceLeft = 20.0;
  var size = const Size(300, 600);
  var dismissed = 0;
  var initialized = 0;
  var disposed = 0;

  Future<void> mount(
    WidgetTester tester, {
    bool restored = false,
    bool interactive = false,
  }) async {
    controller = AppLaunchTransitionController(initiallyOpen: restored);
    reduced = false;
    showSource = true;
    sourceLeft = 20;
    size = const Size(300, 600);
    dismissed = initialized = disposed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: AppLaunchTransitionHost(
                    controller: controller,
                    enableCloseGesture: interactive,
                    surfaceColor: Colors.black,
                    onDismissed: () => dismissed++,
                    home: Stack(
                      children: [
                        if (showSource)
                          Positioned(
                            left: sourceLeft,
                            top: 470,
                            width: 60,
                            height: 60,
                            child: const AppLaunchSource(
                              id: 'icon',
                              borderRadius: 17,
                              preview: Icon(Icons.photo),
                              child: ColoredBox(color: Colors.blue),
                            ),
                          ),
                        const Positioned(
                          left: 220,
                          top: 470,
                          width: 60,
                          height: 60,
                          child: AppLaunchSource(
                            id: 'fallback',
                            borderRadius: 17,
                            child: ColoredBox(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    page: _Probe(
                      onInit: () => initialized++,
                      onDispose: () => disposed++,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Rect rect(WidgetTester tester) {
    final p = tester.widget<Positioned>(find.byKey(_flightKey));
    return Rect.fromLTWH(p.left!, p.top!, p.width!, p.height!);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'edge drag follows the button close path and cancellation restores the page',
    (tester) async {
      await mount(tester, interactive: true);
      controller.open(sourceId: 'icon');
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(find.byType(AppLaunchTransitionHost));
      final drag = await tester.startGesture(origin + const Offset(1, 200));
      await drag.moveBy(const Offset(150, 0));
      await tester.pump();
      final dragRect = rect(tester);
      expect(dragRect.width, inExclusiveRange(60, 300));
      expect(dismissed, 0);
      expect(disposed, 0);
      expect(tester.getSize(find.byKey(const ValueKey('page-layout'))), size);
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(controller.status, AppLaunchTransitionStatus.open);
      expect(rect(tester), Offset.zero & size);
      expect(initialized, 1);
      controller.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(rect(tester).width, closeTo(dragRect.width, .1));
      expect(rect(tester).left, closeTo(dragRect.left, .1));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(disposed, 1);
      await unmount(tester);
    },
  );

  testWidgets(
    'edge drag completes once after release and ignores late pointer events after finish',
    (tester) async {
      await mount(tester, interactive: true);
      controller.open(sourceId: 'icon');
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(find.byType(AppLaunchTransitionHost));
      final drag = await tester.startGesture(origin + const Offset(1, 200));
      await drag.moveBy(const Offset(300, 0));
      await tester.pump();
      expect(
        dismissed,
        0,
        reason: 'Do not dismiss while the finger is still down.',
      );
      await drag.up();
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(disposed, 1);
      controller.finish();
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      await unmount(tester);
    },
  );

  testWidgets(
    'reduced motion still distinguishes canceled and completed edge drags',
    (tester) async {
      await mount(tester, interactive: true);
      update(() => reduced = true);
      await tester.pump();
      controller.open(sourceId: 'icon');
      await tester.pumpAndSettle();
      final start =
          tester.getTopLeft(find.byType(AppLaunchTransitionHost)) +
          const Offset(1, 200);
      final cancel = await tester.startGesture(start);
      await cancel.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(dismissed, 0);
      await cancel.cancel();
      await tester.pumpAndSettle();
      expect(controller.status, AppLaunchTransitionStatus.open);
      expect(dismissed, 0);
      await tester.dragFrom(start, const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      await unmount(tester);
    },
  );

  testWidgets('local geometry, fixed page layout, radius and single mount', (
    tester,
  ) async {
    await mount(tester);
    expect(initialized, 0);
    expect(controller.open(sourceId: 'icon'), isTrue);
    expect(controller.open(sourceId: 'fallback'), isFalse);
    await tester.pump();
    expect(rect(tester), const Rect.fromLTWH(20, 470, 60, 60));
    expect(tester.getSize(find.byKey(const ValueKey('page-layout'))), size);
    await tester.pump(const Duration(milliseconds: 120));
    final mid = rect(tester);
    expect(mid.width, greaterThan(60));
    expect(mid.width, lessThan(300));
    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byKey(_flightKey),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(
      (clip.borderRadius as BorderRadius).topLeft.x,
      inExclusiveRange(0, 17),
    );
    expect(tester.getSize(find.byKey(const ValueKey('page-layout'))), size);
    await tester.pump(const Duration(milliseconds: 241));
    expect(controller.status, AppLaunchTransitionStatus.open);
    expect(rect(tester), Offset.zero & size);
    expect(initialized, 1);
    expect(disposed, 0);
    expect(controller.close(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(microseconds: 279900));
    expect(rect(tester).left, closeTo(20, 1));
    expect(rect(tester).top, closeTo(470, 2));
    await tester.pump(const Duration(milliseconds: 2));
    expect(dismissed, 1);
    expect(disposed, 1);
    expect(controller.status, AppLaunchTransitionStatus.home);
    await unmount(tester);
  });

  testWidgets('mid-flight back is continuous and repeated close is ignored', (
    tester,
  ) async {
    await mount(tester);
    controller.open(sourceId: 'icon');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final before = rect(tester);
    expect(controller.close(), isTrue);
    expect(controller.close(), isFalse);
    await tester.pump();
    expect(rect(tester), before);
    await tester.pump(const Duration(milliseconds: 280));
    expect(dismissed, 1);
    await unmount(tester);
  });

  testWidgets(
    'removed source resolves fallback and moved source is remeasured',
    (tester) async {
      await mount(tester);
      controller.open(sourceId: 'icon');
      await tester.pumpAndSettle();
      update(() => sourceLeft = 90);
      await tester.pump();
      controller.close();
      await tester.pump();
      await tester.pump(const Duration(microseconds: 279900));
      expect(rect(tester).left, closeTo(90, 1));
      await tester.pumpAndSettle();
      controller.open(sourceId: 'icon');
      await tester.pumpAndSettle();
      update(() => showSource = false);
      await tester.pump();
      controller.close(fallbackSourceId: 'fallback');
      await tester.pump();
      await tester.pump(const Duration(microseconds: 279900));
      expect(rect(tester).left, closeTo(220, 1));
      await tester.pumpAndSettle();
      expect(dismissed, 2);
      await unmount(tester);
    },
  );

  testWidgets('offscreen origins and restored pages fade without flying', (
    tester,
  ) async {
    await mount(tester);
    update(() => sourceLeft = 320);
    await tester.pump();
    controller.open(sourceId: 'icon');
    await tester.pump();
    expect(rect(tester), Offset.zero & size);
    await tester.pumpAndSettle();
    controller.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 121));
    expect(dismissed, 1);
    await unmount(tester);
    await mount(tester, restored: true);
    expect(controller.status, AppLaunchTransitionStatus.open);
    controller.close(fallbackSourceId: 'fallback');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(rect(tester), Offset.zero & size);
    await tester.pump(const Duration(milliseconds: 61));
    expect(dismissed, 1);
    await unmount(tester);
  });

  testWidgets(
    'reduced motion, resize, explicit finish and disposal settle safely',
    (tester) async {
      await mount(tester);
      update(() => reduced = true);
      await tester.pump();
      controller.open(sourceId: 'icon');
      await tester.pump();
      expect(controller.status, AppLaunchTransitionStatus.open);
      controller.close();
      await tester.pump();
      expect(controller.status, AppLaunchTransitionStatus.home);
      update(() => reduced = false);
      await tester.pump();
      controller.open(sourceId: 'icon');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      update(() => size = const Size(600, 300));
      await tester.pump();
      await tester.pump();
      expect(controller.status, AppLaunchTransitionStatus.open);
      expect(rect(tester), Offset.zero & size);
      controller.close();
      controller.finish();
      await tester.pump();
      expect(controller.status, AppLaunchTransitionStatus.home);
      expect(dismissed, 2);
      controller.open();
      await tester.pump();
      await unmount(tester);
    },
  );
}
