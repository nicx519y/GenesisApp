import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/network/models/gem_home.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/pages/gems/gem_wallet_page.dart';

void main() {
  testWidgets('GemWalletPage renders home data and refreshes on resume', (
    tester,
  ) async {
    var homeLoadCount = 0;
    var walletLoadCount = 0;
    final walletStore = GemWalletStore(
      loadWallet: () async {
        walletLoadCount += 1;
        return GemWallet(balance: walletLoadCount == 1 ? 430 : 520);
      },
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          homeLoader: (_) async {
            homeLoadCount += 1;
            return _home(balance: homeLoadCount == 1 ? 900 : 610);
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Buy Gems'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('430'), findsOneWidget);
    expect(find.text('900'), findsNothing);
    expect(find.text('+500'), findsOneWidget);
    expect(find.text('+50 Bonus'), findsOneWidget);
    expect(find.text(r'$1.49'), findsOneWidget);
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Create your first worldo'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(homeLoadCount, 2);
    expect(walletLoadCount, 2);
    expect(find.text('520'), findsOneWidget);
    expect(find.text('610'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(find.text('Join us'), findsOneWidget);
    expect(find.text('Discord'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('wallet endpoint balance overrides later home balances', (
    tester,
  ) async {
    var homeBalance = 430;
    var walletBalance = 430;
    final walletStore = GemWalletStore(
      loadWallet: () async => GemWallet(balance: walletBalance),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          homeLoader: (_) async => _home(balance: homeBalance),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('430'), findsOneWidget);

    walletBalance = 520;
    await walletStore.refreshAfterEntitlementGranted();
    await tester.pump();

    expect(find.text('520'), findsOneWidget);

    homeBalance = 610;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('520'), findsOneWidget);
    expect(find.text('610'), findsNothing);
  });

  testWidgets('GemWalletPage shows zero until wallet balance arrives', (
    tester,
  ) async {
    final result = Completer<GemWallet>();
    final walletStore = GemWalletStore(
      loadWallet: () => result.future,
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          homeLoader: (_) async => _home(balance: 900),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('gem-wallet-balance')))
          .data,
      '0',
    );

    result.complete(const GemWallet(balance: 430));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('gem-wallet-balance')))
          .data,
      '430',
    );
  });

  testWidgets('GemWalletPage hides zero bonus gems', (tester) async {
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          homeLoader: (_) async => _home(balance: 900, bonusGems: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+0 Bonus'), findsNothing);
    expect(find.text('+500'), findsOneWidget);
  });
}

GemHome _home({required int balance, int bonusGems = 50}) {
  return GemHome(
    balance: balance,
    products: [
      GemProduct(
        productId: 'gem_pack_500',
        appleProductId: 'com.worldo.gems.500',
        googleProductId: 'worldo_gems_500',
        baseGems: 500,
        bonusGems: bonusGems,
        priceCurrencyCode: 'USD',
        priceAmount: 149,
        canPurchase: true,
        activityType: 'none',
      ),
    ],
    taskGroups: const [
      GemTaskGroup(
        groupCode: 'starter',
        groupTitle: 'Starter',
        displayOrder: 10,
        tasks: [
          GemTask(
            taskCode: 'create_first_worldo',
            title: 'Create your first worldo',
            description: 'Create an Origin and launch a world.',
            rewardGems: 50,
            rewardValidDays: 30,
            cycleType: 'once',
            progress: 0,
            targetCount: 1,
            progressText: '0/1',
            status: 'in_progress',
            actionType: 'navigate',
            actionText: 'Go',
            actionTarget: 'create_origin',
            displayOrder: 10,
          ),
        ],
      ),
      GemTaskGroup(
        groupCode: 'join_us',
        groupTitle: 'Join us',
        displayOrder: 20,
        tasks: [
          GemTask(
            taskCode: 'join_discord',
            title: 'Discord',
            description: 'Join our Discord community.',
            rewardGems: 20,
            rewardValidDays: 30,
            cycleType: 'once',
            progress: 0,
            targetCount: 1,
            progressText: '0/1',
            status: 'in_progress',
            actionType: 'navigate',
            actionText: 'Follow',
            actionTarget: 'discord',
            displayOrder: 10,
          ),
        ],
      ),
    ],
  );
}
