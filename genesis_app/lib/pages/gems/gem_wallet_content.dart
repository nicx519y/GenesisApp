part of 'gem_wallet_page.dart';

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
    required this.onJoinUsTap,
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
  final ValueChanged<GemTask> onJoinUsTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        ValueListenableBuilder<GemWalletState>(
          valueListenable: walletStateListenable,
          builder: (context, walletState, _) {
            return GemPurchaseCatalogSection(
              balance: walletState.balance ?? 0,
              catalog: products == null
                  ? _GemSectionStatePanel(
                      isLoading: productsLoading,
                      hasError: productsError != null,
                      errorMessage: 'Unable to load gem packs.',
                      onRetry: onRetryProducts,
                    )
                  : products!.isEmpty
                  ? const _GemEmptyPanel(message: 'No gem packs available.')
                  : GemProductGrid(
                      products: products!,
                      billingStateListenable: billingStateListenable,
                      onPurchase: onPurchase,
                    ),
            );
          },
        ),
        const SizedBox(height: 22),
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
                onJoinUsTap: onJoinUsTap,
              ),
              const SizedBox(height: 13),
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
    required this.onJoinUsTap,
  });

  final GemTaskGroup group;
  final String Function(GemTask task) taskStatusFor;
  final bool Function(String taskCode) isTaskLoading;
  final ValueChanged<GemTask> onTaskTap;
  final ValueChanged<GemTask> onJoinUsTap;

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
          style: TextStyle(
            fontSize: 15,
            height: 1,
            fontWeight: FontWeight.w800,
            color: context.genesisColors.textPrimary,
          ),
        ),
        const SizedBox(height: 11),
        for (final task in group.tasks) ...[
          if (isJoinUs)
            _JoinUsTaskRow(
              task: task,
              status: taskStatusFor(task),
              isLoading: isTaskLoading(task.taskCode),
              onRowTap: () => onJoinUsTap(task),
              onButtonTap: () => onTaskTap(task),
            )
          else
            _TaskRow(
              task: task,
              status: taskStatusFor(task),
              isLoading: isTaskLoading(task.taskCode),
              onTap: () => onTaskTap(task),
            ),
          const SizedBox(height: 9),
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
    required this.onRowTap,
    required this.onButtonTap,
  });

  final GemTask task;
  final String status;
  final bool isLoading;
  final VoidCallback onRowTap;
  final VoidCallback onButtonTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('gem-join-us-row-${task.taskCode}'),
      behavior: HitTestBehavior.opaque,
      onTap: onRowTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: context.genesisColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/custom-icons/svg/discord-svgrepo-com.svg',
              width: 16,
              height: 16,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: context.genesisColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _TaskReward(task: task),
            const SizedBox(width: 10),
            _TaskActionButton(
              task: task,
              status: status,
              isLoading: isLoading,
              onTap: onButtonTap,
              height: 28,
              borderRadius: 9,
              textHeight: 1,
            ),
          ],
        ),
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
      key: ValueKey<String>('gem-task-row-${task.taskCode}'),
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: context.genesisColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
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
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: context.genesisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    color: context.genesisColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TaskReward(task: task),
              const SizedBox(width: 10),
              _TaskActionButton(
                task: task,
                status: status,
                isLoading: isLoading,
                onTap: onTap,
                height: 28,
                borderRadius: 9,
                textHeight: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskReward extends StatelessWidget {
  const _TaskReward({required this.task});

  final GemTask task;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey<String>('gem-task-reward-${task.taskCode}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          gemIconAsset,
          key: ValueKey<String>('gem-task-reward-icon-${task.taskCode}'),
          width: 9,
          height: 14,
        ),
        const SizedBox(width: 5),
        Text(
          '+${formatGemInteger(task.rewardGems)}',
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w800,
            color: context.genesisColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
