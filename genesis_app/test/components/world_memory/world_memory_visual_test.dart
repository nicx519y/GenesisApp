import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_memory/world_memory.dart';
import 'package:genesis_flutter_android/components/world_memory/world_memory_preview_data.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

// Optional visual review of the actual shared content at the source artboard's
// dimensions, without the Developer gallery controls changing its viewport.
void main() {
  testWidgets('render source-sized memory surfaces', (tester) async {
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('build/global-memory-review/content')
      ..createSync(recursive: true);
    for (final phone in [false, true]) {
      for (final section in WorldMemorySection.values) {
        for (final locked in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: GenesisTheme.dark(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(
                body: Column(
                  children: [
                    SizedBox(height: phone ? 96 : 178),
                    SizedBox(
                      height: phone ? 748 : 617,
                      child: RepaintBoundary(
                        key: ValueKey((phone, section, locked)),
                        child: WorldMemoryView(
                          key: ValueKey((phone, section, locked, 'view')),
                          section: section,
                          snapshot: WorldMemoryPreviewData.live(),
                          premiumActive: !locked,
                          deluxeActive: !locked,
                          phone: phone,
                          phoneHeaderBuilder: phone
                              ? (context, back) => const SizedBox.shrink()
                              : null,
                          onSubscribe: (_) {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            // Decode assets before taking the first screenshot in a new size.
            final context = tester.element(find.byType(WorldMemoryView));
            for (final i in [1, 2, 3, 4, 5]) {
              await precacheImage(
                AssetImage('assets/world_memory_preview/sq_char_$i.jpg'),
                context,
              );
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(ValueKey((phone, section, locked))),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${output.path}/${phone ? 'phone' : 'world'}-${section.name}${locked ? '-locked' : ''}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          if (!locked && section == WorldMemorySection.cast) {
            await tester.tap(
              find.byKey(
                ValueKey('memory-character-${phone ? 'vivienne' : 'you'}'),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '${output.path}/${phone ? 'phone' : 'world'}-cast-open.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    }
  }, skip: !Platform.environment.containsKey('MEMORY_SCREENSHOTS'));
}
