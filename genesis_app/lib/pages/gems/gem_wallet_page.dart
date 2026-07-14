import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/debug_page_tracker.dart';
import '../../app/gems/gem_wallet_store.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/gems/gem_assets.dart';
import '../../components/gems/gem_purchase_catalog.dart';
import '../../components/page_header.dart';
import '../../network/models/gem_product.dart';
import '../../network/models/gem_task.dart';
import '../../network/models/gem_task_action.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/billing_service.dart';
import '../../routers/app_router.dart';

typedef GemTaskActionHandler =
    Future<GemTaskActionResult> Function(String taskCode);
typedef GemProductsLoader =
    Future<List<GemProduct>> Function(BuildContext context);
typedef GemTasksLoader =
    Future<List<GemTaskGroup>> Function(BuildContext context);

class GemWalletPage extends StatefulWidget {
  const GemWalletPage({
    super.key,
    this.productsLoader,
    this.tasksLoader,
    this.walletStore,
    this.billingService,
    this.taskReporter,
    this.taskClaimer,
  });

  final GemProductsLoader? productsLoader;
  final GemTasksLoader? tasksLoader;
  final GemWalletStore? walletStore;
  final BillingService? billingService;
  final GemTaskActionHandler? taskReporter;
  final GemTaskActionHandler? taskClaimer;

  @override
  State<GemWalletPage> createState() => _GemWalletPageState();
}

