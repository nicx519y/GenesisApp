part of 'gem_wallet_page.dart';

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
    final foregroundColor = switch (status) {
      'claimable' => kGemAccentColor,
      'in_progress' => kGemTaskProgressForegroundColor,
      'claimed' => kGemTaskClaimedForegroundColor,
      _ => kGemTaskActionColor,
    };
    final actionText = status == task.status
        ? task.actionText
        : switch (status) {
            'claimable' => 'Claim',
            'claimed' => 'Claimed',
            _ => task.actionText,
          };
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        key: ValueKey<String>('gem-task-action-${task.taskCode}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : () {},
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Text(
            actionText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: textHeight,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
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
          color: kGemAccentColor,
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
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            GenesisButton(
              label: 'Retry',
              onPressed: onRetry,
              size: GenesisButtonSize.compact,
              fullWidth: false,
            ),
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
                  color: kGemAccentColor,
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
