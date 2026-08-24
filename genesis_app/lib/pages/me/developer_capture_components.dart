part of 'developer_page.dart';

class _DeveloperCaptureHeader extends StatelessWidget {
  const _DeveloperCaptureHeader({
    required this.title,
    required this.totalCount,
    required this.clearKey,
    required this.switchKey,
    required this.enabled,
    required this.onClear,
    required this.onEnabledChanged,
    this.visibleCount,
    this.enabledControl = true,
    this.countKey,
  });

  final String title;
  final int totalCount;
  final int? visibleCount;
  final Key? countKey;
  final Key clearKey;
  final Key switchKey;
  final bool enabled;
  final bool enabledControl;
  final VoidCallback? onClear;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final count = visibleCount == null || visibleCount == totalCount
        ? '$totalCount'
        : '${visibleCount!}/$totalCount';
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.genesisColors.textPrimary,
            ),
          ),
        ),
        Text(
          count,
          key: countKey,
          style: TextStyle(
            fontSize: 11,
            color: context.genesisColors.textSubtle,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          key: clearKey,
          behavior: HitTestBehavior.opaque,
          onTap: onClear,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Clear',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onClear == null
                    ? context.genesisColors.textDisabled
                    : context.genesisColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          height: 32,
          child: FittedBox(
            fit: BoxFit.contain,
            child: _DeveloperSwitch(
              switchKey: switchKey,
              value: enabled,
              onChanged: enabledControl ? onEnabledChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeveloperCaptureDetailSection extends StatelessWidget {
  const _DeveloperCaptureDetailSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.content,
    required this.contentKey,
    this.copyLabel,
    this.copyKey,
    this.selectable = false,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final String content;
  final Key contentKey;
  final String? copyLabel;
  final Key? copyKey;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (copyLabel != null)
                  GestureDetector(
                    key: copyKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: content));
                      if (context.mounted) {
                        showGenesisToast(context, copyLabel!);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy, size: 15),
                    ),
                  ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.genesisColors.surfaceRaised,
              borderRadius: BorderRadius.circular(6),
            ),
            child: selectable
                ? SelectionArea(child: _contentText(context))
                : _contentText(context),
          ),
      ],
    );
  }

  Text _contentText(BuildContext context) {
    return Text(
      content,
      key: contentKey,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        height: 1.35,
        color: context.genesisColors.textBody,
      ),
    );
  }
}
