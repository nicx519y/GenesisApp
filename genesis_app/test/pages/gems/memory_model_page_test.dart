import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/gem_model.dart';
import 'package:genesis_flutter_android/pages/gems/memory_model_page.dart';

void main() {
  testWidgets('initial loading indicator uses the Gem red color', (
    tester,
  ) async {
    final catalogCompleter = Completer<GemModelCatalog>();

    await tester.pumpWidget(
      MaterialApp(
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
    expect(indicator.color, const Color(0xFFF42C47));

    catalogCompleter.complete(_catalog());
    await tester.pumpAndSettle();
  });

  testWidgets('renders backend model catalog and selected state', (
    tester,
  ) async {
    final requestedWorldIds = <String>[];

    await tester.pumpWidget(
      MaterialApp(
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
    expect(_tileBorder(tester, 'top_pick_v3').color, const Color(0xFFF42C47));
    expect(_tileBorder(tester, 'sake_pro').color, const Color(0xFFE1E1E1));
    expect(_tagContainer(tester, 'hot').color, const Color(0xFFFF7A1A));
    expect(_tagContainer(tester, 'hot').height, 20);
    expect(_tagContainer(tester, 'new').color, const Color(0xFFF42C47));
    expect(_tagContainer(tester, 'new').height, 20);
    expect(
      tester.getCenter(find.text('Top Pick V3')).dy,
      closeTo(tester.getCenter(find.text('Hot')).dy, 0.5),
    );
    final estimate = _estimateContainer(tester, 'top_pick_v3');
    expect(estimate.color, const Color(0xFF444444).withValues(alpha: 0.14));
    final estimateSize = tester.getSize(
      find.byKey(const ValueKey<String>('gem-model-estimate-top_pick_v3')),
    );
    final tileSize = tester.getSize(
      find.byKey(const ValueKey<String>('gem-model-top_pick_v3')),
    );
    expect(estimateSize.width, lessThan(tileSize.width));
    expect(estimateSize.height, 18);
    expect(_tagContainer(tester, 'hot').radius, 8);
    expect(_tagContainer(tester, 'new').radius, 8);
  });

  testWidgets('save submits the pending model for the current world', (
    tester,
  ) async {
    final selections = <(String, String)>[];
    final cachedModelCodes = <String>[];
    final selectionCompleter = Completer<GemModelSelection>();

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryModelPage(
          worldId: 'W_000002',
          catalogLoader: (_) async => _catalog(),
          selectionHandler: (worldId, modelCode) async {
            selections.add((worldId, modelCode));
            return selectionCompleter.future;
          },
          selectedModelCodeCacheWriter: (modelCode) async {
            cachedModelCodes.add(modelCode);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('gem-model-sake_pro')));
    await tester.pump();

    expect(selections, isEmpty);
    expect(cachedModelCodes, isEmpty);
    expect(_tileBorder(tester, 'top_pick_v3').color, const Color(0xFFE1E1E1));
    expect(_tileBorder(tester, 'sake_pro').color, const Color(0xFFF42C47));

    await tester.tap(find.byKey(const ValueKey('gem-model-save')));
    await tester.pump();

    expect(selections, [('W_000002', 'sake_pro')]);
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
    expect(_tileBorder(tester, 'top_pick_v3').color, const Color(0xFFE1E1E1));
    expect(_tileBorder(tester, 'sake_pro').color, const Color(0xFFF42C47));
    expect(find.text('Switched successfully'), findsOneWidget);
    expect(find.byKey(const ValueKey('gem-model-save-loading')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('failed save restores the server-selected model', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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

    expect(_tileBorder(tester, 'top_pick_v3').color, const Color(0xFFF42C47));
    expect(_tileBorder(tester, 'sake_pro').color, const Color(0xFFE1E1E1));
    expect(find.text('Switched failed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}

BorderSide _tileBorder(WidgetTester tester, String modelCode) {
  final material = tester.widget<Material>(
    find.byKey(ValueKey<String>('gem-model-$modelCode')),
  );
  return (material.shape! as RoundedRectangleBorder).side;
}

({Color? color, double? height, double? radius}) _tagContainer(
  WidgetTester tester,
  String tag,
) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey<String>('gem-model-tag-$tag')),
  );
  final decoration = container.decoration! as BoxDecoration;
  return (
    color: decoration.color,
    height: container.constraints?.maxHeight,
    radius: decoration.borderRadius?.resolve(TextDirection.ltr).topLeft.x,
  );
}

({Color? color}) _estimateContainer(WidgetTester tester, String modelCode) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey<String>('gem-model-estimate-$modelCode')),
  );
  final decoration = container.decoration! as BoxDecoration;
  return (color: decoration.color);
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
