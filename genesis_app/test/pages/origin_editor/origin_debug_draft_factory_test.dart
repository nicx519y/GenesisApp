import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_debug_content_config.dart'
    as debug_content;
import 'package:genesis_flutter_android/pages/origin_editor/origin_debug_content_config_release.dart'
    as release_content;
import 'package:genesis_flutter_android/pages/origin_editor/origin_debug_draft_factory.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_debug_tools_release.dart'
    as release_tools;
import 'package:genesis_flutter_android/pages/origin_editor/origin_draft_repository.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_editor_pages.dart';

void main() {
  test('debug content config contains varied rich location trees', () {
    final templates = debug_content.originDebugContentTemplates;

    expect(templates, hasLength(8));
    expect(
      templates.every(
        (template) =>
            template.regions
                .expand((region) => region.districts)
                .expand((district) => district.locations)
                .length >=
            6,
      ),
      isTrue,
    );
    expect(templates.any((template) => template.regions.length > 1), isTrue);
    expect(
      templates.every(
        (template) =>
            template.regions.expand((region) => region.districts).length >= 2,
      ),
      isTrue,
    );
    expect(
      templates
          .expand((template) => template.regions)
          .expand((region) => region.districts)
          .expand((district) => district.locations)
          .every((location) => location.imageKeywords.contains(',')),
      isTrue,
    );
  });

  test('release content config contains no debug templates', () {
    expect(release_content.originDebugContentTemplates, isEmpty);
  });

  test('release debug tools expose only empty entry points', () {
    final updateNotesController = TextEditingController();
    addTearDown(updateNotesController.dispose);
    final repository = MemoryOriginDraftRepository(
      initialDraft: CreateOriginDraft.empty(),
    );

    expect(release_tools.createOriginDebugDraftGenerator(), isNull);
    expect(
      release_tools.editOriginDebugDraftGenerator(updateNotesController),
      isNull,
    );
    expect(
      release_tools.buildOriginDebugRandomContentButton(
        repository: repository,
        generator: null,
        enabled: true,
        onGenerated: () async {},
      ),
      isNull,
    );
  });

  test(
    'random create draft is complete and keeps its references consistent',
    () {
      final generated = generateRandomCreateOriginDraft(
        CreateOriginDraft.empty(),
        random: Random(7),
        now: DateTime.utc(2026, 7, 28, 10, 20, 30),
      );

      expect(generated.validateForSubmit(), isEmpty);
      expect(generated.hasAllSectionsSaved, isTrue);
      expect(generated.basics.originId, startsWith('origin_debug_'));
      expect(
        generated.characters.first.avatarUrl,
        startsWith(
          'https://loremflickr.com/1080/1080/portrait,person/all?lock=',
        ),
      );
      expect(
        generated.characters.last.avatarUrl,
        startsWith(
          'https://loremflickr.com/1080/1080/anime,character/all?lock=',
        ),
      );

      final locationIds = generated.locations
          .map((location) => location.locationId)
          .toSet();
      for (final location in generated.locations.where(
        (location) => location.parentLocationId.isNotEmpty,
      )) {
        expect(locationIds, contains(location.parentLocationId));
      }
      expect(locationIds, contains(generated.opening.locationId));
      final level1Locations = generated.locations
          .where((location) => location.level == 1)
          .toList(growable: false);
      final level2Locations = generated.locations
          .where((location) => location.level == 2)
          .toList(growable: false);
      final leafLocations = generated.locations
          .where((location) => location.level == 3)
          .toList(growable: false);
      expect(level1Locations, isNotEmpty);
      expect(level2Locations.length, greaterThanOrEqualTo(2));
      expect(leafLocations.length, greaterThanOrEqualTo(6));
      expect(
        leafLocations.every(
          (location) =>
              location.imageUrl.startsWith(
                'https://loremflickr.com/1080/1080/',
              ) &&
              location.imageUrl.contains('/all?lock='),
        ),
        isTrue,
      );
      expect(generated.storyEvents.length, greaterThanOrEqualTo(3));

      final characterIds = generated.characters
          .map((character) => character.charId)
          .toSet();
      expect(
        generated.opening.dialogue
            .where((item) => item.type == OpeningDialogueDraft.characterType)
            .every((item) => characterIds.contains(item.characterId)),
        isTrue,
      );

      final payload = generated.toCreateOriginPayload();
      expect(payload['init_location_group'], isA<Map<String, dynamic>>());
      final opening = payload['init_location_group'] as Map<String, dynamic>;
      expect(
        opening['initial_dialogue'],
        contains(
          predicate<Map<String, dynamic>>(
            (item) => item['char_id'] == 'nar_pic',
          ),
        ),
      );
    },
  );

  test('random edit draft preserves server identity and registers changes', () {
    const original = CreateOriginDraft(
      basics: BasicsDraft(
        originId: 'origin_existing',
        originVersion: '12',
        originName: 'Existing',
        worldView: 'Existing brief',
        coverImageUrl: 'https://example.com/cover.webp',
      ),
      characters: <CharacterDraft>[
        CharacterDraft(
          charId: 'char_existing',
          name: 'Existing Character',
          identity: 'Keeper',
          personality: 'Calm',
        ),
      ],
      locations: <LocationDraft>[
        LocationDraft(
          locationId: 'location_existing',
          level: 3,
          name: 'Existing Location',
        ),
      ],
      storyEvents: <StoryEventDraft>[StoryEventDraft()],
      opening: OpeningDraft(
        locationId: 'location_existing',
        locationName: 'Existing Location',
        dialogue: <OpeningDialogueDraft>[
          OpeningDialogueDraft(
            type: OpeningDialogueDraft.narratorType,
            content: 'Existing opening.',
          ),
        ],
      ),
      basicsSaved: true,
      charactersSaved: true,
      locationsSaved: true,
      storyEventsSaved: true,
      openingSaved: true,
    );
    final repository = MemoryOriginDraftRepository(initialDraft: original);
    final generated = generateRandomEditOriginDraft(
      original,
      random: Random(11),
      now: DateTime.utc(2026, 7, 28, 11, 0),
    );

    expect(generated.basics.originId, 'origin_existing');
    expect(generated.basics.originVersion, '12');
    expect(generated.validateForSubmit(), isEmpty);
    expect(generated.hasAllSectionsSaved, isTrue);
    expect(repository.hasSubmitChanges(generated), isTrue);
    expect(
      generated.characters.map((item) => item.charId),
      contains('char_existing'),
    );
    expect(
      generated.locations.map((item) => item.locationId),
      contains('location_existing'),
    );
    expect(
      generated.locations.where((item) => item.level == 3).length,
      greaterThanOrEqualTo(6),
    );
    expect(generated.locations.any((item) => item.level == 1), isTrue);
    expect(generated.locations.any((item) => item.level == 2), isTrue);
    expect(repository.deletedCharacterIds(generated), isEmpty);
    expect(repository.deletedLocationIds(generated), isEmpty);
  });

  testWidgets(
    'debug random button is bottom-left and refreshes the draft summary',
    (tester) async {
      expect(kDebugMode, isTrue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      final repository = MemoryOriginDraftRepository(
        initialDraft: CreateOriginDraft.empty(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OriginDraftFlowPage(
            title: 'Debug Worldo',
            repository: repository,
            basicsPageBuilder: (_) => const SizedBox.shrink(),
            charactersPageBuilder: (_) => const SizedBox.shrink(),
            locationsPageBuilder: (_) => const SizedBox.shrink(),
            openingPageBuilder: (_) => const SizedBox.shrink(),
            storyEventsPageBuilder: (_) => const SizedBox.shrink(),
            debugDraftGenerator: (current) => generateRandomCreateOriginDraft(
              current,
              random: Random(3),
              now: DateTime.utc(2026, 7, 28, 12, 0),
            ),
            onSubmit: (_, _, _) async => const OriginSubmitResult(message: ''),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(
        const ValueKey<String>('origin-debug-random-content-button'),
      );
      expect(button, findsOneWidget);
      final buttonCenter = tester.getCenter(button);
      final screenSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(buttonCenter.dx, lessThan(screenSize.width / 2));
      expect(buttonCenter.dy, greaterThan(screenSize.height / 2));
      final saveButton = find.widgetWithText(FilledButton, 'Save');
      expect(
        tester.getRect(button).overlaps(tester.getRect(saveButton)),
        isFalse,
      );

      await tester.tap(button);
      await tester.pumpAndSettle();

      final generated = await repository.loadSummaryDraft();
      expect(generated.validateForSubmit(), isEmpty);
      expect(find.textContaining(generated.basics.originName), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('debug random button marks every changed section as saved', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final repository = MemoryOriginDraftRepository(
      initialDraft: CreateOriginDraft.empty(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OriginDraftFlowPage(
          title: 'Debug saved states',
          repository: repository,
          basicsPageBuilder: (_) => const SizedBox.shrink(),
          charactersPageBuilder: (_) => const SizedBox.shrink(),
          locationsPageBuilder: (_) => const SizedBox.shrink(),
          openingPageBuilder: (_) => const SizedBox.shrink(),
          storyEventsPageBuilder: (_) => const SizedBox.shrink(),
          debugDraftGenerator: (current) => current.copyWith(
            basics: const BasicsDraft(originName: 'Randomized name'),
            characters: const <CharacterDraft>[
              CharacterDraft(name: 'Randomized character'),
            ],
            opening: const OpeningDraft(
              locationId: 'random_location',
              locationName: 'Random location',
              dialogue: <OpeningDialogueDraft>[
                OpeningDialogueDraft(
                  type: OpeningDialogueDraft.narratorType,
                  content: 'Randomized opening.',
                ),
              ],
            ),
          ),
          onSubmit: (_, _, _) async => const OriginSubmitResult(message: ''),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('origin-debug-random-content-button')),
    );
    await tester.pumpAndSettle();

    final generated = await repository.loadSummaryDraft();
    expect(generated.basicsSaved, isTrue);
    expect(generated.charactersSaved, isTrue);
    expect(generated.openingSaved, isTrue);
    expect(generated.locationsSaved, isFalse);
    expect(generated.storyEventsSaved, isFalse);
    expect(find.text('✓'), findsNWidgets(3));
    await tester.pump(const Duration(seconds: 3));
  });
}
