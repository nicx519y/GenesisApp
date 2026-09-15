import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/components/gems/daily_check_in_dialog.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter');
    font.addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await font.load();
  });
  for (final member in [false, true]) {
    testWidgets('render ${member ? 'member' : 'non-member'} check-in', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 900);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final wallet = GemWalletStore(
        readUid: () async => 'preview-user',
        loadWallet: () async => GemWallet(
          balanceCent: 5000,
          membership: GemWalletMembership(
            status: member ? 1 : 0,
            planCode: member ? 'pro_monthly' : '',
            expiresAt: member ? DateTime.utc(2041) : null,
            autoRenew: member,
            blueGemsCent: member ? 30000 : 0,
            hasOverlap: false,
          ),
        ),
      );
      final membership = MembershipAccessStore(
        wallet: wallet,
        readLoginUid: () async => 'preview-user',
        serverNow: () => DateTime.utc(2040),
      );
      final boundaryKey = GlobalKey();
      late BuildContext pageContext;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: GenesisTheme.dark(),
            home: Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold(
                  backgroundColor: GenesisColors.darkBackground,
                );
              },
            ),
          ),
        ),
      );
      final dialog = showDailyCheckInDialog(
        pageContext,
        status: DailyCheckInDialogStatus.checkIn,
        membershipAccess: membership,
      );
      await tester.pumpAndSettle();
      expect(find.text('Daily Check-in'), findsOneWidget);
      expect(find.text('Check in'), findsOneWidget);
      expect(find.text('Get 100'), member ? findsNothing : findsOneWidget);
      expect(find.text('Cancel'), member ? findsOneWidget : findsNothing);
      expect(
        tester.widget<Text>(find.text('Check in')).style!.color,
        member ? GenesisColors.redSecondary : GenesisColors.darkTextPrimary,
      );
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 3);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/Users/long/Project/GenesisApp_1/outputs/check-in-vip-colors/${member ? 'member' : 'non-member'}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.tap(find.text(member ? 'Cancel' : 'Check in'));
      await tester.pumpAndSettle();
      await dialog;
      await tester.pumpWidget(const SizedBox.shrink());
      membership.dispose();
      wallet.dispose();
    });
  }
}