class _GemWalletPageState extends State<GemWalletPage>
    with WidgetsBindingObserver, RouteAware {
  List<GemProduct>? _products;
  List<GemTaskGroup>? _taskGroups;
  Object? _productsError;
  Object? _tasksError;
  bool _productsLoading = false;
  bool _tasksLoading = false;
  BillingService? _billingService;
  StreamSubscription<BillingUiEvent>? _billingEvents;
  PageRoute<dynamic>? _subscribedRoute;
  int _productsRequestGeneration = 0;
  int _tasksRequestGeneration = 0;
  final Set<String> _loadingTaskCodes = <String>{};
  final Map<String, String> _taskStatusOverrides = <String, String>{};
  final ValueNotifier<BillingState> _idleBillingState =
      ValueNotifier<BillingState>(BillingState());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    genesisPageRouteObserver.unsubscribe(this);
    _billingEvents?.cancel();
    _idleBillingState.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && !identical(route, _subscribedRoute)) {
      genesisPageRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      genesisPageRouteObserver.subscribe(this, route);
    }
    final billingService =
        widget.billingService ?? AppServicesScope.maybeOf(context)?.billing;
    if (billingService != null) _bindBillingService(billingService);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAll(silent: _hasPageData));
      final billingService = _billingService;
      if (billingService != null) {
        unawaited(billingService.recover(BillingRecoverySource.foreground));
      }
    }
  }

  @override
  void didPopNext() {
    unawaited(_refreshAll(silent: _hasPageData));
  }

  bool get _hasPageData => _products != null || _taskGroups != null;

  Future<void> _refreshAll({bool silent = false}) async {
    unawaited(_walletStore.refresh());
    await Future.wait<void>([
      _refreshProducts(silent: silent),
      _refreshTasks(silent: silent),
    ]);
  }

  Future<void> _refreshTasksAndWallet() async {
    unawaited(_walletStore.refresh());
    await _refreshTasks(silent: true);
  }

  Future<void> _refreshProducts({bool silent = false}) async {
    final generation = ++_productsRequestGeneration;
    final future = _loadProducts();
    setState(() {
      _productsLoading = true;
      _productsError = null;
      if (!silent) _products = null;
    });
    try {
      final products = await future;
      if (!mounted || generation != _productsRequestGeneration) return;
      setState(() {
        _products = products;
        _productsError = null;
        _productsLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _productsRequestGeneration) return;
      setState(() {
        _productsError = error;
        _productsLoading = false;
      });
    }
  }

  Future<void> _refreshTasks({bool silent = false}) async {
    final generation = ++_tasksRequestGeneration;
    final future = _loadTasks();
    setState(() {
      _tasksLoading = true;
      _tasksError = null;
      if (!silent) _taskGroups = null;
    });
    try {
      final groups = await future;
      if (!mounted || generation != _tasksRequestGeneration) return;
      setState(() {
        _taskGroups = groups;
        _tasksError = null;
        _tasksLoading = false;
        _taskStatusOverrides.clear();
      });
    } catch (error) {
      if (!mounted || generation != _tasksRequestGeneration) return;
      setState(() {
        _tasksError = error;
        _tasksLoading = false;
      });
    }
  }

  Future<List<GemProduct>> _loadProducts() async {
    final loader = widget.productsLoader;
    if (loader != null) return loader(context);
    return (await AppServicesScope.read(
      context,
    ).api.v1.gem.products()).products;
  }

  Future<List<GemTaskGroup>> _loadTasks() async {
    final loader = widget.tasksLoader;
    if (loader != null) return loader(context);
    return (await AppServicesScope.read(context).api.v1.gem.tasks()).groups;
  }

  String _taskStatus(GemTask task) {
    return _taskStatusOverrides[task.taskCode] ?? task.status;
  }

  Future<GemTaskActionResult> _reportTask(String taskCode) {
    final reporter = widget.taskReporter;
    if (reporter != null) return reporter(taskCode);
    return AppServicesScope.read(context).api.v1.gem.reportTask(taskCode);
  }

  Future<GemTaskActionResult> _claimTask(String taskCode) {
    final claimer = widget.taskClaimer;
    if (claimer != null) return claimer(taskCode);
    return AppServicesScope.read(context).api.v1.gem.claimTask(taskCode);
  }

  Future<void> _handleTaskTap(GemTask task) async {
    final taskCode = task.taskCode.trim();
    if (taskCode.isEmpty || _loadingTaskCodes.contains(taskCode)) return;

    final status = _taskStatus(task);
    if (status == 'claimed') return;
    if (status == 'claimable') {
      await _claimTaskReward(taskCode);
      return;
    }
    if (status != 'in_progress') return;

    switch (taskCode) {
      case 'create_first_worldo':
        await _openCreateWorld(taskCode);
        return;
      case 'launch_first_world':
      case 'invite_friend':
      case 'write_comment':
      case 'request_join_world':
      case 'send_message':
      case 'progress_world':
        showGenesisToast(context, taskCode);
        return;
      case 'daily_checkin':
      case 'discord_follow':
        await _reportTaskAction(taskCode);
        return;
    }
  }

  Future<void> _openCreateWorld(String taskCode) async {
    if (!_beginTaskAction(taskCode)) return;
    try {
      await Navigator.of(context).pushNamed(RouteNames.create);
    } finally {
      _endTaskAction(taskCode);
    }
  }

  Future<void> _reportTaskAction(String taskCode) async {
    if (!_beginTaskAction(taskCode)) return;
    try {
      final result = await _reportTask(taskCode);
      if (!mounted) return;
      setState(() => _taskStatusOverrides[taskCode] = result.status);
      await _refreshTasksAndWallet();
    } catch (_) {
      if (mounted) showGenesisToast(context, 'Task update failed.');
    } finally {
      _endTaskAction(taskCode);
    }
  }

  Future<void> _claimTaskReward(String taskCode) async {
    if (!_beginTaskAction(taskCode)) return;
    try {
      final result = await _claimTask(taskCode);
      if (!mounted) return;
      if (result.status != 'claimed') {
        showGenesisToast(context, '领取失败');
        return;
      }
      setState(() => _taskStatusOverrides[taskCode] = result.status);
      showGenesisToast(context, 'Reward claimed');
      await _refreshTasksAndWallet();
    } catch (_) {
      if (mounted) showGenesisToast(context, '领取失败');
    } finally {
      _endTaskAction(taskCode);
    }
  }

  bool _beginTaskAction(String taskCode) {
    if (_loadingTaskCodes.contains(taskCode)) return false;
    setState(() => _loadingTaskCodes.add(taskCode));
    return true;
  }

  void _endTaskAction(String taskCode) {
    if (!mounted || !_loadingTaskCodes.contains(taskCode)) return;
    setState(() => _loadingTaskCodes.remove(taskCode));
  }

  GemWalletStore get _walletStore =>
      widget.walletStore ?? AppServicesScope.read(context).gemWallet;

  ValueListenable<BillingState> get _billingStateListenable =>
      _billingService?.state ?? _idleBillingState;

  void _bindBillingService(BillingService service) {
    if (identical(_billingService, service)) return;
    _billingEvents?.cancel();
    _billingService = service;
    _billingEvents = service.events.listen(_handleBillingEvent);
    unawaited(service.start());
    if (mounted) setState(() {});
  }

  Future<void> _purchaseProduct(GemProduct product) async {
    final service =
        _billingService ??
        widget.billingService ??
        AppServicesScope.maybeRead(context)?.billing;
    if (service == null) {
      showGenesisToast(context, 'Google Play is unavailable.');
      return;
    }
    _bindBillingService(service);
    await service.purchaseGem(product);
  }

  void _handleBillingEvent(BillingUiEvent event) {
    if (!mounted) return;
    showGenesisToast(context, event.message);
    if (event.kind == BillingUiEventKind.success) {
      unawaited(_refreshAll(silent: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletStateListenable = _walletStore.state;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: GenesisBackAppBar(
        pageName: 'Buy Gems',
        titleStyle: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 16,
          height: 22 / 16,
          fontWeight: FontWeight.w600,
        ),
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(RouteNames.gemRecords),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 20, 10),
              child: Text(
                'Records',
                style: TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 12,
                  height: 18 / 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(walletStateListenable)),
    );
  }

  Widget _buildBody(ValueListenable<GemWalletState> walletStateListenable) {
    if (!_hasPageData && (_productsLoading || _tasksLoading)) {
      return const _GemWalletLoading();
    }
    if (!_hasPageData && _productsError != null && _tasksError != null) {
      return _GemWalletError(onRetry: () => unawaited(_refreshAll()));
    }
    return RefreshIndicator(
      color: const Color(0xFFFF2D4F),
      onRefresh: () => _refreshAll(silent: true),
      child: _GemWalletContent(
        products: _products,
        taskGroups: _taskGroups,
        productsLoading: _productsLoading,
        tasksLoading: _tasksLoading,
        productsError: _productsError,
        tasksError: _tasksError,
        walletStateListenable: walletStateListenable,
        billingStateListenable: _billingStateListenable,
        onPurchase: _purchaseProduct,
        onRetryProducts: () => unawaited(_refreshProducts()),
        onRetryTasks: () => unawaited(_refreshTasks()),
        taskStatusFor: _taskStatus,
        isTaskLoading: _loadingTaskCodes.contains,
        onTaskTap: _handleTaskTap,
      ),
    );
  }
}

class _GemWalletContent extends StatelessWidget {
  const _GemWalletContent({
    required this.products,
    required this.taskGroups,
    required this.productsLoading,
    required this.tasksLoading,
    required this.productsError,
    required this.tasksError,
    required this.walletStateListenable,
    required this.billingStateListenable,
    required this.onPurchase,
    required this.onRetryProducts,
    required this.onRetryTasks,
    required this.taskStatusFor,
    required this.isTaskLoading,
    required this.onTaskTap,
  });

  final List<GemProduct>? products;
  final List<GemTaskGroup>? taskGroups;
  final bool productsLoading;
  final bool tasksLoading;
  final Object? productsError;
  final Object? tasksError;
  final ValueListenable<GemWalletState> walletStateListenable;
  final ValueListenable<BillingState> billingStateListenable;
  final ValueChanged<GemProduct> onPurchase;
  final VoidCallback onRetryProducts;
  final VoidCallback onRetryTasks;
  final String Function(GemTask task) taskStatusFor;
  final bool Function(String taskCode) isTaskLoading;
  final ValueChanged<GemTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        ValueListenableBuilder<GemWalletState>(
          valueListenable: walletStateListenable,
          builder: (context, walletState, _) {
            return GemBalancePanel(balance: walletState.balance ?? 0);
          },
        ),
        const SizedBox(height: 20),
        if (products == null)
          _GemSectionStatePanel(
            isLoading: productsLoading,
            hasError: productsError != null,
            errorMessage: 'Unable to load gem packs.',
            onRetry: onRetryProducts,
          )
        else if (products!.isEmpty)
          const _GemEmptyPanel(message: 'No gem packs available.')
        else
          GemProductGrid(
            products: products!,
            billingStateListenable: billingStateListenable,
            onPurchase: onPurchase,
          ),
        const SizedBox(height: 26),
        if (taskGroups == null)
          _GemSectionStatePanel(
            isLoading: tasksLoading,
            hasError: tasksError != null,
            errorMessage: 'Unable to load gem tasks.',
            onRetry: onRetryTasks,
          )
        else
          for (final group in taskGroups!)
            if (group.tasks.isNotEmpty) ...[
              _TaskGroupSection(
                group: group,
                taskStatusFor: taskStatusFor,
                isTaskLoading: isTaskLoading,
                onTaskTap: onTaskTap,
              ),
              const SizedBox(height: 20),
            ],
      ],
    );
  }
}

