import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/components/gems/gem_colors.dart';
import 'package:genesis_flutter_android/network/models/gem_model.dart';
import 'package:genesis_flutter_android/pages/gems/memory_model_page.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  tearDown(GenesisTelemetry.resetForTesting);

  _gemModelTitleCacheTests();

  testWidgets('initial loading indicator uses the Gem red color', (
    tester,
  ) async {
    final catalogCompleter = Completer<GemModelCatalog>();

    await tester.pumpWidget(
      _testApp(
        home: MemoryModelPage(
          worldId: 'W_LOADING',
          catalogLoader: (_) => catalogCompleter.future,
        ),
      ),
    );
    await tester.pump();

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byKey(const ValueKey('gem-model-page-loading')),
    );
    expect(indicator.color, const Color(0xFFF82B3C));

    catalogCompleter.complete(_catalog());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'selected model dot stays a borderless reward dot in both themes',
    (tester) async {
      // 8-22 spec: the in-use dot moved off the green success slot onto the
      // per-theme gem reward tone.
      for (final (theme, gemColors) in <(ThemeData, GenesisGemColors)>[
        (GenesisTheme.worldoLight(), GenesisGemColors.worldoLight()),
        (GenesisTheme.worldoDark(), GenesisGemColors.worldoDark()),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MemoryModelPage(
              worldId: 'W_MODEL_DOT',
              catalogLoader: (_) async => _catalog(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final currentDot = tester.widget<Container>(
          find.byKey(const ValueKey('gem-model-current-top_pick_v3')),
        );
        final decoration = currentDot.decoration! as BoxDecoration;
        expect(decoration.color, gemColors.reward);
        expect(decoration.border, isNull);
      }
    },
  );

  testWidgets('renders backend model catalog and selected state', (
    tester,
  ) async {
    final requestedWorldIds = <String>[];

    await tester.pumpWidget(
      _testApp(
        home: MemoryModelPage(
          worldId: 'W_000001',
          catalogLoader: (worldId) async {
            requestedWorldIds.add(worldId);
            return _catalog();
          },
          selectionHandler: (_, modelCode) async =>
              GemModelSelection(selectedModelCode: modelCode),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedWorldIds, ['W_000001']);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Top Pick V3'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Estimated next message: 4 gems'), findsOneWidget);

    final pageTitleStyle = tester.widget<Text>(find.text('Model')).style;
    expect(pageTitleStyle?.fontSize, 17);
    expect(pageTitleStyle?.height, 1);
    expect(pageTitleStyle?.fontWeight, FontWeight.w800);
    expect(pageTitleStyle?.color, Colors.white);
    expect(
      tester.getTopLeft(find.text('Recommended')).dy -
          tester.getRect(find.text('Model')).bottom,
      closeTo(30.5, 0.1),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('gem-model-back'))),
      const Size.square(34),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('gem-model-save'))).height,
      28,
    );

    final saveButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('gem-model-save')),
    );
    expect(saveButton.onPressed, isNull);
    expect(
      find.byKey(const ValueKey('gem-model-current-top_pick_v3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('gem-model-current-sake_pro')),
      findsNothing,
    );
    final saveStyle = saveButton.style?.textStyle?.resolve(<WidgetState>{});
    expect(saveStyle?.fontSize, 11);
    expect(saveStyle?.height, 1);
    expect(saveStyle?.fontWeight, FontWeight.w800);
    expect(
      saveButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      const Color(0xFFF4F3F6),
    );

    final groupTitleStyle = tester.widget<Text>(find.text('Recommended')).style;
    expect(groupTitleStyle?.fontSize, 9.5);
    expect(groupTitleStyle?.height, 1);
    expect(groupTitleStyle?.fontWeight, FontWeight.w600);
    expect(groupTitleStyle?.color, const Color(0x73FFFFFF));

    final modelTitleStyle = tester.widget<Text>(find.text('Top Pick V3')).style;
    expect(modelTitleStyle?.fontSize, 15);
    expect(modelTitleStyle?.height, 1);
    expect(modelTitleStyle?.fontWeight, FontWeight.w800);
    expect(modelTitleStyle?.color, const Color(0xFFF4F3F6));

    final estimateStyle = tester
        .widget<Text>(find.text('Estimated next message: 4 gems'))
        .style;
    expect(estimateStyle?.fontSize, 11);
    expect(estimateStyle?.height, 1);
    expect(estimateStyle?.fontWeight, FontWeight.w400);
    expect(estimateStyle?.color, const Color(0x73FFFFFF));
    final estimateText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('gem-model-estimate-top_pick_v3')),
    );
    final estimateSpan = estimateText.textSpan! as TextSpan;
    final gemsSpan = estimateSpan.children!.single as TextSpan;
    expect(gemsSpan.text, '4 gems');
    expect(gemsSpan.style?.fontSize, 11);
    expect(gemsSpan.style?.fontWeight, FontWeight.w800);
    expect(gemsSpan.style?.color, const Color(0xFFFF8A9A));

    final descriptionStyle = tester
        .widget<Text>(find.text('Balanced storytelling.'))
        .style;
    expect(descriptionStyle?.fontSize, 11);
    expect(descriptionStyle?.height, 1.45);
    expect(descriptionStyle?.fontWeight, FontWeight.w400);
    expect(descriptionStyle?.color, const Color(0x8FFFFFFF));

    expect(find.text('4-320 gems (memory from 2K to 156K)'), findsNothing);

    final hotStyle = tester.widget<Text>(find.text('Hot')).style;
    expect(hotStyle?.fontSize, 9.5);
    expect(hotStyle?.height, 1);
    expect(hotStyle?.fontWeight, FontWeight.w800);
    expect(hotStyle?.color, const Color(0xFFFF8A9A));
    expect(_tileBorder(tester, 'top_pick_v3').color, const Color(0xFFF82B3C));
    expect(
      _tileBorder(tester, 'sake_pro').color,
      Colors.white.withValues(alpha: 0.14),
    );
    expect(
      _tileColor(tester, 'top_pick_v3'),
      const Color(0xFFF82B3C).withValues(alpha: 0.10),
    );
    expect(_tileColor(tester, 'sake_pro'), const Color(0x0FFFFFFF));
    final selectedTileInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('gem-model-top_pick_v3')),
        matching: find.byType(InkWell),
      ),
    );
    expect(selectedTileInkWell.splashFactory, NoSplash.splashFactory);
    expect(
      selectedTileInkWell.overlayColor?.resolve(<WidgetState>{}),
      Colors.white.withValues(alpha: 0),
    );
    expect(
      _tagContainer(tester, 'hot').color,
      Colors.white.withValues(alpha: 0),
    );
    expect(_tagContainer(tester, 'hot').height, 19);
    expect(_tagContainer(tester, 'hot').borderColor, const Color(0xFFFF8A9A));
    expect(_tagContainer(tester, 'new').color, const Color(0xFFF82B3C));
    expect(_tagContainer(tester, 'new').height, 19);
    expect(
      tester.getCenter(find.text('Top Pick V3')).dy,
      closeTo(tester.getCenter(find.text('Hot')).dy, 0.5),
    );
    final estimateSize = tester.getSize(
      find.byKey(const ValueKey<String>('gem-model-estimate-top_pick_v3')),
    );
    final tileSize = tester.getSize(
      find.byKey(const ValueKey<String>('gem-model-top_pick_v3')),
    );
    expect(estimateSize.width, lessThan(tileSize.width));
    expect(estimateSize.height, 12);
    expect(_tagContainer(tester, 'hot').radius, 6);
    expect(_tagContainer(tester, 'new').radius, 6);
    expect(_tileBorder(tester, 'top_pick_v3').width, 1.5);
    expect(_tileBorder(tester, 'sake_pro').width, 1);
  });

  testWidgets('reports model page view once with the world id', (tester) async {
    final telemetry = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(telemetry);

    await tester.pumpWidget(
      _testApp(
        home: MemoryModelPage(
          worldId: 'W_000004',
          catalogLoader: (_) async => _catalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final events = telemetry.events
        .where((event) => event.name == 'switch_model_page')
        .toList();
    expect(events, hasLength(1));
    expect(events.single.data, <String, Object?>{
      'action_type': 'pay_event',
      'action': 'switch_model_page',
      'object1': 'W_000004',
    });
  });

  testWidgets('save submits the pending model for the current world', (
    tester,
  ) async {
    final telemetry = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(telemetry);
    final selections = <(String, String)>[];
    final cachedModelCodes = <String>[];
    final cachedModelTitles = <String>[];
    final selectionCompleter = Completer<GemModelSelection>();

    await tester.pumpWidget(
      _testApp(
        home: MemoryModelPage(
          worldId: 'W_000002',
          catalogLoader: (_) async => _catalog(),
          selectionHandler: (worldId, modelCode) async {
            selections.add((worldId, modelCode));
            return selectionCompleter.future;
          },
          selectedModelCacheWriter: (modelCode, modelTitle) async {
            cachedModelCodes.add(modelCode);
            cachedModelTitles.add(modelTitle);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('gem-model-sake_pro')));
    await tester.pump();

    expect(selections, isEmpty);
    expect(cachedModelCodes, isEmpty);
    expect(
      _tileBorder(tester, 'top_pick_v3').color,
      Colors.white.withValues(alpha: 0.14),
    );
    expect(_tileBorder(tester, 'sake_pro').color, const Color(0xFFF82B3C));
    expect(_tileColor(tester, 'top_pick_v3'), const Color(0x0FFFFFFF));
    expect(
      _tileColor(tester, 'sake_pro'),
      const Color(0xFFF82B3C).withValues(alpha: 0.10),
    );
    expect(
      find.byKey(const ValueKey('gem-model-current-top_pick_v3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('gem-model-current-sake_pro')),
      findsNothing,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('gem-model-save')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('gem-model-save')));
    await tester.pump();

    expect(selections, [('W_000002', 'sake_pro')]);
    final saveEvents = telemetry.events
        .where((event) => event.name == 'switch_model_save')
        .toList();
    expect(saveEvents, hasLength(1));
    expect(saveEvents.single.data, <String, Object?>{
      'action_type': 'pay_event',
      'action': 'switch_model_save',
      'object1': 'W_000002',
      'object2': 'sake_pro',
    });
    expect(
      find.byKey(const ValueKey('gem-model-save-loading')),
      findsOneWidget,
    );
    expect(find.text('Save'), findsNothing);

    selectionCompleter.complete(
      const GemModelSelection(selectedModelCode: 'sake_pro'),
    );
    await tester.pump();
    await tester.pump();

    expect(cachedModelCodes, ['sake_pro']);
    expect(cachedModelTitles, ['Sake Pro']);
    expect(
      _tileBorder(tester, 'top_pick_v3').color,
      Colors.white.withValues(alpha: 0.14),
    );
    expect(_tileBorder(tester, 'sake_pro').color, const Color(0xFFF82B3C));
    expect(find.text('Switched successfully'), findsOneWidget);
    expect(find.byKey(const ValueKey('gem-model-save-loading')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('failed save restores the server-selected model', (tester) async {
    final telemetry = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(telemetry);
    await tester.pumpWidget(
      _testApp(
        home: MemoryModelPage(
          worldId: 'W_000003',
          catalogLoader: (_) async => _catalog(),
          selectionHandler: (_, _) async => throw StateError('save failed'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('gem-model-sake_pro')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('gem-model-save')));
    await tester.pump();
    await tester.pump();

    expect(_tileBorder(tester, 'top_pick_v3').color, const Color(0xFFF82B3C));
    expect(
      _tileBorder(tester, 'sake_pro').color,
      Colors.white.withValues(alpha: 0.14),
    );
    expect(find.text('Switched failed'), findsOneWidget);
    expect(
      telemetry.events.where((event) => event.name == 'switch_model_save'),
      hasLength(1),
    );
    await tester.pump(const Duration(seconds: 2));
  });
}

class _CapturingTelemetrySink implements GenesisTelemetrySink {
  final events = <GenesisTelemetryEvent>[];

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    events.add(event);
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {}

  @override
  Future<void> setUserId(String? uid) async {}
}

BorderSide _tileBorder(WidgetTester tester, String modelCode) {
  final material = tester.widget<Material>(
    find.byKey(ValueKey<String>('gem-model-$modelCode')),
  );
  return (material.shape! as RoundedRectangleBorder).side;
}

Color _tileColor(WidgetTester tester, String modelCode) {
  return tester
      .widget<Material>(find.byKey(ValueKey<String>('gem-model-$modelCode')))
      .color!;
}

({Color? color, Color? borderColor, double? height, double? radius})
_tagContainer(WidgetTester tester, String tag) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey<String>('gem-model-tag-$tag')),
  );
  final decoration = container.decoration! as BoxDecoration;
  return (
    color: decoration.color,
    borderColor: decoration.border?.top.color,
    height: container.constraints?.maxHeight,
    radius: decoration.borderRadius?.resolve(TextDirection.ltr).topLeft.x,
  );
}

Widget _testApp({required Widget home}) {
  return MaterialApp(theme: GenesisTheme.worldoDark(), home: home);
}

void _gemModelTitleCacheTests() {
  test('catalog exposes every code to title pair', () {
    expect(_catalog().titlesByCode(), {
      'top_pick_v3': 'Top Pick V3',
      'sake_pro': 'Sake Pro',
    });
  });

  test('caching a model keeps titles learned earlier', () {
    final first = userInfoWithSelectedGemModel(
      const {'uid': 'u_1'},
      selectedModelCode: 'top_pick_v3',
      titlesByCode: const {'top_pick_v3': 'Top Pick V3'},
    );
    expect(first, {
      'uid': 'u_1',
      'selected_model_code': 'top_pick_v3',
      'selected_model_titles': {'top_pick_v3': 'Top Pick V3'},
    });

    final second = userInfoWithSelectedGemModel(
      first,
      selectedModelCode: 'sake_pro',
      titlesByCode: const {'sake_pro': 'Sake Pro'},
    );
    expect(second['selected_model_code'], 'sake_pro');
    expect(second['selected_model_titles'], {
      'top_pick_v3': 'Top Pick V3',
      'sake_pro': 'Sake Pro',
    });
  });

  test('a title-less save still records the code', () {
    expect(userInfoWithSelectedGemModel(null, selectedModelCode: 'sedna'), {
      'selected_model_code': 'sedna',
    });
  });

  test('titles survive the user info json round trip', () {
    final decoded = jsonDecode(
      jsonEncode(
        userInfoWithSelectedGemModel(
          const {},
          selectedModelCode: 'sedna',
          titlesByCode: const {'sedna': 'Sedna'},
        ),
      ),
    );
    expect(
      gemModelTitlesFromUserInfo(Map<String, dynamic>.from(decoded as Map)),
      {'sedna': 'Sedna'},
    );
  });
}

GemModelCatalog _catalog() {
  return const GemModelCatalog(
    selectedModelCode: 'top_pick_v3',
    groups: [
      GemModelGroup(
        groupCode: 'recommended',
        groupTitle: 'Recommended',
        models: [
          GemModel(
            modelCode: 'top_pick_v3',
            title: 'Top Pick V3',
            tags: ['hot'],
            estimatedNextMessageGems: 4,
            estimatedNextTickGems: 4,
            description: 'Balanced storytelling.',
            rangeText: '4-320 gems (memory from 2K to 156K)',
          ),
          GemModel(
            modelCode: 'sake_pro',
            title: 'Sake Pro',
            tags: ['new'],
            estimatedNextMessageGems: 3,
            estimatedNextTickGems: 3,
            description: 'Flexible storytelling.',
            rangeText: '3-160 gems (memory from 2K to 156K)',
          ),
        ],
      ),
    ],
  );
}
