part of 'origin_editor_pages.dart';

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.completed,
    required this.onTap,
    this.modified = false,
    this.summaryWrap = false,
    this.showDivider = true,
  });

  final String? icon;
  final String title;
  final String summary;
  final bool completed;
  final VoidCallback? onTap;
  final bool modified;
  final bool summaryWrap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  key: ValueKey<String>('section-icon-$title'),
                  width: 24,
                  height: 24,
                  child: icon == null
                      ? null
                      : SvgPicture.asset(icon!, fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                summaryWrap
                                    ? Text(
                                        _summarySingleLine,
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (final line in _summaryLines)
                                            Text(
                                              line,
                                              textAlign: TextAlign.left,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
                                              style: const TextStyle(
                                                color: Color(0xFF666666),
                                                fontSize: 12,
                                                height: 1.4,
                                              ),
                                            ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (modified) ...[
                            _ModifiedSectionBadge(
                              key: ValueKey('section-modified-$title'),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (completed)
                            const Text(
                              '✓',
                              style: TextStyle(
                                color: Color(0xFF1C7D56),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                          if (onTap != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF666666),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            const Divider(height: 1, thickness: 1, color: Color(0xFFEAEAEA)),
        ],
      ),
    );
  }

  List<String> get _summaryLines {
    return summary
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  String get _summarySingleLine {
    return summary.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _ModifiedSectionBadge extends StatelessWidget {
  const _ModifiedSectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: SvgPicture.asset(refreshModifiedIconAsset, fit: BoxFit.contain),
    );
  }
}
