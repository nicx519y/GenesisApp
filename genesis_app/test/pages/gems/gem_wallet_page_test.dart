import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug_page_tracker.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/network/models/gem_records.dart';
import 'package:genesis_flutter_android/network/models/gem_task.dart';
import 'package:genesis_flutter_android/network/models/gem_task_action.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/pages/gems/gem_records_page.dart';
import 'package:genesis_flutter_android/pages/gems/gem_wallet_page.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/billing_service.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
  testWidgets('GemWalletPage renders split data and refreshes on resume', (
    tester,
  ) async {
    var productsLoadCount = 0;
    var tasksLoadCount = 0;
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
          productsLoader: (_) async {
            productsLoadCount += 1;
            return _products();
          },
          tasksLoader: (_) async {
            tasksLoadCount += 1;
            return _taskGroups();
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Buy Gems'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('430'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);
    expect(find.text('+50 Bonus'), findsOneWidget);
    expect(find.text(r'$1.49'), findsOneWidget);
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Create your first worldo'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(productsLoadCount, 2);
    expect(tasksLoadCount, 2);
    expect(walletLoadCount, 2);
    expect(find.text('520'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(find.text('Join us'), findsOneWidget);
    expect(find.text('Discord'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('Records opens Gem Records and supports swipe tab switching', (
    tester,
  ) async {
    var productsLoadCount = 0;
    var tasksLoadCount = 0;
    final walletStore = GemWalletStore(
      loadWallet: () async => GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);
    final requestedScenes = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [genesisPageRouteObserver],
        routes: {
          RouteNames.gemRecords: (_) => GemRecordsPage(
            recordsLoader: ({required scene, required pn, required rn}) async {
              requestedScenes.add(scene);
              return GemRecordList(
                items: [
                  GemRecordItem(
                    ledgerId: 'gl_$scene',
                    amount: 50,
                    scene: 'task',
                    reasonCode: 'daily_checkin',
                    title: scene == 'earned'
                        ? 'Earned reward'
                        : 'Daily check-in',
                    subtitle: 'Starter reward',
                    createdAt: 1783586400,
                    expiresAt: 0,
                  ),
                ],
                total: 1,
                page: 1,
                pageSize: 20,
              );
            },
          ),
        },
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async {
            productsLoadCount += 1;
            return _products();
          },
          tasksLoader: (_) async {
            tasksLoadCount += 1;
            return _taskGroups();
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Records'), findsNothing);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();

    expect(find.text('Gem Records'), findsOneWidget);
    expect(find.text('Daily check-in'), findsOneWidget);
    expect(requestedScenes, contains('all'));

    await tester.drag(find.byType(TabBarView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(requestedScenes, contains('earned'));
    expect(find.text('Earned reward'), findsOneWidget);

    Navigator.of(tester.element(find.text('Gem Records'))).pop();
    await tester.pumpAndSettle();

    expect(productsLoadCount, 2);
    expect(tasksLoadCount, 2);
  });

  testWidgets('task section remains available when products fail', (
    tester,
  ) async {
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async => throw Exception('products failed'),
          tasksLoader: (_) async => _taskGroups(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load gem packs.'), findsOneWidget);
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Create your first worldo'), findsOneWidget);
  });

  testWidgets('wallet endpoint balance stays independent from catalog data', (
    tester,
  ) async {
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
          productsLoader: (_) async => _products(),
          tasksLoader: (_) async => _taskGroups(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('430'), findsOneWidget);

    walletBalance = 520;
    await walletStore.refreshAfterEntitlementGranted();
    await tester.pump();

    expect(find.text('520'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('520'), findsOneWidget);
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
          productsLoader: (_) async => _products(),
          tasksLoader: (_) async => _taskGroups(),
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
          productsLoader: (_) async => _products(bonusGems: 0),
          tasksLoader: (_) async => _taskGroups(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+0 Bonus'), findsNothing);
    expect(find.text('+500'), findsOneWidget);
  });

  testWidgets('tapping a product starts its billing purchase', (tester) async {
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    final billing = _FakeBillingService();
    addTearDown(walletStore.dispose);
    addTearDown(billing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          billingService: billing,
          productsLoader: (_) async => _products(),
          tasksLoader: (_) async => _taskGroups(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-product-gem_pack_500')),
    );
    await tester.pump();

    expect(billing.purchasedProducts, hasLength(1));
    expect(billing.purchasedProducts.single.productId, 'gem_pack_500');
  });

  testWidgets('other gem products ignore taps during a purchase', (
    tester,
  ) async {
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    final billing = _FakeBillingService();
    addTearDown(walletStore.dispose);
    addTearDown(billing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          billingService: billing,
          productsLoader: (_) async => [
            _product('gem_pack_500'),
            _product('gem_pack_1100'),
          ],
          tasksLoader: (_) async => _taskGroups(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-product-gem_pack_500')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('gem-product-gem_pack_1100')),
    );
    await tester.pump();

    expect(billing.purchasedProducts, hasLength(1));
    expect(billing.purchasedProducts.single.productId, 'gem_pack_500');
  });

  testWidgets('billing success refreshes products tasks and wallet', (
    tester,
  ) async {
    var productsLoadCount = 0;
    var tasksLoadCount = 0;
    var walletLoadCount = 0;
    final walletStore = GemWalletStore(
      loadWallet: () async {
        walletLoadCount += 1;
        return const GemWallet(balance: 430);
      },
      readUid: () async => 'u_user',
    );
    final billing = _FakeBillingService();
    addTearDown(walletStore.dispose);
    addTearDown(billing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          billingService: billing,
          productsLoader: (_) async {
            productsLoadCount += 1;
            return _products();
          },
          tasksLoader: (_) async {
            tasksLoadCount += 1;
            return _taskGroups();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    billing.emitSuccess();
    await tester.pumpAndSettle();

    expect(productsLoadCount, 2);
    expect(tasksLoadCount, 2);
    expect(walletLoadCount, 2);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('task button always displays backend action text', (
    tester,
  ) async {
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);
    var claimCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async => const [],
          tasksLoader: (_) async => [
            _taskGroup(
              _task(
                taskCode: 'daily_checkin',
                status: 'claimed',
                actionText: 'Received',
              ),
            ),
          ],
          taskClaimer: (_) async {
            claimCalls += 1;
            return const GemTaskActionResult(status: 'claimed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Claimed'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('gem-task-action-daily_checkin')),
    );
    await tester.pump();
    expect(claimCalls, 0);
  });

  testWidgets('daily check-in reports once and refreshes task and wallet', (
    tester,
  ) async {
    final reportResult = Completer<GemTaskActionResult>();
    var reportCalls = 0;
    var productsLoadCount = 0;
    var tasksLoadCount = 0;
    var walletLoadCount = 0;
    final walletStore = GemWalletStore(
      loadWallet: () async {
        walletLoadCount += 1;
        return const GemWallet(balance: 430);
      },
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async {
            productsLoadCount += 1;
            return const [];
          },
          tasksLoader: (_) async {
            tasksLoadCount += 1;
            final completed = tasksLoadCount > 1;
            return [
              _taskGroup(
                _task(
                  taskCode: 'daily_checkin',
                  status: completed ? 'claimed' : 'in_progress',
                  actionText: completed ? 'Received' : 'Check in',
                ),
              ),
            ];
          },
          taskReporter: (taskCode) {
            expect(taskCode, 'daily_checkin');
            reportCalls += 1;
            return reportResult.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(
      const ValueKey<String>('gem-task-action-daily_checkin'),
    );
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(reportCalls, 1);

    reportResult.complete(const GemTaskActionResult(status: 'claimed'));
    await tester.pumpAndSettle();

    expect(productsLoadCount, 1);
    expect(tasksLoadCount, 2);
    expect(walletLoadCount, 2);
    expect(find.text('Received'), findsOneWidget);
  });

  testWidgets('claimable task claims with its task code', (tester) async {
    var productsLoadCount = 0;
    var tasksLoadCount = 0;
    final claimedCodes = <String>[];
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async {
            productsLoadCount += 1;
            return const [];
          },
          tasksLoader: (_) async {
            tasksLoadCount += 1;
            final claimed = tasksLoadCount > 1;
            return [
              _taskGroup(
                _task(
                  taskCode: 'discord_follow',
                  status: claimed ? 'claimed' : 'claimable',
                  actionText: claimed ? 'Received' : 'Collect',
                ),
              ),
            ];
          },
          taskClaimer: (taskCode) async {
            claimedCodes.add(taskCode);
            return const GemTaskActionResult(status: 'claimed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-task-action-discord_follow')),
    );
    await tester.pump();
    await tester.pump();

    expect(claimedCodes, ['discord_follow']);
    expect(productsLoadCount, 1);
    expect(tasksLoadCount, 2);
    expect(find.text('Reward claimed'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

class _FakeBillingService implements BillingService {
  final ValueNotifier<BillingState> _state = ValueNotifier<BillingState>(
    BillingState(storeAvailable: true),
  );
  final StreamController<BillingUiEvent> _events =
      StreamController<BillingUiEvent>.broadcast();
  final List<GemProduct> purchasedProducts = <GemProduct>[];

  @override
  Stream<BillingUiEvent> get events => _events.stream;

  @override
  ValueListenable<BillingState> get state => _state;

  @override
  Future<void> purchaseGem(GemProduct product) async {
    purchasedProducts.add(product);
    _state.value = BillingState(
      storeAvailable: true,
      busyProductIds: <String>{product.productId},
    );
  }

  @override
  Future<void> recover(BillingRecoverySource source) async {}

  @override
  void resetForSession() {}

  @override
  Future<void> start() async {}

  void emitSuccess() {
    _events.add(
      const BillingUiEvent(
        kind: BillingUiEventKind.success,
        productId: 'gem_pack_500',
        attemptId: 'pay_test',
        message: 'Purchase successful.',
      ),
    );
  }

  @override
  void dispose() {
    _state.dispose();
    _events.close();
  }
}

List<GemProduct> _products({int bonusGems = 50}) {
  return [_product('gem_pack_500', bonusGems: bonusGems)];
}

List<GemTaskGroup> _taskGroups() {
  return const [
    GemTaskGroup(
      groupCode: 'starter',
      groupTitle: 'Starter',
      tasks: [
        GemTask(
          taskCode: 'create_first_worldo',
          title: 'Create your first worldo',
          description: 'Create an Origin and launch a world.',
          rewardGems: 50,
          rewardValidDays: 30,
          cycleType: 'once',
          cycleKey: '',
          progress: 0,
          targetCount: 1,
          progressText: '0/1',
          status: 'in_progress',
          actionText: 'Go',
        ),
      ],
    ),
    GemTaskGroup(
      groupCode: 'join_us',
      groupTitle: 'Join us',
      tasks: [
        GemTask(
          taskCode: 'discord_follow',
          title: 'Discord',
          description: 'Join our Discord community.',
          rewardGems: 20,
          rewardValidDays: 30,
          cycleType: 'once',
          cycleKey: '',
          progress: 0,
          targetCount: 1,
          progressText: '0/1',
          status: 'in_progress',
          actionText: 'Follow',
        ),
      ],
    ),
  ];
}

GemTaskGroup _taskGroup(GemTask task) {
  return GemTaskGroup(
    groupCode: 'starter',
    groupTitle: 'Starter',
    tasks: [task],
  );
}

GemTask _task({
  required String taskCode,
  required String status,
  required String actionText,
}) {
  return GemTask(
    taskCode: taskCode,
    title: 'Task title',
    description: 'Task description',
    rewardGems: 20,
    rewardValidDays: 30,
    cycleType: 'once',
    cycleKey: '',
    progress: 0,
    targetCount: 1,
    progressText: '0/1',
    status: status,
    actionText: actionText,
  );
}

GemProduct _product(String productId, {int bonusGems = 50}) {
  final amount = productId == 'gem_pack_1100' ? 590 : 149;
  final gems = productId == 'gem_pack_1100' ? 1100 : 500;
  return GemProduct(
    productId: productId,
    appleProductId: 'com.worldo.$productId',
    googleProductId: 'worldo_$productId',
    baseGems: gems,
    bonusGems: bonusGems,
    priceCurrencyCode: 'USD',
    priceAmount: amount,
    canPurchase: true,
    activityType: 'none',
  );
}
