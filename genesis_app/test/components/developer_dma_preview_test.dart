import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/privacy/privacy_choices_store.dart';
import 'package:genesis_flutter_android/components/common/genesis_action_box.dart';
import 'package:genesis_flutter_android/pages/me/developer_dma_preview.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saved choices are restored and closing discards edits', (
    tester,
  ) async {
    await PrivacyChoicesStore.save(
      const PrivacyChoices(
        adStorage: true,
        adUserData: false,
        adPersonalization: false,
        analyticsStorage: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showDeveloperDmaPreview(context, openChoicesDirectly: true),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value), [
      true,
      false,
      false,
      true,
    ]);
    await tester.tap(find.text('Advertising storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dma-preview-close')));
    await tester.pumpAndSettle();
    expect((await PrivacyChoicesStore.read())!.adStorage, isTrue);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept all'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final saved = (await PrivacyChoicesStore.read())!;
    expect([
      saved.adStorage,
      saved.adUserData,
      saved.adPersonalization,
      saved.analyticsStorage,
    ], everyElement(isTrue));
  });

  test(
    'all denied is a valid record; missing and malformed records are not',
    () async {
      expect(await PrivacyChoicesStore.read(), isNull);
      await PrivacyChoicesStore.save(
        const PrivacyChoices(
          adStorage: false,
          adUserData: false,
          adPersonalization: false,
          analyticsStorage: false,
        ),
      );
      expect(await PrivacyChoicesStore.read(), isNotNull);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrivacyChoicesStore.storageKey, '{invalid');
      expect(await PrivacyChoicesStore.read(), isNull);
    },
  );
  testWidgets('settings entry opens choices directly and X closes the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showDeveloperDmaPreview(context, openChoicesDirectly: true),
              child: const Text('Privacy choices'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Privacy choices'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNWidgets(4));
    expect(find.text('Manage options'), findsNothing);
    expect(find.text('Confirm choices'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dma-preview-close')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Privacy choices'), findsOneWidget);
  });

  for (final sheet in [true, false]) {
    testWidgets('DMA dismisses debug ${sheet ? 'sheet' : 'page'} first', (
      tester,
    ) async {
      var transitionCompleted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Widget debugPage(BuildContext context) {
                    ModalRoute.of(context)!.completed.then((_) {
                      transitionCompleted = true;
                    });
                    return Scaffold(
                      key: const ValueKey('debug-preview-surface'),
                      body: TextButton(
                        onPressed: () => showDeveloperDmaPreview(
                          context,
                          dismissCurrentRoute: true,
                        ),
                        child: const Text('DMA'),
                      ),
                    );
                  }

                  if (sheet) {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: debugPage,
                    );
                  } else {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: debugPage));
                  }
                },
                child: const Text('Open debug'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open debug'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DMA'));
      await tester.pump();
      expect(find.byType(Dialog), findsNothing);
      await tester.pumpAndSettle();
      expect(transitionCompleted, isTrue);
      expect(find.byKey(const ValueKey('debug-preview-surface')), findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('Do not consent'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Open debug'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('small screen and large text remain scrollable; reject closes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDeveloperDmaPreview(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byKey(const ValueKey('dma-preview-close')), findsNothing);
    await tester.ensureVisible(find.text('Manage options'));
    await tester.tap(find.text('Manage options'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(GenesisActionBoxSurface));
    final close = tester.getRect(
      find.byKey(const ValueKey('dma-preview-close')),
    );
    expect(close.top - panel.top, 12);
    expect(panel.right - close.right, 12);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('dma-preview-close')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const ValueKey('dma-preview-close')), findsNothing);
    await tester.ensureVisible(find.text('Do not consent'));
    await tester.tap(find.text('Do not consent'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview choices stay local and reset when reopened', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDeveloperDmaPreview(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage options'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNWidgets(4));
    expect(
      tester
          .widgetList<Switch>(find.byType(Switch))
          .every((tile) => !tile.value),
      isTrue,
    );
    await tester.tap(find.text('Advertising data sharing'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Switch>(find.byType(Switch)).map((tile) => tile.value),
      [false, true, false, false],
    );
    await tester.ensureVisible(find.text('Usage analytics'));
    await tester.tap(find.text('Usage analytics'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Switch>(find.byType(Switch)).map((tile) => tile.value),
      [false, true, false, true],
    );
    await tester.ensureVisible(find.text('Personalized ads'));
    await tester.tap(find.text('Personalized ads'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dma-preview-close')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Manage options'), findsOneWidget);
    expect(find.text('Consent'), findsOneWidget);
    expect(find.text('Do not consent'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.text('Manage options'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Switch>(find.byType(Switch))
          .every((tile) => !tile.value),
      isTrue,
    );
    await tester.tap(find.text('Confirm choices'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage options'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Switch>(find.byType(Switch))
          .every((tile) => !tile.value),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
