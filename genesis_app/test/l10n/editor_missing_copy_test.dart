import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/l10n/genesis_l10n.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_editor_pages.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_draft_repository.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';

void main() {
  tearDown(() => GenesisL10n.bind(lookupAppLocalizations(const Locale('en'))));
  testWidgets(
    'Taiwan duration options use localized labels with stable values',
    (tester) async {
      GenesisL10n.bind(lookupAppLocalizations(const Locale('zh', 'TW')));
      await tester.pumpWidget(
        MaterialApp(
          home: OriginBasicsEditorPage(
            repository: MemoryOriginDraftRepository(
              initialDraft: CreateOriginDraft.empty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['6 小時', '12 小時', '1 天', '1 週']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('time-progress-option-6 hours')),
        findsOneWidget,
      );
      expect(find.text('6 hours'), findsNothing);
    },
  );
  testWidgets('Taiwan event counter is localized', (tester) async {
    GenesisL10n.bind(lookupAppLocalizations(const Locale('zh', 'TW')));
    await tester.pumpWidget(
      MaterialApp(
        home: OriginStoryEventsEditorPage(
          repository: MemoryOriginDraftRepository(
            initialDraft: CreateOriginDraft.empty(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('已新增／上限'), findsOneWidget);
    expect(find.textContaining('Added / Max'), findsNothing);
  });
}
