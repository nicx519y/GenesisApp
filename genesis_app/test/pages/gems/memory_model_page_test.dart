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
import 'package:genesis_flutter_android/ui/components/genesis_refresh_indicator.dart';

void main() {
  tearDown(GenesisTelemetry.resetForTesting);

  testWidgets('ranges show one decimal gems and whole K memory', (
    tester,
  ) async {
    for (final scenario in [
      (500, 12400, '1K', '13K'),
      (2400, 12400, '3K', '13K'),
      (32000, 32000, '32K', '32K'),
      (31999, 32000, '32K', '32K'),
      (32000, 1000000, '32K', '1M'),
    ]) {
      await tester.pumpWidget(
        _testApp(
          MemoryModelPage(
            key: ValueKey(scenario),
            worldId: 'W_RANGE',
            memorySettingsLoader: (_) async => _worldSettings(
              'W_RANGE',
              memoryTokens: scenario.$2,
              usedTokens: scenario.$1,
            ),
            catalogLoader: (_) async =>
                _quotationCatalog(memoryTokens: scenario.$2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          scenario.$3 == scenario.$4
              ? '2.2–4.8 gems (memory ${scenario.$3})'
              : '2.2–4.8 gems (memory ${scenario.$3} → ${scenario.$4})',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Estimated next message 2.2 gems',
          findRichText: true,
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('equal prices and equal memory endpoints collapse', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_EQUAL',
          memorySettingsLoader: (_) async =>
              _worldSettings('W_EQUAL', memoryTokens: 32000, usedTokens: 32000),
          catalogLoader: (_) async => _quotationCatalog(
            memoryTokens: 32000,
            minCent: 483,
            maxCent: 483,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4.8 gems (memory 32K)'), findsOneWidget);
  });

  testWidgets(
    'save publishes price and memory together after both reads finish',
    (tester) async {
      final memoryApi = _FakeMemoryApi();
      final cache = MemoryModelPageCache();
      final refreshedCatalog = Completer<GemModelCatalog>();
      var loads = 0;
      await tester.pumpWidget(
        _testApp(
          MemoryModelPage(
            worldId: 'W_ATOMIC',
            pageCache: cache,
            memorySettingsLoader: memoryApi.load,
            memorySettingsUpdater: (tokens) async {
              memoryApi.usedTokens = 9000;
              return memoryApi.update(tokens);
            },
            catalogLoader: (_) async =>
                ++loads == 1 ? _quotationCatalog() : refreshedCatalog.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      _setSliderValue(tester, 1);
      await tester.pump(const Duration(milliseconds: 499));
      expect(loads, 1);
      expect(find.text('2.2–4.8 gems (memory 6K → 48K)'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('2.2–4.8 gems (memory 6K → 48K)'), findsOneWidget);
      expect(find.text('9K'), findsNothing);
      expect(cache.modelCatalog, isNull);
      expect(cache.memorySettings, isNull);
      refreshedCatalog.complete(
        _quotationCatalog(memoryTokens: 1000000, minCent: 300, maxCent: 900),
      );
      await tester.pump();
      expect(find.text('3.0–9.0 gems (memory 9K → 1M)'), findsOneWidget);
      expect(
        find.textContaining(
          'Estimated next message 3.0 gems',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(cache.memorySettings!.memoryTokens, 1000000);
      expect(
        cache.modelCatalog!.groups.single.models.single.minMemoryTokens,
        1000000,
      );
    },
  );

  testWidgets(
    'failed quotation refresh shows bones with real memory and retry',
    (tester) async {
      final memoryApi = _FakeMemoryApi();
      final cache = MemoryModelPageCache();
      var loads = 0;
      await tester.pumpWidget(
        _testApp(
          MemoryModelPage(
            worldId: 'W_PRICE_ERROR',
            pageCache: cache,
            memorySettingsLoader: memoryApi.load,
            memorySettingsUpdater: memoryApi.update,
            catalogLoader: (_) async {
              if (++loads == 2) throw TimeoutException('quotation timeout');
              return _quotationCatalog(memoryTokens: memoryApi.globalValue);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      _setSliderValue(tester, 1);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('gem-model-estimate-loading-miranda')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('gem-model-price-loading-miranda')),
        findsOneWidget,
      );
      expect(find.text('memory 6K → 1M'), findsOneWidget);
      expect(cache.modelCatalog, isNull);
      await tester.tap(find.byKey(const ValueKey('gem-model-ranges-retry')));
      await tester.pumpAndSettle();
      expect(find.text('2.2–4.8 gems (memory 6K → 1M)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('gem-model-ranges-retry')),
        findsNothing,
      );
    },
  );

  testWidgets('failed usage refresh never invents a memory range', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi();
    final cache = MemoryModelPageCache();
    var loads = 0;
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_USAGE_ERROR',
          pageCache: cache,
          memorySettingsLoader: (world) async {
            if (++loads == 2) throw TimeoutException('usage timeout');
            return memoryApi.load(world);
          },
          memorySettingsUpdater: memoryApi.update,
          catalogLoader: (_) async =>
              _quotationCatalog(memoryTokens: memoryApi.globalValue),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('2.2–4.8 gems'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('gem-model-memory-loading-miranda')),
      findsOneWidget,
    );
    expect(find.textContaining('memory 6K'), findsNothing);
    expect(cache.memorySettings, isNull);
    await tester.tap(find.byKey(const ValueKey('gem-model-ranges-retry')));
    await tester.pumpAndSettle();
    expect(find.text('2.2–4.8 gems (memory 6K → 1M)'), findsOneWidget);
  });

  testWidgets('mismatched quotation budget cannot appear as current price', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_MISMATCH',
          memorySettingsLoader: (_) async => _worldSettings('W_MISMATCH'),
          catalogLoader: (_) async => _quotationCatalog(memoryTokens: 12400),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('gem-model-price-loading-miranda')),
      findsOneWidget,
    );
    expect(find.text('memory 6K → 48K'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('gem-model-ranges-retry')),
      findsOneWidget,
    );
  });

  testWidgets('old world snapshot cannot overwrite new world or its cache', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi();
    final oldQuotes = Completer<GemModelCatalog>();
    final cache = MemoryModelPageCache();
    var oldLoads = 0;
    Widget page(String world) => _testApp(
      MemoryModelPage(
        worldId: world,
        pageCache: cache,
        memorySettingsLoader: memoryApi.load,
        memorySettingsUpdater: memoryApi.update,
        catalogLoader: (id) async {
          if (id == 'OLD' && ++oldLoads > 1) return oldQuotes.future;
          return _quotationCatalog(
            memoryTokens: memoryApi.globalValue,
            minCent: id == 'NEW' ? 999 : 216,
            maxCent: 1200,
          );
        },
      ),
    );
    await tester.pumpWidget(page('OLD'));
    await tester.pumpAndSettle();
    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pumpWidget(page('NEW'));
    await tester.pumpAndSettle();
    oldQuotes.complete(_quotationCatalog(memoryTokens: 1000000));
    await tester.pumpAndSettle();
    expect(find.text('10.0–12.0 gems (memory 6K → 1M)'), findsOneWidget);
    expect(cache.memorySettings!.worldId, 'NEW');
    expect(cache.modelCatalog!.groups.single.models.single.minGemsCent, 999);
  });

  testWidgets('older refresh cannot overwrite a newer saved snapshot', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi();
    final cache = MemoryModelPageCache();
    final oldQuotes = Completer<GemModelCatalog>();
    final oldMemory = Completer<UserMemorySettings>();
    var catalogLoads = 0;
    var memoryLoads = 0;
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_ORDER',
          pageCache: cache,
          memorySettingsUpdater: memoryApi.update,
          memorySettingsLoader: (id) async =>
              ++memoryLoads == 2 ? oldMemory.future : memoryApi.load(id),
          catalogLoader: (_) async => ++catalogLoads == 2
              ? oldQuotes.future
              : _quotationCatalog(memoryTokens: memoryApi.globalValue),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _setSliderValue(tester, 1);
    final oldRefresh = tester
        .widget<GenesisRefreshIndicator>(find.byType(GenesisRefreshIndicator))
        .onRefresh();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('2.2–4.8 gems (memory 6K → 1M)'), findsOneWidget);
    oldMemory.complete(_worldSettings('W_ORDER'));
    oldQuotes.complete(_quotationCatalog());
    await oldRefresh;
    await tester.pumpAndSettle();
    expect(find.text('2.2–4.8 gems (memory 6K → 1M)'), findsOneWidget);
    expect(cache.memorySettings!.memoryTokens, 1000000);
    expect(
      cache.modelCatalog!.groups.single.models.single.minMemoryTokens,
      1000000,
    );
  });

  testWidgets(
    'serial saves retain newer drag and finish with matching ranges',
    (tester) async {
      final memoryApi = _FakeMemoryApi();
      final firstQuotes = Completer<GemModelCatalog>();
      var loads = 0;
      await tester.pumpWidget(
        _testApp(
          MemoryModelPage(
            worldId: 'W_SERIAL',
            memorySettingsLoader: memoryApi.load,
            memorySettingsUpdater: memoryApi.update,
            catalogLoader: (_) async => ++loads == 2
                ? firstQuotes.future
                : _quotationCatalog(memoryTokens: memoryApi.globalValue),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _setSliderValue(tester, 1);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      _setSliderValue(tester, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(memoryApi.updates, [1000000]);
      firstQuotes.complete(_quotationCatalog(memoryTokens: 1000000));
      await tester.pumpAndSettle();
      expect(memoryApi.updates, [1000000, 4000]);
      expect(find.text('2.2–4.8 gems (memory 4K)'), findsOneWidget);
    },
  );

  testWidgets('reentry reuses the saved pair without extra requests', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi();
    final cache = MemoryModelPageCache();
    var catalogLoads = 0;
    Widget page() => _testApp(
      MemoryModelPage(
        worldId: 'W_CACHE_RANGE',
        pageCache: cache,
        memorySettingsLoader: memoryApi.load,
        memorySettingsUpdater: memoryApi.update,
        catalogLoader: (_) async {
          catalogLoads++;
          return _quotationCatalog(memoryTokens: memoryApi.globalValue);
        },
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(catalogLoads, 2);
    expect(memoryApi.loads, ['W_CACHE_RANGE', 'W_CACHE_RANGE']);
    expect(find.text('2.2–4.8 gems (memory 6K → 1M)'), findsOneWidget);
  });

  testWidgets(
    'quotation refresh preserves a concurrently saved model selection',
    (tester) async {
      final memoryApi = _FakeMemoryApi();
      final cache = MemoryModelPageCache();
      final selected = Completer<GemModelSelection>();
      final quotes = Completer<GemModelCatalog>();
      var loads = 0;
      await tester.pumpWidget(
        _testApp(
          MemoryModelPage(
            worldId: 'W_SELECTION_RACE',
            pageCache: cache,
            memorySettingsLoader: memoryApi.load,
            memorySettingsUpdater: memoryApi.update,
            selectionHandler: (_, _) => selected.future,
            catalogLoader: (_) async =>
                ++loads == 1 ? _catalog() : quotes.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('gem-model-sake_pro')),
      );
      await tester.tap(find.byKey(const ValueKey('gem-model-sake_pro')));
      _setSliderValue(tester, 1);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      selected.complete(const GemModelSelection(selectedModelCode: 'sake_pro'));
      await tester.pump();
      // The quotation response still reflects selection before POST completed.
      quotes.complete(_catalog(memoryTokens: 1000000));
      await tester.pumpAndSettle();
      expect(_tileBorder(tester, 'sake_pro').color, GenesisColors.redPrimary);
      expect(cache.modelCatalog!.selectedModelCode, 'sake_pro');
    },
  );

  testWidgets(
    'model selection completing after exit updates only valid cache',
    (tester) async {
      final memoryApi = _FakeMemoryApi();
      final cache = MemoryModelPageCache();
      final selected = Completer<GemModelSelection>();
      await tester.pumpWidget(
        _testApp(
          MemoryModelPage(
            worldId: 'W_EXIT_SELECTION',
            pageCache: cache,
            memorySettingsLoader: memoryApi.load,
            catalogLoader: (_) async => _catalog(),
            selectionHandler: (_, _) => selected.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('gem-model-sake_pro')),
      );
      await tester.tap(find.byKey(const ValueKey('gem-model-sake_pro')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      selected.complete(const GemModelSelection(selectedModelCode: 'sake_pro'));
      await tester.pumpAndSettle();
      expect(cache.modelCatalog!.selectedModelCode, 'sake_pro');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('memory save failure returns to the latest successful budget', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi();
    var attempts = 0;
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_ROLLBACK',
          memorySettingsLoader: memoryApi.load,
          memorySettingsUpdater: (tokens) async {
            if (++attempts > 1) throw StateError('save failed');
            return memoryApi.update(tokens);
          },
          catalogLoader: (_) async =>
              _quotationCatalog(memoryTokens: memoryApi.globalValue),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    _setSliderValue(tester, 0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(_sliderTokens(tester), 1000000);
    expect(find.text('2.2–4.8 gems (memory 6K → 1M)'), findsOneWidget);
    // The rejected draft is cleared, but a new intentional attempt is allowed.
    _setSliderValue(tester, 0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(attempts, 3);
    expect(_sliderTokens(tester), 1000000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'model save failure returns to latest success without exit retry',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _routeTestApp(
          MemoryModelPage(
            worldId: 'W_MODEL_ROLLBACK',
            memorySettingsLoader: _FakeMemoryApi().load,
            catalogLoader: (_) async => _catalog(),
            selectionHandler: (_, code) async {
              calls.add(code);
              if (code == 'top_pick_v3') throw StateError('selection failed');
              return GemModelSelection(selectedModelCode: code);
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('gem-model-sake_pro')),
      );
      await tester.tap(find.byKey(const ValueKey('gem-model-sake_pro')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('gem-model-top_pick_v3')),
      );
      await tester.tap(find.byKey(const ValueKey('gem-model-top_pick_v3')));
      await tester.pumpAndSettle();
      expect(_tileBorder(tester, 'sake_pro').color, GenesisColors.redPrimary);
      expect(
        _tileBorder(tester, 'top_pick_v3').color,
        GenesisColors.darkCardBorder,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(calls, ['sake_pro', 'top_pick_v3']);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('older memory failure does not undo a newer drag', (
    tester,
  ) async {
    final memoryApi = _FakeMemoryApi();
    final first = Completer<UserMemorySettings>();
    final second = Completer<UserMemorySettings>();
    var attempts = 0;
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_MEMORY_LATE_ERROR',
          memorySettingsLoader: memoryApi.load,
          memorySettingsUpdater: (_) =>
              ++attempts == 1 ? first.future : second.future,
          catalogLoader: (_) async =>
              _quotationCatalog(memoryTokens: memoryApi.globalValue),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _setSliderValue(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    _setSliderValue(tester, 0);
    await tester.pump(const Duration(milliseconds: 500));
    first.completeError(StateError('old request failed'));
    await tester.pump();
    expect(_sliderTokens(tester), 4000);
    expect(attempts, 2);
    second.completeError(StateError('current request failed'));
    await tester.pumpAndSettle();
    expect(_sliderTokens(tester), 48000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('older model failure does not undo a newer selection', (
    tester,
  ) async {
    final first = Completer<GemModelSelection>();
    final second = Completer<GemModelSelection>();
    var attempts = 0;
    await tester.pumpWidget(
      _testApp(
        MemoryModelPage(
          worldId: 'W_MODEL_LATE_ERROR',
          memorySettingsLoader: _FakeMemoryApi().load,
          catalogLoader: (_) async => _catalogWithTwoGroups(),
          selectionHandler: (_, _) =>
              ++attempts == 1 ? first.future : second.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('gem-model-sake_pro')),
    );
    await tester.tap(find.byKey(const ValueKey('gem-model-sake_pro')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('gem-model-water')));
    await tester.tap(find.byKey(const ValueKey('gem-model-water')));
    await tester.pump();
    first.completeError(StateError('old selection failed'));
    await tester.pump();
    expect(_tileBorder(tester, 'water').color, GenesisColors.redPrimary);
    second.completeError(StateError('current selection failed'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('gem-model-top_pick_v3')),
    );
    expect(_tileBorder(tester, 'top_pick_v3').color, GenesisColors.redPrimary);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('bubble follows the real slider thumb on every drag frame', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [390.0, 320.0]) {
      for (final direction in TextDirection.values) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        final memoryApi = _FakeMemoryApi();
        await tester.pumpWidget(
          _testApp(
            Directionality(
              textDirection: direction,
              child: MemoryModelPage(
                key: ValueKey('$width-$direction'),
                worldId: 'W_GEOMETRY',
                memorySettingsLoader: memoryApi.load,
                memorySettingsUpdater: memoryApi.update,
                catalogLoader: (_) async =>
                    _quotationCatalog(memoryTokens: memoryApi.globalValue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sliderFinder = find.byKey(
          const ValueKey('memory-model-max-memory-slider'),
        );
        Offset paintedThumbCenter() {
          final target = find.descendant(
            of: sliderFinder,
            matching: find.byType(CompositedTransformTarget),
          );
          final box = tester.renderObject<RenderBox>(target);
          Offset? center;
          expect(
            box,
            paints..something((method, arguments) {
              if (method == #drawCircle && arguments[1] == 10.0) {
                center = box.localToGlobal(arguments[0] as Offset);
                return true;
              }
              return false;
            }),
          );
          return center!;
        }

        final sliderRect = tester.getRect(sliderFinder);
        final gesture = await tester.startGesture(paintedThumbCenter());
        for (final fraction in [0.0, .1, .25, .5, .75, .9, 1.0]) {
          await gesture.moveTo(
            Offset(
              sliderRect.left + 24 + fraction * (sliderRect.width - 48),
              sliderRect.center.dy,
            ),
          );
          await tester.pump(const Duration(milliseconds: 16));
          final thumb = paintedThumbCenter();
          final pointer = tester.getRect(
            find.byKey(const ValueKey('memory-model-max-memory-pointer')),
          );
          final bubble = tester.getRect(
            find.byKey(const ValueKey('memory-model-max-memory-value')),
          );
          expect(
            pointer.center.dx,
            closeTo(thumb.dx, .01),
            reason: '$width $direction $fraction pointer',
          );
          expect(
            bubble.center.dx,
            closeTo(thumb.dx, .01),
            reason: '$width $direction $fraction bubble',
          );
          expect(thumb.dy - 10 - pointer.bottom, closeTo(2, .01));
          expect(bubble.left, greaterThanOrEqualTo(0));
          expect(bubble.right, lessThanOrEqualTo(width));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });

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
    expect(formatMemoryTokens(12400), '13K');
    expect(formatMemoryTokens(10200), '11K');
    expect(formatMemoryTokens(1), '1K');
    expect(formatMemoryTokens(999001), '1M');
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
    expect(find.text('4K'), findsOneWidget);
    expect(find.text('Max memory token limit'), findsOneWidget);
    expect(find.text('Max memory limit'), findsNothing);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('Apply to all Worldos'), findsNothing);
    expect(find.byKey(const ValueKey('gem-model-save')), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Recommended'), findsNothing);
    expect(find.text('More'), findsNothing);
    expect(find.text('Top Pick V3'), findsOneWidget);
    expect(find.text('Sake Pro'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('4.0–320.0 gems (memory 11K → 48K)'), findsOneWidget);
    expect(find.textContaining('(memory 11K → 48K)'), findsNWidgets(3));
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
    const trackInset = 24.0;
    expect(sliderRect.left + trackInset - cardRect.left, moreOrLessEquals(19));
    expect(
      cardRect.right - (sliderRect.right - trackInset),
      moreOrLessEquals(19),
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
      minMemoryTokens: 4000,
      maxMemoryTokens: 1000000,
    );
    final thumbCenterX =
        sliderRect.left +
        trackInset +
        sliderValue * (sliderRect.width - trackInset * 2);
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
    expect(calls, [1000000, 4000]);
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
            return _catalog(memoryTokens: memoryApi.globalValue);
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
      expect(_sliderTokens(tester), 48000);
      expect(memoryApi.loads, ['W_UNCERTAIN', null]);
      expect(find.text('Save result not confirmed'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.text('Open'), findsOneWidget);
      expect(attempts, [1000000]);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('definite memory failure rolls back and is not retried on exit', (
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
    expect(_sliderTokens(tester), 48000);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Open'), findsOneWidget);
    expect(attempts, 1);
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

GemModelCatalog _catalog({int memoryTokens = 48000}) => GemModelCatalog(
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
          minGemsCent: 400,
          maxGemsCent: 32000,
          minMemoryTokens: memoryTokens,
          maxMemoryTokens: 1000000,
        ),
        GemModel(
          modelCode: 'sake_pro',
          title: 'Sake Pro',
          tags: ['new'],
          estimatedNextMessageGemsCent: 300,
          estimatedNextTickGemsCent: 300,
          description: 'Flexible storytelling.',
          minGemsCent: 300,
          maxGemsCent: 16000,
          minMemoryTokens: memoryTokens,
          maxMemoryTokens: 1000000,
        ),
      ],
    ),
  ],
);

GemModelCatalog _catalogWithTwoGroups({int memoryTokens = 48000}) =>
    GemModelCatalog(
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
              minGemsCent: 400,
              maxGemsCent: 32000,
              minMemoryTokens: memoryTokens,
              maxMemoryTokens: 1000000,
            ),
            GemModel(
              modelCode: 'sake_pro',
              title: 'Sake Pro',
              tags: ['new'],
              estimatedNextMessageGemsCent: 300,
              estimatedNextTickGemsCent: 300,
              description: 'Flexible storytelling.',
              minGemsCent: 300,
              maxGemsCent: 16000,
              minMemoryTokens: memoryTokens,
              maxMemoryTokens: 1000000,
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
              minGemsCent: 200,
              maxGemsCent: 8000,
              minMemoryTokens: memoryTokens,
              maxMemoryTokens: 1000000,
            ),
          ],
        ),
      ],
    );

GemModelCatalog _quotationCatalog({
  int memoryTokens = 48000,
  int minCent = 216,
  int maxCent = 483,
}) => GemModelCatalog(
  selectedModelCode: 'miranda',
  groups: [
    GemModelGroup(
      groupCode: 'recommended',
      groupTitle: 'Recommended',
      models: [
        GemModel(
          modelCode: 'miranda',
          title: 'Miranda',
          tags: const [],
          description: 'Model description.',
          estimatedNextMessageGemsCent: minCent,
          estimatedNextTickGemsCent: 300,
          minGemsCent: minCent,
          maxGemsCent: maxCent,
          minMemoryTokens: memoryTokens,
          maxMemoryTokens: 1000000,
        ),
      ],
    ),
  ],
);

int _sliderTokens(WidgetTester tester) {
  final slider = tester.widget<Slider>(
    find.byKey(const ValueKey('memory-model-max-memory-slider')),
  );
  return memoryTokensForSliderValue(
    slider.value,
    minMemoryTokens: 4000,
    maxMemoryTokens: 1000000,
  );
}
