import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_sheet.dart';
import 'package:genesis_flutter_android/pages/me/developer_personalization_preview.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

/// Renders the sheet the login flow raises, so its header and the benefit
/// emphasis can be eyeballed without reaching the gate's one-shot trigger.
void main() {
  testWidgets('render onboarding subscription sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
            body: PersonalizationSheet(
              form: personalizationPreviewForm,
              initialStep: PersonalizationStep.subscription,
              onSubmit: (_) async => PersonalizationNextStep.subscription,
              onSignIn: (_) async => const PersonalizationProfile(),
              subscriptionBuilder: (context) => ProSubscriptionContent(
                topSpacing: 0,
                horizontalInset: 0,
                showHeading: false,
                productsLoader: loadPersonalizationPreviewCatalog,
              ),
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
        'test/preview/onboarding_subscription.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  });
}
