import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/app/debug_page_tracker.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/components/common/genesis_action_box.dart';
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

const _wrappingTaskDescription =
    'Create an Origin and launch a world, then continue exploring locations '
    'and interacting with characters to move its story forward.';

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
    expect(find.text('+550'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('USD1.49'), findsOneWidget);
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Create your first worldo'), findsOneWidget);

    final pageTitleStyle = tester.widget<Text>(find.text('Buy Gems')).style;
    expect(pageTitleStyle?.fontSize, 16);
    expect(pageTitleStyle?.height, 22 / 16);
    expect(pageTitleStyle?.fontWeight, FontWeight.w600);
    expect(pageTitleStyle?.color, const Color(0xFF333333));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('gem-balance-panel'))).dy -
          tester.getRect(find.text('Buy Gems')).bottom,
      closeTo(26, 0.1),
    );

    final recordsStyle = tester.widget<Text>(find.text('Records')).style;
    expect(recordsStyle?.fontSize, 12);
    expect(recordsStyle?.height, 18 / 12);
    expect(recordsStyle?.fontWeight, FontWeight.w600);
    expect(recordsStyle?.color, const Color(0xFF333333));

    final groupTitleStyle = tester.widget<Text>(find.text('Starter')).style;
    expect(groupTitleStyle?.fontSize, 16);
    expect(groupTitleStyle?.height, 20 / 16);
    expect(groupTitleStyle?.fontWeight, FontWeight.w600);
    expect(groupTitleStyle?.color, const Color(0xFF111111));

    final taskTitleStyle = tester
        .widget<Text>(find.text('Create your first worldo'))
        .style;
    expect(taskTitleStyle?.fontSize, 14);
    expect(taskTitleStyle?.height, 16 / 14);
    expect(taskTitleStyle?.fontWeight, FontWeight.w600);
    expect(taskTitleStyle?.color, const Color(0xFF111111));

    final descriptionStyle = tester
        .widget<Text>(find.text(_wrappingTaskDescription))
        .style;
    expect(descriptionStyle?.fontSize, 12);
    expect(descriptionStyle?.height, 14 / 12);
    expect(descriptionStyle?.fontWeight, FontWeight.w400);
    expect(descriptionStyle?.color, const Color(0xFF888888));
    final description = tester.widget<Text>(
      find.text(_wrappingTaskDescription),
    );
    expect(description.maxLines, isNull);
    expect(description.overflow, isNull);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('gem-task-row-create_first_worldo'),
            ),
          )
          .height,
      greaterThan(62),
    );

    final actionStyle = tester.widget<Text>(find.text('Go')).style;
    expect(actionStyle?.fontSize, 12);
    expect(actionStyle?.height, 14 / 12);
    expect(actionStyle?.fontWeight, FontWeight.w600);
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('gem-task-action-create_first_worldo'),
        ),
      ),
      const Size(64, 24),
    );
    final taskRewardStyle = tester.widget<Text>(find.text('+50')).style;
    expect(taskRewardStyle?.fontSize, 14);
    expect(taskRewardStyle?.fontWeight, FontWeight.w600);
    expect(taskRewardStyle?.color, const Color(0xFF111111));
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('gem-task-reward-icon-create_first_worldo'),
        ),
      ),
      const Size.square(14),
    );

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

    final joinUsStyle = tester.widget<Text>(find.text('Join us')).style;
    expect(joinUsStyle?.fontSize, 16);
    expect(joinUsStyle?.height, 20 / 16);
    expect(joinUsStyle?.fontWeight, FontWeight.w600);
    expect(joinUsStyle?.color, const Color(0xFF111111));

    final discordStyle = tester.widget<Text>(find.text('Discord')).style;
    expect(discordStyle?.fontSize, 14);
    expect(discordStyle?.height, 16 / 14);
    expect(discordStyle?.fontWeight, FontWeight.w600);
    expect(discordStyle?.color, const Color(0xFF111111));
    final joinUsRewardStyle = tester.widget<Text>(find.text('+20')).style;
    expect(joinUsRewardStyle?.fontSize, 14);
    expect(joinUsRewardStyle?.fontWeight, FontWeight.w600);
    expect(joinUsRewardStyle?.color, const Color(0xFF111111));
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('gem-task-reward-icon-discord_follow'),
        ),
      ),
      const Size.square(14),
    );

    final followStyle = tester.widget<Text>(find.text('Follow')).style;
    expect(followStyle?.fontSize, 12);
    expect(followStyle?.height, 14 / 12);
    expect(followStyle?.fontWeight, FontWeight.w600);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('gem-task-action-discord_follow')),
      ),
      const Size(64, 24),
    );
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
    final recordsTitle = tester.widget<Text>(find.text('Gem Records'));
    expect(recordsTitle.style?.fontSize, 16);
    expect(recordsTitle.style?.height, 22 / 16);
    expect(recordsTitle.style?.fontWeight, FontWeight.w600);
    expect(recordsTitle.style?.color, const Color(0xFF111111));
    expect(
      tester.getTopLeft(find.byType(TabBar)).dy -
          tester.getRect(find.text('Gem Records')).bottom,
      closeTo(14, 0.1),
    );
    expect(find.text('Daily check-in'), findsOneWidget);
    expect(find.text('Starter reward'), findsNothing);
    expect(find.text(formatGemRecordTimestamp(1783586400)), findsOneWidget);
    expect(requestedScenes, contains('all'));

    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.labelStyle?.fontSize, 14);
    expect(tabs.labelStyle?.height, 20 / 14);
    expect(tabs.labelStyle?.fontWeight, FontWeight.w600);
    expect(tabs.labelColor, const Color(0xFF333333));
    expect(tabs.unselectedLabelStyle?.fontSize, 14);
    expect(tabs.unselectedLabelStyle?.height, 20 / 14);
    expect(tabs.unselectedLabelStyle?.fontWeight, FontWeight.w400);
    expect(tabs.unselectedLabelColor, const Color(0xFF999999));

    final recordTitleStyle = tester
        .widget<Text>(find.text('Daily check-in'))
        .style;
    expect(recordTitleStyle?.fontSize, 14);
    expect(recordTitleStyle?.height, 17 / 14);
    expect(recordTitleStyle?.fontWeight, FontWeight.w600);
    expect(recordTitleStyle?.color, const Color(0xFF111111));

    final recordTimeStyle = tester
        .widget<Text>(find.text(formatGemRecordTimestamp(1783586400)))
        .style;
    expect(recordTimeStyle?.fontSize, 12);
    expect(recordTimeStyle?.height, 14 / 12);
    expect(recordTimeStyle?.fontWeight, FontWeight.w400);
    expect(recordTimeStyle?.color, const Color(0xFF999999));

    final amountStyle = tester.widget<Text>(find.text('+50')).style;
    expect(amountStyle?.fontSize, 14);
    expect(amountStyle?.height, 20 / 14);
    expect(amountStyle?.fontWeight, FontWeight.w600);
    expect(amountStyle?.color, const Color(0xFFFF2442));

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

  testWidgets('GemWalletPage hides original amount without bonus gems', (
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
          productsLoader: (_) async => _products(bonusGems: 0),
          tasksLoader: (_) async => _taskGroups(),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
    expect(find.textContaining('Purchasing Gems'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);

    billing.emitProcessing();
    await tester.pump();
    expect(find.textContaining('Purchasing Gems'), findsOneWidget);

    billing.emitSuccess();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('OK'));
    await tester.pump();
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
    _expectGrantedSuccessDialog(tester);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('billing processing dialog blocks interaction until success OK', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    billing.emitProcessing();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Purchasing Gems'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('genesis-action-box-title-row')))
          .height,
      202,
    );
    final processingActionBoxSize = tester.getSize(
      find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
    );

    await tester.tapAt(Offset.zero);
    await tester.pump();
    expect(find.textContaining('Purchasing Gems'), findsOneWidget);

    billing.emitSuccess();
    await tester.pumpAndSettle();

    _expectGrantedSuccessDialog(tester);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('billing-purchase-granted-line')),
          )
          .height,
      lessThanOrEqualTo(21),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('genesis-action-box-title-row')))
          .height,
      150,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
      ),
      processingActionBoxSize,
    );

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Purchase successful!'), findsNothing);
    expect(find.text('Go Chat Now.'), findsNothing);
  });

  testWidgets('billing accepted keeps dialog until OK', (tester) async {
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

    billing.emitProcessing();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Purchasing Gems'), findsOneWidget);

    billing.emitAccepted();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Payment successful. Your Gems are being issued as quickly as possible. Please check your balance again later.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Payment successful. Your Gems are being issued as quickly as possible. Please check your balance again later.',
      ),
      findsNothing,
    );
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

  testWidgets('in-progress tasks show user-facing guidance', (tester) async {
    const messages = <String, String>{
      'launch_first_world':
          'Open a Worldo you like, then Launch your own world.',
      'invite_friend': 'Open a World, then tap Invite in the detail panel.',
      'write_comment': 'Open a Worldo you liked, then write a post in Discuss.',
      'request_join_world':
          'Open a World you haven’t joined, then request to join it.',
      'send_message': 'Send messages in your world.',
      'progress_world': 'Open your launched World, then tap Progress.',
    };
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    for (final entry in messages.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: GemWalletPage(
            key: ValueKey<String>('guidance-${entry.key}'),
            walletStore: walletStore,
            productsLoader: (_) async => const [],
            tasksLoader: (_) async => [
              _taskGroup(
                _task(
                  taskCode: entry.key,
                  status: 'in_progress',
                  actionText: 'Go',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ValueKey<String>('gem-task-action-${entry.key}')),
      );
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    }
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
    expect(find.text('Check in successful.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('task reporting shows task-specific failure messages', (
    tester,
  ) async {
    const messages = <String, String>{
      'daily_checkin': 'Check in failed.',
      'discord_follow': 'Follow failed.',
    };
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    for (final entry in messages.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: GemWalletPage(
            key: ValueKey<String>('report-failure-${entry.key}'),
            walletStore: walletStore,
            productsLoader: (_) async => const [],
            tasksLoader: (_) async => [
              _taskGroup(
                _task(
                  taskCode: entry.key,
                  status: 'in_progress',
                  actionText: 'Go',
                ),
              ),
            ],
            taskReporter: (_) async => throw Exception('report failed'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ValueKey<String>('gem-task-action-${entry.key}')),
      );
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    }
  });

  testWidgets('claim failure uses English toast', (tester) async {
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async => const [],
          tasksLoader: (_) async => [
            _taskGroup(
              _task(
                taskCode: 'daily_checkin',
                status: 'claimable',
                actionText: 'Collect',
              ),
            ),
          ],
          taskClaimer: (_) async =>
              const GemTaskActionResult(status: 'claimable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-task-action-daily_checkin')),
    );
    await tester.pump();

    expect(find.text('Claim failed.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Discord follow opens the Me page invite and reports the task', (
    tester,
  ) async {
    final launchedUris = <Uri>[];
    final reportedCodes = <String>[];
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async => const [],
          tasksLoader: (_) async => _taskGroups(),
          discordLauncher: (uri) async {
            launchedUris.add(uri);
            return true;
          },
          taskReporter: (taskCode) async {
            reportedCodes.add(taskCode);
            return const GemTaskActionResult(status: 'claimable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final followButton = find.byKey(
      const ValueKey<String>('gem-task-action-discord_follow'),
    );
    await tester.scrollUntilVisible(
      followButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(followButton);
    await tester.pumpAndSettle();

    expect(launchedUris, [Uri.parse('https://discord.gg/wuKHk7cyX7')]);
    expect(reportedCodes, ['discord_follow']);
  });

  testWidgets('repeated Discord row taps open every time but report once', (
    tester,
  ) async {
    final reportResult = Completer<GemTaskActionResult>();
    final launchedUris = <Uri>[];
    var reportCalls = 0;
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async => const [],
          tasksLoader: (_) async => [
            _joinUsGroup(status: 'in_progress', actionText: 'Follow'),
          ],
          discordLauncher: (uri) async {
            launchedUris.add(uri);
            return true;
          },
          taskReporter: (_) {
            reportCalls += 1;
            return reportResult.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(
      const ValueKey<String>('gem-join-us-row-discord_follow'),
    );
    await tester.tap(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pump();

    expect(launchedUris, [
      Uri.parse('https://discord.gg/wuKHk7cyX7'),
      Uri.parse('https://discord.gg/wuKHk7cyX7'),
    ]);
    expect(reportCalls, 1);

    reportResult.complete(const GemTaskActionResult(status: 'claimable'));
    await tester.pumpAndSettle();
  });

  testWidgets('Discord row always opens while claimable button only claims', (
    tester,
  ) async {
    final launchedUris = <Uri>[];
    final reportedCodes = <String>[];
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
          productsLoader: (_) async => const [],
          tasksLoader: (_) async => [
            _joinUsGroup(status: 'claimable', actionText: 'Claim'),
          ],
          discordLauncher: (uri) async {
            launchedUris.add(uri);
            return true;
          },
          taskReporter: (taskCode) async {
            reportedCodes.add(taskCode);
            return const GemTaskActionResult(status: 'claimable');
          },
          taskClaimer: (taskCode) async {
            claimedCodes.add(taskCode);
            return const GemTaskActionResult(status: 'claimed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(
      const ValueKey<String>('gem-join-us-row-discord_follow'),
    );
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(launchedUris, [Uri.parse('https://discord.gg/wuKHk7cyX7')]);
    expect(reportedCodes, isEmpty);
    expect(claimedCodes, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-task-action-discord_follow')),
    );
    await tester.pumpAndSettle();

    expect(launchedUris, hasLength(1));
    expect(reportedCodes, isEmpty);
    expect(claimedCodes, ['discord_follow']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('claimed Discord button is disabled but its row still opens', (
    tester,
  ) async {
    final launchedUris = <Uri>[];
    final walletStore = GemWalletStore(
      loadWallet: () async => const GemWallet(balance: 430),
      readUid: () async => 'u_user',
    );
    addTearDown(walletStore.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GemWalletPage(
          walletStore: walletStore,
          productsLoader: (_) async => const [],
          tasksLoader: (_) async => [
            _joinUsGroup(status: 'claimed', actionText: 'Claimed'),
          ],
          discordLauncher: (uri) async {
            launchedUris.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-task-action-discord_follow')),
    );
    await tester.pump();
    expect(launchedUris, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-join-us-row-discord_follow')),
    );
    await tester.pumpAndSettle();
    expect(launchedUris, [Uri.parse('https://discord.gg/wuKHk7cyX7')]);
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

void _expectGrantedSuccessDialog(WidgetTester tester) {
  expect(find.text('Purchase successful!'), findsOneWidget);
  expect(find.text('Go Chat Now.'), findsNothing);
  expect(find.byType(GenesisActionBox<bool>), findsOneWidget);
  final successTitle = tester.widget<Text>(
    find.byKey(const ValueKey<String>('billing-purchase-success-title')),
  );
  expect(successTitle.style?.fontSize, 16);
  expect(successTitle.style?.fontWeight, FontWeight.w600);
  expect(
    tester
        .getSize(
          find.byKey(
            const ValueKey<String>('billing-purchase-success-line-gap'),
          ),
        )
        .height,
    12,
  );
  final grantedLine = tester.widget<Text>(
    find.byKey(const ValueKey<String>('billing-purchase-granted-line')),
  );
  expect(grantedLine.style?.fontSize, 14);
  expect(grantedLine.style?.fontWeight, FontWeight.w400);
  final spans = (grantedLine.textSpan! as TextSpan).children!;
  expect(spans[0], isA<WidgetSpan>());
  expect(
    find.byKey(const ValueKey<String>('billing-purchase-granted-icon')),
    findsOneWidget,
  );
  expect((spans[1] as TextSpan).text, '550');
  expect((spans[1] as TextSpan).style?.color, const Color(0xFFFF2442));
  expect((spans[2] as TextSpan).text, ' Gems have been granted.');
  final okText = tester.widget<Text>(find.text('OK'));
  expect(okText.style?.fontSize, 15);
  expect(okText.style?.fontWeight, FontWeight.w600);
  expect(
    tester
        .getSize(find.byKey(const ValueKey('genesis-action-box-action-row')))
        .height,
    GenesisActionBox.defaultRowHeight,
  );
  expect(find.byType(SvgPicture), findsWidgets);
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

  void emitProcessing() {
    _events.add(
      const BillingUiEvent(
        kind: BillingUiEventKind.processing,
        productId: 'gem_pack_500',
        attemptId: 'pay_test',
        message: 'Purchasing Gems',
      ),
    );
  }

  void emitSuccess({int grantedGems = 550}) {
    _events.add(
      BillingUiEvent(
        kind: BillingUiEventKind.success,
        productId: 'gem_pack_500',
        attemptId: 'pay_test',
        message: 'Purchase successful!',
        grantedGems: grantedGems,
      ),
    );
  }

  void emitAccepted() {
    _events.add(
      const BillingUiEvent(
        kind: BillingUiEventKind.accepted,
        productId: 'gem_pack_500',
        attemptId: 'pay_test',
        message:
            'Payment successful. Your Gems are being issued as quickly as possible. Please check your balance again later.',
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
          description: _wrappingTaskDescription,
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

GemTaskGroup _joinUsGroup({
  required String status,
  required String actionText,
}) {
  return GemTaskGroup(
    groupCode: 'join_us',
    groupTitle: 'Join us',
    tasks: [
      _task(taskCode: 'discord_follow', status: status, actionText: actionText),
    ],
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
