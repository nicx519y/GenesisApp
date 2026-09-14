import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/gem_model.dart';
import 'package:genesis_flutter_android/network/models/user_memory_settings.dart';
import 'package:genesis_flutter_android/pages/gems/memory_model_page.dart';
import 'package:genesis_flutter_android/pages/gems/memory_model_page_cache.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

void main() {
  tearDown(GenesisTelemetry.resetForTesting);

  test('memory slider uses dynamic logarithmic integer token mapping', () {
    expect(
      memorySliderValueForTokens(
        8000,
        minMemoryTokens: 8000,
        maxMemoryTokens: 1000000,
      ),
      0,
    );
    expect(
      memorySliderValueForTokens(
        1000000,
        minMemoryTokens: 8000,
        maxMemoryTokens: 1000000,
      ),
      1,
    );
    final value = memorySliderValueForTokens(
      48000,
      minMemoryTokens: 8000,
      maxMemoryTokens: 1000000,
    );
    expect(value, closeTo(0.371, 0.001));
    expect(
      memoryTokensForSliderValue(
        value,
        minMemoryTokens: 8000,
        maxMemoryTokens: 1000000,
      ),
      48000,
    );
    expect(
      memoryTokensForSliderValue(
        memorySliderValueForTokens(
          48400,
          minMemoryTokens: 8000,
          maxMemoryTokens: 1000000,
        ),
        minMemoryTokens: 8000,
        maxMemoryTokens: 1000000,
      ),
      48000,
    );
    expect(
      memoryTokensForSliderValue(
        memorySliderValueForTokens(
          48600,
          minMemoryTokens: 8000,
          maxMemoryTokens: 1000000,
        ),
        minMemoryTokens: 8000,
        maxMemoryTokens: 1000000,
      ),
      49000,
    );
    expect(
      memoryTokensForSliderValue(
        0,
        minMemoryTokens: 8500,
        maxMemoryTokens: 1000500,
      ),
      8500,
    );
    expect(
      memoryTokensForSliderValue(
        1,
        minMemoryTokens: 8500,
        maxMemoryTokens: 1000500,
      ),
      1000500,
    );
    expect(formatMemoryTokens(0), '0');
    expect(formatMemoryTokens(12400), '12.4K');
    expect(formatMemoryTokens(1000000), '1M');
  });

  testWidgets('renders actual usage, budget, and flat model list', (
    tester,
  ) async {
    await _setReferenceSurface(tester);
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_LAYOUT',
          memorySettingsLoader: _FakeMemoryApi(usedTokens: 11000).load,
          catalogLoader: (_) async => _catalogWithTwoGroups(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Memory & Model'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('memory-model-current-usage')),
      findsOneWidget,
    );
    expect(find.text('11K'), findsOneWidget);
    expect(find.text('Your current memory usage'), findsOneWidget);
    expect(find.text('48K'), findsOneWidget);
    expect(find.text('8K'), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('Apply to all Worldos'), findsNothing);
    expect(find.byKey(const ValueKey('gem-model-save')), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Recommended'), findsNothing);
    expect(find.text('More'), findsNothing);
    expect(find.text('Top Pick V3'), findsOneWidget);
    expect(find.text('Sake Pro'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('4-320 gems (memory from 2K to 156K)'), findsOneWidget);
    expect(_tileBorder(tester, 'top_pick_v3').color, GenesisColors.redPrimary);
    expect(_tileBorder(tester, 'sake_pro').color, GenesisColors.darkCardBorder);
    final hot = _tagDecoration(tester, 'hot');
    expect(hot.color, Colors.transparent);
    expect(hot.border?.top.color, GenesisColors.redSecondary);
    expect(_tagDecoration(tester, 'new').color, GenesisColors.redPrimary);

    final cardRect = tester.getRect(
      find.byKey(const ValueKey('memory-model-max-memory-card')),
    );
    final sliderRect = tester.getRect(
      find.byKey(const ValueKey('memory-model-max-memory-slider')),
    );
    final pointerRect = tester.getRect(
      find.byKey(const ValueKey('memory-model-max-memory-pointer')),
    );
    const thumbRadius = 10.0;
    expect(sliderRect.left + thumbRadius - cardRect.left, moreOrLessEquals(14));
    expect(
      cardRect.right - (sliderRect.right - thumbRadius),
      moreOrLessEquals(14),
    );
    expect(sliderRect.height, 48);
    final sliderTheme = tester.widget<SliderTheme>(
      find.ancestor(
        of: find.byKey(const ValueKey('memory-model-max-memory-slider')),
        matching: find.byType(SliderTheme),
      ),
    );
    final overlayShape = sliderTheme.data.overlayShape;
    expect(overlayShape, isA<RoundSliderOverlayShape>());
    expect((overlayShape! as RoundSliderOverlayShape).overlayRadius, 24);
    final sliderValue = memorySliderValueForTokens(
      48000,
      minMemoryTokens: 8000,
      maxMemoryTokens: 1000000,
    );
    final thumbCenterX =
        sliderRect.left +
        thumbRadius +
        sliderValue * (sliderRect.width - thumbRadius * 2);
    expect(pointerRect.center.dx, moreOrLessEquals(thumbCenterX));
    final thumbTop = sliderRect.center.dy - thumbRadius;
    expect(thumbTop - pointerRect.bottom, moreOrLessEquals(2));
  });

  testWidgets('memory and model loading states do not block each other', (
    tester,
  ) async {
    final catalogCompleter = Completer<GemModelCatalog>();
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_LOADING',
          memorySettingsLoader: _FakeMemoryApi(usedTokens: 7000).load,
          catalogLoader: (_) => catalogCompleter.future,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('7K'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('gem-model-page-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('gem-model-page-loading-skeleton')),
      findsOneWidget,
    );
    catalogCompleter.complete(_catalog());
    await tester.pumpAndSettle();

    final memoryCompleter = Completer<UserMemorySettings>();
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_MEMORY_LOADING',
          memorySettingsLoader: (_) => memoryCompleter.future,
          catalogLoader: (_) async => _catalog(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Top Pick V3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('memory-settings-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memory-settings-loading-skeleton')),
      findsOneWidget,
    );
    memoryCompleter.complete(_worldSettings('W_MEMORY_LOADING'));
    await tester.pumpAndSettle();
  });

  testWidgets('reuses both settings responses within one WorldPage cache', (
    tester,
  ) async {
    final pageCache = MemoryModelPageCache();
    var memoryLoads = 0;
    var modelLoads = 0;

    Widget page() => _testApp(
      MemoryModelPage(
        worldId: 'W_CACHED',
        pageCache: pageCache,
        memorySettingsLoader: (_) async {
          memoryLoads += 1;
          return _worldSettings('W_CACHED');
        },
        catalogLoader: (_) async {
          modelLoads += 1;
          return _catalog();
        },
      ),
    );

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(memoryLoads, 1);
    expect(modelLoads, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(memoryLoads, 1);
    expect(modelLoads, 1);

    pageCache.dispose();
    expect(pageCache.memorySettings, isNull);
    expect(pageCache.modelCatalog, isNull);
  });

  testWidgets('memory autosave waits 500ms and keeps only latest value', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi();
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_DEBOUNCE',
          memorySettingsLoader: memoryApi.load,
          memorySettingsUpdater: memoryApi.update,
          catalogLoader: (_) async => _catalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _setSliderValue(tester, .75);
    await tester.pump(const Duration(milliseconds: 300));
    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 499));
    expect(memoryApi.updates, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(memoryApi.updates, [1000000]);
  });

  testWidgets('model saves immediately while memory keeps 500ms debounce', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi();
    final selections = <String>[];
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_TIMERS',
          memorySettingsLoader: memoryApi.load,
          memorySettingsUpdater: memoryApi.update,
          catalogLoader: (_) async => _catalog(),
          selectionHandler: (_, code) async {
            selections.add(code);
            return GemModelSelection(selectedModelCode: code);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(
      find.byKey(const ValueKey('gem-model-sake_pro')),
    );
    await tester.tap(find.byKey(const ValueKey('gem-model-sake_pro')));
    await tester.pump();
    expect(memoryApi.updates, isEmpty);
    expect(selections, ['sake_pro']);
    await tester.pump(const Duration(milliseconds: 299));
    expect(memoryApi.updates, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(memoryApi.updates, [1000000]);
  });

  testWidgets('new memory revision waits for the in-flight request', (
    tester,
  ) async {
    final calls = <int>[];
    final first = Completer<UserMemorySettings>();
    var budget = 48000;
    Future<UserMemorySettings> loader(String? worldId) async => worldId == null
        ? _globalSettings(budget)
        : _worldSettings(worldId, memoryTokens: budget);
    Future<UserMemorySettings> updater(int value) {
      calls.add(value);
      if (calls.length == 1) return first.future;
      budget = value;
      return Future.value(_globalSettings(value));
    }

    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_SERIAL',
          memorySettingsLoader: loader,
          memorySettingsUpdater: updater,
          catalogLoader: (_) async => _catalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, [1000000]);
    _setSliderValue(tester, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, [1000000]);

    budget = 1000000;
    first.complete(_globalSettings(1000000));
    await tester.pump();
    await tester.pump();
    expect(calls, [1000000, 8000]);
  });

  testWidgets('memory save refreshes actual usage and model quotations', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi(usedTokens: 6000);
    var catalogLoads = 0;
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_REFRESH',
          memorySettingsLoader: memoryApi.load,
          memorySettingsUpdater: (tokens) async {
            memoryApi.usedTokens = 9000;
            return memoryApi.update(tokens);
          },
          catalogLoader: (_) async {
            catalogLoads += 1;
            return _catalog();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('6K'), findsOneWidget);

    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('9K'), findsOneWidget);
    expect(catalogLoads, 2);
    expect(memoryApi.loads, ['W_REFRESH', 'W_REFRESH']);
  });

  testWidgets(
    'uncertain memory result reconciles once and is not retried on exit',
    (tester) async {
      final memoryApi = _FakeMemoryApi();
      final attempts = <int>[];
      await tester.pumpWidget(
        _routeTestApp(
          MemoryModelPage(
            worldId: 'W_UNCERTAIN',
            memorySettingsLoader: memoryApi.load,
            memorySettingsUpdater: (tokens) async {
              attempts.add(tokens);
              throw ApiException(
                message: 'system error',
                code: 5000,
                kind: ApiExceptionKind.business,
              );
            },
            catalogLoader: (_) async => _catalog(),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      _setSliderValue(tester, 1);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(attempts, [1000000]);
      expect(memoryApi.loads, ['W_UNCERTAIN', null]);
      expect(find.text('Save result not confirmed'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.text('Open'), findsOneWidget);
      expect(attempts, [1000000]);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('definite memory failure stays dirty and retries on exit', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _routeTestApp(
        MemoryModelPage(
          worldId: 'W_FAILED',
          memorySettingsLoader: _FakeMemoryApi().load,
          memorySettingsUpdater: (_) async {
            attempts += 1;
            throw StateError('save failed');
          },
          catalogLoader: (_) async => _catalog(),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(attempts, 1);
    expect(find.text('Save failed'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Open'), findsOneWidget);
    expect(attempts, 2);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'back pops immediately and flushes pending changes in background',
    (tester) async {
      final updateStarted = Completer<void>();
      final updateFinished = Completer<UserMemorySettings>();
      await tester.pumpWidget(
        _routeTestApp(
          MemoryModelPage(
            worldId: 'W_EXIT',
            memorySettingsLoader: _FakeMemoryApi().load,
            memorySettingsUpdater: (tokens) {
              updateStarted.complete();
              return updateFinished.future;
            },
            catalogLoader: (_) async => _catalog(),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      _setSliderValue(tester, 1);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.text('Open'), findsOneWidget);
      expect(updateStarted.isCompleted, isTrue);
      expect(updateFinished.isCompleted, isFalse);

      updateFinished.complete(_globalSettings(1000000));
      await tester.pump();
    },
  );

  testWidgets('missing world usage shows memory error without hiding models', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_MISSING_USAGE',
          memorySettingsLoader: (_) async => _globalSettings(48000),
          catalogLoader: (_) async => _catalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('memory-settings-load-error')),
      findsOneWidget,
    );
    expect(find.text('Top Pick V3'), findsOneWidget);
  });

  testWidgets('reference layout scrolls on a small large-text viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.4),
        ),
        child: _testApp(
          MemoryModelPage(
            worldId: 'W_SMALL',
            memorySettingsLoader: _FakeMemoryApi().load,
            catalogLoader: (_) async => _catalogWithTwoGroups(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gem-model-water')),
      200,
    );
    expect(find.text('Water'), findsOneWidget);
  });

  testWidgets('reports model page and autosave telemetry', (tester) async {
    final telemetry = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(telemetry);
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_TELEMETRY',
          memorySettingsLoader: _FakeMemoryApi().load,
          catalogLoader: (_) async => _catalog(),
          selectionHandler: (_, code) async =>
              GemModelSelection(selectedModelCode: code),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('gem-model-sake_pro')),
    );
    await tester.tap(find.byKey(const ValueKey('gem-model-sake_pro')));
    await tester.pump();

    expect(
      telemetry.events.where((event) => event.name == 'switch_model_page'),
      hasLength(1),
    );
    final saves = telemetry.events
        .where((event) => event.name == 'switch_model_save')
        .toList();
    expect(saves, hasLength(1));
    expect(saves.single.data['object1'], 'W_TELEMETRY');
    expect(saves.single.data['object2'], 'sake_pro');
  });
}

Future<void> _setReferenceSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _testApp(Widget home) => MaterialApp(home: home);

Widget _routeTestApp(Widget page) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push<String>(MaterialPageRoute<String>(builder: (_) => page)),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

void _setSliderValue(WidgetTester tester, double value) {
  final slider = tester.widget<Slider>(
    find.byKey(const ValueKey('memory-model-max-memory-slider')),
  );
  slider.onChanged!(value);
}

BorderSide _tileBorder(WidgetTester tester, String modelCode) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byKey(ValueKey<String>('gem-model-$modelCode')),
          matching: find.byType(Material),
        )
        .first,
  );
  return (material.shape! as RoundedRectangleBorder).side;
}

BoxDecoration _tagDecoration(WidgetTester tester, String tag) {
  return tester
          .widget<Container>(find.byKey(ValueKey<String>('gem-model-tag-$tag')))
          .decoration!
      as BoxDecoration;
}

class _FakeMemoryApi {
  _FakeMemoryApi({this.usedTokens = 6000});

  final List<String?> loads = <String?>[];
  final List<int> updates = <int>[];
  int globalValue = 48000;
  int usedTokens;

  Future<UserMemorySettings> load(String? worldId) async {
    loads.add(worldId);
    final normalized = worldId?.trim() ?? '';
    return normalized.isEmpty
        ? _globalSettings(globalValue)
        : _worldSettings(
            normalized,
            memoryTokens: globalValue,
            usedTokens: usedTokens.clamp(0, globalValue),
          );
  }

  Future<UserMemorySettings> update(int memoryTokens) async {
    updates.add(memoryTokens);
    globalValue = memoryTokens;
    return _globalSettings(memoryTokens);
  }
}

UserMemorySettings _globalSettings(int memoryTokens) => UserMemorySettings(
  memoryTokens: memoryTokens,
  minMemoryTokens: 8000,
  maxMemoryTokens: 1000000,
);

UserMemorySettings _worldSettings(
  String worldId, {
  int memoryTokens = 48000,
  int usedTokens = 6000,
}) => UserMemorySettings(
  memoryTokens: memoryTokens,
  minMemoryTokens: 8000,
  maxMemoryTokens: 1000000,
  worldId: worldId,
  memoryUsedTokens: usedTokens,
);

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

GemModelCatalog _catalog() => const GemModelCatalog(
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
          estimatedNextMessageGemsCent: 400,
          estimatedNextTickGemsCent: 400,
          description: 'Balanced storytelling.',
          rangeText: '4-320 gems (memory from 2K to 156K)',
        ),
        GemModel(
          modelCode: 'sake_pro',
          title: 'Sake Pro',
          tags: ['new'],
          estimatedNextMessageGemsCent: 300,
          estimatedNextTickGemsCent: 300,
          description: 'Flexible storytelling.',
          rangeText: '3-160 gems (memory from 2K to 156K)',
        ),
      ],
    ),
  ],
);

GemModelCatalog _catalogWithTwoGroups() => const GemModelCatalog(
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
          estimatedNextMessageGemsCent: 400,
          estimatedNextTickGemsCent: 400,
          description: 'Balanced storytelling.',
          rangeText: '4-320 gems (memory from 2K to 156K)',
        ),
        GemModel(
          modelCode: 'sake_pro',
          title: 'Sake Pro',
          tags: ['new'],
          estimatedNextMessageGemsCent: 300,
          estimatedNextTickGemsCent: 300,
          description: 'Flexible storytelling.',
          rangeText: '3-160 gems (memory from 2K to 156K)',
        ),
      ],
    ),
    GemModelGroup(
      groupCode: 'more',
      groupTitle: 'More',
      models: [
        GemModel(
          modelCode: 'water',
          title: 'Water',
          tags: [],
          estimatedNextMessageGemsCent: 200,
          estimatedNextTickGemsCent: 200,
          description: 'Fast roleplay.',
          rangeText: '2-80 gems (memory from 2K to 156K)',
        ),
      ],
    ),
  ],
);