class _TaskGroupSection extends StatelessWidget {
  const _TaskGroupSection({
    required this.group,
    required this.taskStatusFor,
    required this.isTaskLoading,
    required this.onTaskTap,
  });

  final GemTaskGroup group;
  final String Function(GemTask task) taskStatusFor;
  final bool Function(String taskCode) isTaskLoading;
  final ValueChanged<GemTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final isJoinUs =
        group.groupCode == 'join_us' ||
        group.groupTitle.trim().toLowerCase() == 'join us';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.groupTitle,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 10),
        for (final task in group.tasks) ...[
          if (isJoinUs)
            _JoinUsTaskRow(
              task: task,
              status: taskStatusFor(task),
              isLoading: isTaskLoading(task.taskCode),
              onTap: () => onTaskTap(task),
            )
          else
            _TaskRow(
              task: task,
              status: taskStatusFor(task),
              isLoading: isTaskLoading(task.taskCode),
              onTap: () => onTaskTap(task),
            ),
          SizedBox(height: isJoinUs ? 10 : 12),
        ],
      ],
    );
  }
}

class _JoinUsTaskRow extends StatelessWidget {
  const _JoinUsTaskRow({
    required this.task,
    required this.status,
    required this.isLoading,
    required this.onTap,
  });

  final GemTask task;
  final String status;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/custom-icons/svg/discord-svgrepo-com.svg',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 18 / 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${formatGemInteger(task.rewardGems)}',
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 4),
          SvgPicture.asset(
            gemIconAsset,
            key: ValueKey<String>('gem-task-reward-icon-${task.taskCode}'),
            width: gemSmallIconSize,
            height: gemSmallIconSize,
          ),
          const SizedBox(width: 10),
          _TaskActionButton(
            task: task,
            status: status,
            isLoading: isLoading,
            onTap: onTap,
            width: 54,
            height: 24,
            borderRadius: 12,
            textHeight: 14 / 11,
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.status,
    required this.isLoading,
    required this.onTap,
  });

  final GemTask task;
  final String status;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 16 / 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 14 / 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '+${formatGemInteger(task.rewardGems)}',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(width: 2),
                    SvgPicture.asset(
                      gemIconAsset,
                      key: ValueKey<String>(
                        'gem-task-reward-icon-${task.taskCode}',
                      ),
                      width: gemSmallIconSize,
                      height: gemSmallIconSize,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _TaskActionButton(
                  task: task,
                  status: status,
                  isLoading: isLoading,
                  onTap: onTap,
                  width: 64,
                  height: 19,
                  borderRadius: 10,
                  textHeight: 14 / 11,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.task,
    required this.status,
    required this.isLoading,
    required this.onTap,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.textHeight,
  });

  final GemTask task;
  final String status;
  final bool isLoading;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double borderRadius;
  final double textHeight;

  @override
  Widget build(BuildContext context) {
    final enabled =
        !isLoading && (status == 'in_progress' || status == 'claimable');
    final color = status == 'claimed'
        ? const Color(0xFFFF9AAA)
        : const Color(0xFFF42C47);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        key: ValueKey<String>('gem-task-action-${task.taskCode}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Text(
            task.actionText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: textHeight,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _GemWalletLoading extends StatelessWidget {
  const _GemWalletLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFFFF2D4F),
        ),
      ),
    );
  }
}

class _GemWalletError extends StatelessWidget {
  const _GemWalletError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unable to load gems.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _GemSectionStatePanel extends StatelessWidget {
  const _GemSectionStatePanel({
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Center(
        child: isLoading || !hasError
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF2D4F),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 28,
                    child: FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GemEmptyPanel extends StatelessWidget {
  const _GemEmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
        ),
      ),
    );
  }
}
