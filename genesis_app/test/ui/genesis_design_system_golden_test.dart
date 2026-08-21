import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_action_box.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    final icons = FontLoader('MyFlutterApp')
      ..addFont(rootBundle.load('assets/custom-icons/fonts/MyFlutterApp.ttf'));
    await Future.wait([inter.load(), icons.load()]);
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    final platformName = platform == TargetPlatform.android ? 'android' : 'ios';

    group('$platformName design-system goldens', () {
      testWidgets('root page', (tester) async {
        await _pumpPage(
          tester,
          platform,
          GenesisPageScaffold.root(
            title: 'Messages',
            body: ListView(
              children: [
                GenesisNavigationRow(label: 'World updates', onTap: () {}),
                GenesisNavigationRow(label: 'Mentions', onTap: () {}),
              ],
            ),
          ),
        );
        await _expectGolden(tester, platformName, 'root');
      });

      testWidgets('secondary page', (tester) async {
        await _pumpPage(
          tester,
          platform,
          const GenesisPageScaffold.secondary(
            title: 'About',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Worldo', style: GenesisTypography.sectionTitle),
                SizedBox(height: 12),
                Text(
                  'Create, discover, and enter AI-powered worlds.',
                  style: GenesisTypography.body,
                ),
              ],
            ),
          ),
        );
        await _expectGolden(tester, platformName, 'secondary');
      });

      testWidgets('editor page', (tester) async {
        final nameController = TextEditingController(text: 'Sky Realm');
        final descriptionController = TextEditingController(
          text: 'A floating world above the clouds.',
        );
        addTearDown(nameController.dispose);
        addTearDown(descriptionController.dispose);
        await _pumpPage(
          tester,
          platform,
          GenesisPageScaffold.editor(
            title: 'Basics',
            actions: [TextButton(onPressed: () {}, child: const Text('Save'))],
            body: Column(
              children: [
                GenesisTextField(
                  controller: nameController,
                  label: 'Name',
                  requiredIndicator: true,
                  maxLength: 30,
                ),
                const SizedBox(height: 20),
                GenesisTextArea(
                  controller: descriptionController,
                  label: 'Description',
                  maxLength: 300,
                ),
              ],
            ),
          ),
        );
        await _expectGolden(tester, platformName, 'editor');
      });

      testWidgets('confirmation dialog', (tester) async {
        late BuildContext routeContext;
        await _pumpPage(
          tester,
          platform,
          Builder(
            builder: (context) {
              routeContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        );
        showGenesisActionBox<bool>(
          context: routeContext,
          title: 'Discard changes?',
          actions: const [
            GenesisActionBoxAction<bool>(label: 'Discard', value: true),
          ],
        );
        await tester.pumpAndSettle();
        await _expectGolden(tester, platformName, 'confirmation');
      });

      testWidgets('content dialog', (tester) async {
        late BuildContext routeContext;
        await _pumpPage(
          tester,
          platform,
          Builder(
            builder: (context) {
              routeContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        );
        showGenesisContentDialog<void>(
          context: routeContext,
          title: 'Content dialog',
          content: const Text(
            'Structured content uses the shared title, spacing, and actions.',
          ),
          showCloseButton: true,
          actions: const [GenesisDialogAction(label: 'Done', onPressed: null)],
        );
        await tester.pumpAndSettle();
        await _expectGolden(tester, platformName, 'content_dialog');
      });

      testWidgets('bottom sheet', (tester) async {
        late BuildContext routeContext;
        await _pumpPage(
          tester,
          platform,
          Builder(
            builder: (context) {
              routeContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        );
        showGenesisModalBottomSheet<void>(
          context: routeContext,
          backgroundColor: Colors.transparent,
          builder: (context) => GenesisBottomSheetPanel.content(
            title: 'Choose an option',
            trailing: GenesisBottomSheetCloseButton(onPressed: () {}),
            child: Column(
              children: [
                GenesisNavigationRow(label: 'Option one', onTap: () {}),
                GenesisNavigationRow(label: 'Option two', onTap: () {}),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _expectGolden(tester, platformName, 'bottom_sheet');
      });

      testWidgets('page states', (tester) async {
        await _pumpPage(
          tester,
          platform,
          Scaffold(
            body: SafeArea(
              child: ListView(
                padding: GenesisSpacing.pagePadding,
                children: [
                  const GenesisStateView.loading(height: 120),
                  const GenesisStateView.empty(
                    message: 'Nothing here yet.',
                    height: 120,
                    compact: true,
                  ),
                  GenesisStateView.error(
                    message: 'Unable to load.',
                    onAction: () {},
                    height: 140,
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
        );
        await _expectGolden(tester, platformName, 'states');
      });
    });
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  TargetPlatform platform,
  Widget home,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: GenesisTheme.worldoRedesign().copyWith(platform: platform),
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _expectGolden(WidgetTester tester, String platform, String name) {
  return expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/design_system/$platform/$name.png'),
  );
}
