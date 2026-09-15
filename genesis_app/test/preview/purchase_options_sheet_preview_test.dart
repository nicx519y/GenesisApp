import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/components/gems/gem_purchase_catalog.dart';
import 'package:genesis_flutter_android/components/gems/purchase_options_sheet.dart';
import 'package:genesis_flutter_android/pages/me/developer_personalization_preview.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

/// Renders the gem purchase sheet — the surface whose body carries the
/// wordmark — so its title column can be checked against the benefit rows.
void main() {
  testWidgets('render gem purchase sheet', (tester) async {
    tester.view.physicalSize = const Size(780, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.runAsync(() async {
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            'C:/dev/flutter/bin/cache/artifacts/material_fonts/'
            'materialicons-regular.otf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await icons.load();
    });

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: GenesisTheme.light(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Row(
              children: [
                for (final tab in PurchaseSheetTab.values)
                  Expanded(
                    child: PurchaseOptionsSheet(
                      initialTab: tab,
                      // As the real sheet builds it: the panel heads a column,
                      // it does not fill the page.
                      gemsBuilder: (_) => const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GemBalancePanel(balanceCent: 128400, compact: true),
                        ],
                      ),
                      subscriptionBuilder: (context) => ProSubscriptionContent(
                        topSpacing: 0,
                        horizontalInset: 0,
                        headingTopSpacing: 0,
                        productsLoader: loadPersonalizationPreviewCatalog,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        'test/preview/gem_purchase_sheet.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  });
}
