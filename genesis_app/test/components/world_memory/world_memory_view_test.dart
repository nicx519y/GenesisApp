import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_offer_card.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_style.dart';
import 'package:genesis_flutter_android/components/world_memory/world_memory.dart';
import 'package:genesis_flutter_android/components/world_memory/world_memory_preview_data.dart';
import 'package:genesis_flutter_android/components/world_memory/world_memory_tick_tile.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

const _alice = WorldMemoryPerson(id: 'alice', name: 'Secret Alice');
const _bob = WorldMemoryPerson(id: 'bob', name: 'Secret Bob');
const _summaryBody = 'Private full summary\nSecond paragraph stays intact.';
const _snapshot = WorldMemorySnapshot(
  summaryTicks: [
    WorldMemorySummaryTick(tickNo: 3, bodies: [_summaryBody]),
  ],
  hasStoryMemory: true,
  events: [
    WorldMemoryEvent(
      id: 'event',
      timeLabel: 'Secret time',
      order: 1,
      body: 'Private event',
      participants: [_alice],
    ),
  ],
  cast: [
    WorldMemoryCharacter(
      person: _alice,
      identity: 'Secret identity',
      now: 'Private activity',
      towardYou: 'Private affection',
      updated: true,
      fields: {
        WorldMemoryField.age: WorldMemoryValue('28'),
        WorldMemoryField.personality: WorldMemoryValue(
          'Private personality',
          updated: true,
        ),
        WorldMemoryField.background: WorldMemoryValue('   '),
      },
    ),
  ],
  relations: [
    WorldMemoryRelation(
      id: 'bond',
      group: WorldMemoryRelationGroup.towardPlayer,
      from: _alice,
      to: _bob,
      body: 'Private relationship',
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  WorldMemorySection section = WorldMemorySection.recap,
  WorldMemorySnapshot snapshot = _snapshot,
  bool premium = false,
  bool deluxe = false,
  bool phone = false,
  Widget? summaryContent,
  double width = 390,
  double scale = 1,
  ValueChanged<MemoryMembershipTier>? onSubscribe,
  ScrollController? controller,
  Widget Function(BuildContext, VoidCallback?)? phoneHeaderBuilder,
}) async {
  tester.view.resetPhysicalSize();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: GenesisTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: WorldMemoryView(
            section: section,
            snapshot: snapshot,
            premiumActive: premium,
            deluxeActive: deluxe,
            onSubscribe: onSubscribe ?? (_) {},
            phone: phone,
            summaryContent: summaryContent,
            scrollController: controller,
            phoneHeaderBuilder: phoneHeaderBuilder,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone profile reuses host back header without a duplicate row', (
    tester,
  ) async {
    VoidCallback? profileBack;
    await _pump(
      tester,
      section: WorldMemorySection.cast,
      deluxe: true,
      phone: true,
      phoneHeaderBuilder: (context, back) {
        profileBack = back;
        return const SizedBox(height: 56, child: Text('Host Cast header'));
      },
    );
    expect(profileBack, isNull);
    await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
    await tester.pumpAndSettle();
    expect(profileBack, isNotNull);
    expect(find.text('Host Cast header'), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-profile-back')), findsNothing);
    profileBack!();
    await tester.pumpAndSettle();
    expect(profileBack, isNull);
    expect(
      find.byKey(const ValueKey('memory-character-alice')),
      findsOneWidget,
    );
  });
  testWidgets('World keeps earlier profiles open when another expands', (
    tester,
  ) async {
    const snapshot = WorldMemorySnapshot(
      hasStoryMemory: true,
      cast: [
        WorldMemoryCharacter(
          person: _alice,
          fields: {WorldMemoryField.age: WorldMemoryValue('28')},
        ),
        WorldMemoryCharacter(
          person: _bob,
          fields: {WorldMemoryField.age: WorldMemoryValue('31')},
        ),
      ],
    );
    await _pump(
      tester,
      section: WorldMemorySection.cast,
      deluxe: true,
      snapshot: snapshot,
    );
    await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
    await tester.pumpAndSettle();
    expect(find.text('28'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('memory-character-bob')));
    await tester.pumpAndSettle();
    expect(find.text('28'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('Phone opens a separate detail and returns to Cast', (
    tester,
  ) async {
    await _pump(
      tester,
      section: WorldMemorySection.cast,
      deluxe: true,
      phone: true,
    );
    await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('memory-phone-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-character-alice')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('memory-profile-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('memory-phone-profile')), findsNothing);
    expect(
      find.byKey(const ValueKey('memory-character-alice')),
      findsOneWidget,
    );
  });

  testWidgets(
    'preview uses offline portraits and fresh keeps only setup fields',
    (tester) async {
      final snapshot = WorldMemoryPreviewData.fresh();
      expect(snapshot.events, isEmpty);
      expect(snapshot.relations, isEmpty);
      expect(snapshot.summaryTicks, isEmpty);
      expect(snapshot.cast.every((c) => c.now.isEmpty && !c.updated), isTrue);
      expect(
        snapshot.cast.every((c) => !c.fields.containsKey(WorldMemoryField.arc)),
        isTrue,
      );
      await _pump(
        tester,
        section: WorldMemorySection.cast,
        deluxe: true,
        snapshot: snapshot,
      );
      expect(find.byType(Image), findsNWidgets(5));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(image.image, isA<AssetImage>());
      }
      expect(find.text('Now'), findsNothing);
      expect(find.text('Updated'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone departed detail uses Last seen and remains navigable', (
    tester,
  ) async {
    await _pump(
      tester,
      section: WorldMemorySection.cast,
      deluxe: true,
      phone: true,
      snapshot: const WorldMemorySnapshot(
        cast: [
          WorldMemoryCharacter(
            person: _alice,
            status: WorldMemoryCharacterStatus.departed,
            now: 'Station',
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
    await tester.pumpAndSettle();
    expect(find.text('Right now'), findsNothing);
    expect(find.text('Last seen'), findsNWidgets(2));
    expect(find.text('Status'), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('caller-owned controller attaches and is not disposed by view', (
    tester,
  ) async {
    final controller = ScrollController();
    await _pump(
      tester,
      deluxe: true,
      controller: controller,
      snapshot: WorldMemorySnapshot(
        events: List.generate(
          10,
          (i) => WorldMemoryEvent(
            id: '$i',
            timeLabel: 'Day $i',
            order: i,
            body: 'Long event body. ' * 20,
          ),
        ),
      ),
    );
    expect(controller.hasClients, isTrue);
    controller.jumpTo(100);
    await tester.pumpAndSettle();
    expect(controller.offset, 100);
    await tester.pumpWidget(const SizedBox());
    expect(controller.hasClients, isFalse);
    controller.addListener(() {});
    controller.dispose();
  });

  for (final premium in [false, true]) {
    for (final deluxe in [false, true]) {
      testWidgets('independent access premium=$premium deluxe=$deluxe', (
        tester,
      ) async {
        await _pump(tester, premium: premium, deluxe: deluxe);
        await tester.tap(find.byKey(const ValueKey('memory-tab-timeline')));
        await tester.pumpAndSettle();
        expect(
          find.text('Private event'),
          deluxe ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(MemoryMembershipOfferCard),
          deluxe ? findsNothing : findsOneWidget,
        );
        if (!deluxe) {
          expect(
            tester
                .widget<MemoryMembershipOfferCard>(
                  find.byType(MemoryMembershipOfferCard),
                )
                .tier,
            MemoryMembershipTier.deluxe,
          );
        }
        await tester.tap(find.byKey(const ValueKey('memory-tab-summary')));
        await tester.pumpAndSettle();
        expect(
          find.text(_summaryBody),
          premium ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(MemoryMembershipOfferCard),
          premium ? findsNothing : findsOneWidget,
        );
        if (!premium) {
          expect(
            tester
                .widget<MemoryMembershipOfferCard>(
                  find.byType(MemoryMembershipOfferCard),
                )
                .tier,
            MemoryMembershipTier.premium,
          );
        }
      });
    }
  }

  for (final section in WorldMemorySection.values) {
    testWidgets(
      'locked ${section.name} excludes sensitive content and avatars',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _pump(
            tester,
            section: section,
            summaryContent: const Text('Private override'),
          );
          for (final secret in [
            // Cast keeps names and avatars visible; everything else is hidden.
            if (section != WorldMemorySection.cast) ...[
              'Secret Alice',
              'Secret Bob',
            ],
            'Private event',
            'Secret time',
            'Secret identity',
            'Private activity',
            'Private affection',
            'Private personality',
            'Private relationship',
            'Private override',
            _summaryBody,
          ]) {
            expect(find.textContaining(secret), findsNothing);
            expect(
              find.bySemanticsLabel(RegExp(RegExp.escape(secret))),
              findsNothing,
            );
          }
          expect(
            find.byType(GenesisCharacterAvatar),
            section == WorldMemorySection.cast ? findsWidgets : findsNothing,
          );
          expect(find.byType(MemoryMembershipOfferCard), findsOneWidget);
          if (section == WorldMemorySection.recap) {
            await tester.tap(find.byKey(const ValueKey('memory-tab-timeline')));
            await tester.pumpAndSettle();
            expect(find.text('Private event'), findsNothing);
            expect(find.text('Secret time'), findsNothing);
            expect(find.byType(GenesisCharacterAvatar), findsNothing);
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('subscribe and details forward the exact locked tier', (
    tester,
  ) async {
    final tiers = <MemoryMembershipTier>[];
    await _pump(tester, onSubscribe: tiers.add);
    final premiumCard = tester.widget<MemoryMembershipOfferCard>(
      find.byType(MemoryMembershipOfferCard),
    );
    premiumCard.onSubscribe();
    premiumCard.onDetails();
    await tester.tap(find.byKey(const ValueKey('memory-tab-timeline')));
    await tester.pumpAndSettle();
    final deluxeCard = tester.widget<MemoryMembershipOfferCard>(
      find.byType(MemoryMembershipOfferCard),
    );
    deluxeCard.onSubscribe();
    deluxeCard.onDetails();
    expect(tiers, [
      MemoryMembershipTier.premium,
      MemoryMembershipTier.premium,
      MemoryMembershipTier.deluxe,
      MemoryMembershipTier.deluxe,
    ]);
  });

  testWidgets('timeline reads down to the latest, caps ten, preserves input', (
    tester,
  ) async {
    final events = List.generate(
      12,
      (i) => WorldMemoryEvent(
        id: 'event-$i',
        order: i,
        timeLabel: 'time-$i',
        body: 'body-$i',
      ),
    );
    await _pump(
      tester,
      deluxe: true,
      snapshot: WorldMemorySnapshot(events: events),
    );
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data)
        .whereType<String>()
        .where((s) => s.startsWith('body-'))
        .toList();
    expect(rendered, List.generate(10, (i) => 'body-${i + 2}'));
    expect(events.first.id, 'event-0');
  });

  testWidgets('summary override is gated and replaces the full supplied body', (
    tester,
  ) async {
    await _pump(
      tester,
      premium: true,
      summaryContent: const Text('Loading summary'),
    );
    expect(find.text('Loading summary'), findsOneWidget);
    expect(find.text(_summaryBody), findsNothing);
    await _pump(tester, premium: true);
    expect(find.text(_summaryBody), findsOneWidget);
  });

  testWidgets('summary shows ticks oldest first on the recap rail', (
    tester,
  ) async {
    await _pump(
      tester,
      premium: true,
      snapshot: const WorldMemorySnapshot(
        summaryTicks: [
          WorldMemorySummaryTick(tickNo: 1, bodies: ['First tick']),
          WorldMemorySummaryTick(tickNo: 2, bodies: ['Second a', 'Second b']),
        ],
      ),
    );
    expect(find.byType(WorldMemoryTickTile), findsNWidgets(2));
    expect(find.text('Tick 1'), findsOneWidget);
    expect(find.text('The story so far'), findsNothing);
    final tiles = tester
        .widgetList<WorldMemoryTickTile>(find.byType(WorldMemoryTickTile))
        .toList();
    expect(tiles.first.tickNo, 1);
    expect(tiles.last.isLast, isTrue);
    expect(find.text('Second b'), findsOneWidget);
  });

  testWidgets('World cast rows open independently and hold their place', (
    tester,
  ) async {
    await _pump(
      tester,
      section: WorldMemorySection.cast,
      deluxe: true,
      snapshot: WorldMemoryPreviewData.live(),
    );
    final you = find.byKey(const ValueKey('memory-character-you'));
    final vivienne = find.byKey(const ValueKey('memory-character-vivienne'));
    final youTop = tester.getTopLeft(you).dy;
    await tester.tap(you);
    await tester.pumpAndSettle();
    expect(
      find.text('Black hair, sharp dark suit, loosened tie'),
      findsOneWidget,
    );
    await tester.ensureVisible(vivienne);
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final offset = scroll.position.pixels;
    final vivienneTop = tester.getTopLeft(vivienne).dy;
    await tester.tap(vivienne);
    await tester.pumpAndSettle();
    // The second opens without closing the first, and nothing on screen jumps.
    expect(
      find.text('Black hair, sharp dark suit, loosened tie'),
      findsOneWidget,
    );
    expect(
      find.text('Long dark waves, cream knit, an easy smile'),
      findsOneWidget,
    );
    expect(scroll.position.pixels, offset);
    expect(tester.getTopLeft(vivienne).dy, vivienneTop);
    await tester.tap(vivienne);
    await tester.pumpAndSettle();
    expect(
      find.text('Long dark waves, cream knit, an easy smile'),
      findsNothing,
    );
    expect(
      find.text('Black hair, sharp dark suit, loosened tie'),
      findsOneWidget,
    );
    expect(youTop, lessThan(vivienneTop));
  });

  testWidgets('the three World sections start the same gap under the title', (
    tester,
  ) async {
    final snapshot = WorldMemoryPreviewData.live();
    double gap(Finder content) =>
        tester.getTopLeft(content).dy -
        tester.getTopLeft(find.byType(WorldMemoryView)).dy;
    await _pump(tester, deluxe: true, snapshot: snapshot);
    final recap = gap(find.byKey(const ValueKey('memory-tab-timeline')));
    await _pump(
      tester,
      section: WorldMemorySection.cast,
      deluxe: true,
      snapshot: snapshot,
    );
    final cast = gap(find.byKey(const ValueKey('memory-character-you')));
    await _pump(
      tester,
      section: WorldMemorySection.bonds,
      deluxe: true,
      snapshot: snapshot,
    );
    final bonds = gap(find.text('How they see you'));
    expect((recap - cast).abs(), lessThanOrEqualTo(3));
    expect((bonds - cast).abs(), lessThanOrEqualTo(3));
    // Before subscribing, the pitch takes that same place in all three.
    for (final section in WorldMemorySection.values) {
      await _pump(tester, section: section, snapshot: snapshot);
      final pitch = find
          .descendant(
            of: find.byType(WorldMemoryView),
            matching: find.byType(Text),
          )
          .first;
      expect(gap(pitch), cast, reason: section.name);
    }
  });

  testWidgets('empty states preserve groups without invented updates', (
    tester,
  ) async {
    const empty = WorldMemorySnapshot.empty();
    await _pump(tester, premium: true, deluxe: true, snapshot: empty);
    expect(find.text('No key events yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('memory-tab-summary')));
    await tester.pumpAndSettle();
    expect(
      find.text('Story recap will appear here as the story moves forward.'),
      findsOneWidget,
    );
    await _pump(
      tester,
      section: WorldMemorySection.cast,
      deluxe: true,
      snapshot: empty,
    );
    expect(
      find.text('Characters will appear here as your story begins.'),
      findsOneWidget,
    );
    expect(find.text('Updated'), findsNothing);
    await _pump(
      tester,
      section: WorldMemorySection.bonds,
      deluxe: true,
      snapshot: empty,
    );
    expect(find.text('How they see you'), findsOneWidget);
    expect(find.text('Between them'), findsOneWidget);
    expect(
      find.text(
        'Nobody has formed a view of you yet. It shows up here once someone does.',
      ),
      findsOneWidget,
    );
    expect(find.text('Updated'), findsNothing);
  });

  testWidgets(
    'cast expands, omits blank rows, shows updated values and collapses',
    (tester) async {
      await _pump(tester, section: WorldMemorySection.cast, deluxe: true);
      expect(find.text('Private personality'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
      await tester.pumpAndSettle();
      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Story'), findsNothing);
      expect(find.text('Background'), findsNothing);
      expect(find.text('Private personality'), findsOneWidget);
      expect(find.text('Updated'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
      await tester.pumpAndSettle();
      expect(find.text('Private personality'), findsNothing);
    },
  );

  testWidgets(
    'departed and dead profiles come last with grayscale and status',
    (tester) async {
      const snapshot = WorldMemorySnapshot(
        cast: [
          WorldMemoryCharacter(
            person: _bob,
            status: WorldMemoryCharacterStatus.dead,
            now: 'Terrace',
          ),
          WorldMemoryCharacter(person: _alice),
          WorldMemoryCharacter(
            person: WorldMemoryPerson(id: 'gone', name: 'Departed'),
            status: WorldMemoryCharacterStatus.departed,
            now: 'Station',
          ),
        ],
      );
      await _pump(
        tester,
        section: WorldMemorySection.cast,
        deluxe: true,
        snapshot: snapshot,
      );
      expect(
        tester.getTopLeft(find.text('Secret Alice')).dy,
        lessThan(tester.getTopLeft(find.text('Left the story · 2')).dy),
      );
      expect(
        find.textContaining('Last seen ·', findRichText: true),
        findsNWidgets(2),
      );
      expect(find.text('Now'), findsNothing);
      expect(find.byType(ColorFiltered), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('memory-character-bob')));
      await tester.pumpAndSettle();
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Deceased'), findsNWidgets(2));
      expect(find.text('Left'), findsOneWidget);
    },
  );

  testWidgets('phone profile includes Right now and Toward you', (
    tester,
  ) async {
    await _pump(
      tester,
      section: WorldMemorySection.cast,
      deluxe: true,
      phone: true,
    );
    await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
    await tester.pumpAndSettle();
    expect(find.text('Right now'), findsOneWidget);
    expect(find.text('Toward you'), findsOneWidget);
    expect(find.text('Private affection'), findsOneWidget);
  });

  testWidgets('entitlement revocation removes already expanded content', (
    tester,
  ) async {
    await _pump(tester, section: WorldMemorySection.cast, deluxe: true);
    await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
    await tester.pumpAndSettle();
    await _pump(tester, section: WorldMemorySection.cast, deluxe: false);
    expect(find.text('Private personality'), findsNothing);
    expect(find.text('Secret identity'), findsNothing);
  });

  for (final width in [280.0, 350.0, 390.0]) {
    testWidgets(
      'narrow $width at 1.5x text handles expanded and locked content',
      (tester) async {
        await _pump(
          tester,
          section: WorldMemorySection.cast,
          deluxe: true,
          phone: true,
          width: width,
          scale: 1.5,
        );
        await tester.tap(find.byKey(const ValueKey('memory-character-alice')));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _pump(tester, width: width, scale: 1.5);
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
