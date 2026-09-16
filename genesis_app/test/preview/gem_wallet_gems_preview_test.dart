import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/pages/gems/gem_wallet_page.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

/// Renders the Buy Gems tab so the balance header can be eyeballed.
void main() {
  testWidgets('render buy gems tab', (tester) async {
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

    final wallet = GemWalletStore(
      loadWallet: () async => const GemWallet(balanceCent: 128400),
      readUid: () async => 'preview',
    );
    addTearDown(wallet.dispose);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: GenesisTheme.light(),
          home: GemWalletPage(
            walletStore: wallet,
            productsLoader: (_) async => [],
            tasksLoader: (_) async => [],
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
        'test/preview/buy_gems_tab.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  });
}
