import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_bottom_sheet.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';
import 'package:genesis_flutter_android/pages/world/world_recap_cache.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'package:genesis_flutter_android/ui/components/genesis_dark_close_button.dart';
import 'history_fixtures.dart';
import 'world_history_widget_test.dart' show Backend, Harness, frames;

Future<ValueNotifier<WorldBottomSheetSelection>> openSheet(
  WidgetTester tester,
  Harness h,
) async {
  final world = historyWorld().copyWith(relationStatus: 'owner');
  final selection = ValueNotifier(
    const WorldBottomSheetSelection(
      kind: WorldBottomSheetKind.history,
      eventsLatestRevision: 0,
    ),
  );
  final worlds = ValueNotifier<WorldDetail?>(world);
  final notices = ValueNotifier<List<WorldNewUserJoinNotice>>([]);
  final recap = WorldRecapCache();
  addTearDown(selection.dispose);
  addTearDown(worlds.dispose);
  addTearDown(notices.dispose);
  addTearDown(recap.dispose);
  await tester.pumpWidget(h.build(world, shown: false));
  unawaited(
    h.navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: WorldSingleSectionBottomSheet(
            selectionListenable: selection,
            services: h.services,
            initialWorld: world,
            worldListenable: worlds,
            newUserJoinNoticesListenable: notices,
            eventsCache: WorldSectionsEventsCache(),
            recapCache: recap,
            historyCache: h.cache,
            currentUid: 'me',
            recentChatLocationIds: const {},
            onLocationTap: (_) {},
          ),
        ),
      ),
    ),
  );
  await frames(tester);
  return selection;
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          GenesisMethodChannels.device,
          (call) async => call.method == GenesisMethodChannels.getAppVersion
              ? {'versionName': '9.9.9', 'versionCode': 999}
              : null,
        );
  });

  final sheet = find.byKey(const ValueKey('world-single-section-bottom-sheet'));
  final header = find.byKey(const ValueKey('world-sheet-header-drag-area'));

  testWidgets(
    'unloaded, more and failed history block body and header dismissal; close remains available',
    (tester) async {
      final b = Backend()
        ..more = true
        ..pending = Completer<void>();
      final h = Harness(b);
      await openSheet(tester, h);
      final top = tester.getTopLeft(sheet).dy;
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
        2000,
      );
      await frames(tester);
      expect(sheet, findsOneWidget);
      expect(tester.getTopLeft(sheet).dy, closeTo(top, 1));
      b.pending!.complete();
      b.pending = null;
      await frames(tester);
      expect(h.cache.controller!.hasOlder, isTrue);
      await tester.fling(header, const Offset(0, 400), 2000);
      await frames(tester);
      expect(tester.getTopLeft(sheet).dy, closeTo(top, 1));
      b.fail = true;
      await h.cache.controller!.loadOlder();
      await frames(tester);
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
        2000,
      );
      await frames(tester);
      expect(sheet, findsOneWidget);
      expect(tester.getTopLeft(sheet).dy, closeTo(top, 1));
      await tester.tap(find.byType(GenesisDarkCloseButton));
      await frames(tester);
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    },
  );

  testWidgets(
    'last page arriving during a drag only enables dismissal for the next gesture',
    (tester) async {
      final b = Backend()..more = true;
      final h = Harness(b);
      await openSheet(tester, h);
      final top = tester.getTopLeft(sheet).dy;
      b.more = false;
      b.rows = [historyJson('older')];
      b.pending = Completer<void>();
      final loading = h.cache.controller!.loadOlder();
      await frames(tester);
      final gesture = await tester.startGesture(tester.getCenter(header));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      b.pending!.complete();
      b.pending = null;
      await loading;
      await frames(tester);
      expect(h.cache.controller!.hasOlder, isFalse);
      await gesture.moveBy(const Offset(0, 350));
      await gesture.up();
      await frames(tester);
      expect(sheet, findsOneWidget);
      expect(tester.getTopLeft(sheet).dy, closeTo(top, 1));
      await tester.fling(header, const Offset(0, 400), 2000);
      await frames(tester);
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    },
  );
  testWidgets('other sheet tabs still dismiss while History has more pages', (
    tester,
  ) async {
    final b = Backend()..more = true;
    final h = Harness(b);
    final selection = await openSheet(tester, h);
    selection.value = const WorldBottomSheetSelection(
      kind: WorldBottomSheetKind.detail,
      eventsLatestRevision: 0,
    );
    await frames(tester);
    expect(h.cache.controller!.hasOlder, isTrue);
    await tester.fling(header, const Offset(0, 400), 2000);
    await frames(tester);
    expect(sheet, findsNothing);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });
}
