import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/me/developer_global_memory_preview.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_preview_page.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  test('memory capsules remain gated before joining the World', () {
    for (final kind in [
      WorldBottomSheetKind.recap,
      WorldBottomSheetKind.cast,
      WorldBottomSheetKind.bonds,
    ]) {
      expect(canAccessWorldSection(kind, 'approved'), isFalse);
      expect(canAccessWorldSection(kind, 'owner'), isTrue);
      expect(canAccessWorldSection(kind, 'joined'), isTrue);
    }
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const RepaintBoundary(
          key: ValueKey('memory-preview-render'),
          child: DeveloperGlobalMemoryPreview(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'isolated preview can navigate memory sections without services',
    (tester) async {
      await mount(tester);
      expect(find.text('Sample story · preview only'), findsOneWidget);
      await tester.tap(find.text('Cast').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Bonds').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Recap').last);
      await tester.pumpAndSettle();
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
    },
  );

  testWidgets('preview controls and memory body fit narrow large-text screen', (
    tester,
  ) async {
    await mount(tester, width: 350, scale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cast').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('render memory review screens', (tester) async {
    await tester.runAsync(() async {
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
      await (FontLoader('MaterialIcons')..addFont(
            File(
              'C:/dev/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    });
    await mount(tester);
    final directory = Directory('build/global-memory-review')
      ..createSync(recursive: true);
    for (final section in ['Recap', 'Cast', 'Bonds']) {
      await tester.tap(find.text(section).last);
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('memory-preview-render')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/${section.toLowerCase()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const RepaintBoundary(
          key: ValueKey('membership-review-render'),
          child: MemoryMembershipPreviewPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final surface in ['premium', 'deluxe', 'me-membership']) {
      if (surface == 'deluxe') {
        await tester.drag(
          find.byKey(const ValueKey('membership-subscription-pages')),
          const Offset(-300, 0),
        );
      } else if (surface == 'me-membership') {
        await tester.tap(find.byTooltip('Me'));
      }
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('membership-review-render')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/$surface.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  }, skip: !Platform.environment.containsKey('MEMORY_SCREENSHOTS'));
}
