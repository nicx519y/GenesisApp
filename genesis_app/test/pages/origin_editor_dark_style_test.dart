import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_form_widgets.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_draft_repository.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_editor_pages.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  setUp(() {
    GenesisColorRuntime.activate(GenesisColorDefaults.dark, 1);
  });

  tearDown(() {
    GenesisColorRuntime.activate(GenesisColorDefaults.light, 0);
  });

  testWidgets('OriginDraftFlowPage uses layered Dark summary colors', (
    tester,
  ) async {
    final repository = MemoryOriginDraftRepository(
      initialDraft: CreateOriginDraft.empty(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: OriginDraftFlowPage(
          title: 'Edit Worldo',
          repository: repository,
          basicsPageBuilder: (_) => const SizedBox.shrink(),
          charactersPageBuilder: (_) => const SizedBox.shrink(),
          locationsPageBuilder: (_) => const SizedBox.shrink(),
          storyEventsPageBuilder: (_) => const SizedBox.shrink(),
          onSubmit: (_, _, _) async =>
              const OriginSubmitResult(message: '', showMessage: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dark = GenesisColorDefaults.dark;
    final title = tester.widget<Text>(find.text('Basics'));
    final summary = tester.widget<Text>(find.text('Not started yet').first);
    final divider = tester.widget<Divider>(find.byType(Divider).first);

    expect(title.style?.color, dark.color(GenesisColorToken.textPrimary));
    expect(summary.style?.color, dark.color(GenesisColorToken.textSecondary));
    expect(divider.color, dark.color(GenesisColorToken.divider));
  });

  testWidgets('CreateFormCard uses the Dark elevated surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: Scaffold(
          body: CreateFormCard(
            title: 'Character 1',
            onDelete: () {},
            child: const Text('Form content'),
          ),
        ),
      ),
    );

    final decorated = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) => container.decoration is BoxDecoration)
        .map((container) => container.decoration! as BoxDecoration)
        .firstWhere((decoration) => decoration.border != null);
    expect(
      decorated.color,
      GenesisColorDefaults.dark.color(GenesisColorToken.surfaceElevated),
    );
  });
}
