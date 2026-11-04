import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/world_memory_debug_preview.dart';
import 'package:genesis_flutter_android/components/world_memory/world_memory_models.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/world/world_bottom_sheet.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  tearDown(() {
    worldMemoryDebugPreview.value = const WorldMemoryDebugPreview();
  });

  test('stays out of the way until a membership is chosen', () {
    expect(activeWorldMemoryDebugPreview, isNull);
    worldMemoryDebugPreview.value = const WorldMemoryDebugPreview(
      membership: WorldMemoryDebugMembership.free,
    );
    expect(activeWorldMemoryDebugPreview, isNotNull);
  });

  test('Premium and Deluxe stay independent', () {
    const free = WorldMemoryDebugPreview(
      membership: WorldMemoryDebugMembership.free,
    );
    const premium = WorldMemoryDebugPreview(
      membership: WorldMemoryDebugMembership.premium,
    );
    const deluxe = WorldMemoryDebugPreview(
      membership: WorldMemoryDebugMembership.deluxe,
    );
    const both = WorldMemoryDebugPreview(
      membership: WorldMemoryDebugMembership.both,
    );
    expect([free.premium, free.deluxe], [false, false]);
    expect([premium.premium, premium.deluxe], [true, false]);
    expect([deluxe.premium, deluxe.deluxe], [false, true]);
    expect([both.premium, both.deluxe], [true, true]);
    expect(premium.deluxeExpiry, isNull);
    expect(deluxe.premiumExpiry, isNull);
  });

  test('update counts follow the design for each membership', () {
    int count(WorldMemoryDebugMembership membership, WorldMemorySection s) =>
        WorldMemoryDebugPreview(membership: membership).updatesFor(s);

    expect(count(WorldMemoryDebugMembership.both, WorldMemorySection.cast), 2);
    expect(
      count(WorldMemoryDebugMembership.deluxe, WorldMemorySection.bonds),
      1,
    );
    expect(
      count(WorldMemoryDebugMembership.premium, WorldMemorySection.recap),
      1,
    );
    expect(
      count(WorldMemoryDebugMembership.premium, WorldMemorySection.cast),
      0,
    );
    expect(count(WorldMemoryDebugMembership.free, WorldMemorySection.recap), 0);
    expect(
      const WorldMemoryDebugPreview(
        membership: WorldMemoryDebugMembership.both,
        story: WorldMemoryDebugStory.fresh,
      ).updatesFor(WorldMemorySection.cast),
      0,
    );
  });

  test('each story supplies its own sample snapshot', () {
    const preview = WorldMemoryDebugPreview(
      membership: WorldMemoryDebugMembership.both,
    );
    expect(preview.snapshot.events, isNotEmpty);
    expect(
      preview.copyWith(story: WorldMemoryDebugStory.fresh).snapshot.events,
      isEmpty,
    );
    expect(
      preview
          .copyWith(story: WorldMemoryDebugStory.departures)
          .snapshot
          .cast
          .where((character) => character.hasLeft),
      isNotEmpty,
    );
  });

  testWidgets('capsule dots follow the preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WorldBottomTags(onTap: (_) {}, relationStatus: 'joined'),
        ),
      ),
    );
    final dot = find.byKey(const ValueKey('world-recap-unread-dot'));
    expect(dot, findsNothing);

    worldMemoryDebugPreview.value = const WorldMemoryDebugPreview(
      membership: WorldMemoryDebugMembership.both,
    );
    await tester.pump();
    expect(dot, findsOneWidget);
  });

  test('History sits second in the World sections', () {
    final kinds = worldBottomTagItemsFor(
      lookupAppLocalizations(const Locale('en')),
    ).map((item) => item.kind).toList();
    expect(kinds.take(5), [
      WorldBottomSheetKind.detail,
      WorldBottomSheetKind.history,
      WorldBottomSheetKind.recap,
      WorldBottomSheetKind.cast,
      WorldBottomSheetKind.bonds,
    ]);
  });
}
