part of 'gem_wallet_page.dart';

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.task,
    required this.status,
    required this.isLoading,
    required this.onTap,
    required this.height,
    required this.borderRadius,
    required this.textHeight,
  });

  final GemTask task;
  final String status;
  final bool isLoading;
  final VoidCallback onTap;
  final double height;
  final double borderRadius;
  final double textHeight;

  @override
  Widget build(BuildContext context) {
    final enabled =
        !isLoading && (status == 'in_progress' || status == 'claimable');
    final actionText = status == task.status
        ? task.actionText
        : switch (status) {
            'claimable' => 'Claim',
            'claimed' => 'Claimed',
            _ => task.actionText,
          };
    final emphasized =
        enabled &&
        (status == 'claimable' ||
            actionText.trim().toLowerCase() == 'check in');
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        key: ValueKey<String>('gem-task-action-${task.taskCode}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : () {},
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: emphasized
                ? context.genesisGemColors.accent
                : context.genesisColors.surfaceTag,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Text(
            actionText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: textHeight,
              fontWeight: FontWeight.w800,
              color: emphasized
                  ? context.genesisColors.textHighEmphasis
                  : context.genesisColors.textBody,
            ),
          ),
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
            ? GenesisLoadingIndicator(
                variant: GenesisLoadingIndicatorVariant.section,
                color: context.genesisGemColors.accent,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: context.genesisColors.textPlaceholder,
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
        color: context.genesisColors.surfaceEmpty,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w600,
          color: context.genesisColors.textPlaceholder,
        ),
      ),
    );
  }
}
