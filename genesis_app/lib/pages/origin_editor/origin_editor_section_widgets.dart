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
    this.wrapFirstSummaryLine = false,
    this.showDivider = true,
    this.createHubStyle = false,
  });

  final String? icon;
  final String title;
  final String summary;
  final bool completed;
  final VoidCallback? onTap;
  final bool modified;
  final bool wrapFirstSummaryLine;
  final bool showDivider;
  final bool createHubStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: createHubStyle ? 15 : 14),
            child: Row(
              crossAxisAlignment: createHubStyle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  key: ValueKey<String>('section-icon-$title'),
                  width: createHubStyle ? 34 : 24,
                  height: createHubStyle ? 34 : 24,
                  alignment: Alignment.center,
                  decoration: createHubStyle
                      ? BoxDecoration(
                          color: GenesisPalette.redesignWhite07,
                          borderRadius: BorderRadius.circular(11),
                        )
                      : null,
                  child: icon == null
                      ? null
                      : SizedBox(
                          width: createHubStyle ? 16 : 24,
                          height: createHubStyle ? 16 : 24,
                          child: SvgPicture.asset(
                            icon!,
                            fit: BoxFit.contain,
                            colorFilter: createHubStyle
                                ? const ColorFilter.mode(
                                    GenesisPalette.white,
                                    BlendMode.srcIn,
                                  )
                                : null,
                          ),
                        ),
                ),
                SizedBox(width: createHubStyle ? 13 : 14),
                Expanded(
                  child: Column(
                    key: ValueKey<String>('section-content-$title'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      color: createHubStyle
                                          ? GenesisPalette.white
                                          : context
                                                .genesisColors
                                                .foregroundStrong,
                                      fontSize: createHubStyle ? 14 : 16,
                                      fontWeight: createHubStyle
                                          ? FontWeight.w800
                                          : FontWeight.w400,
                                      height: createHubStyle ? 1.15 : 1.2,
                                    ),
                                  ),
                                ),
                                if (completed && !createHubStyle) ...[
                                  SizedBox(width: 6),
                                  Text(
                                    '✓',
                                    key: ValueKey<String>(
                                      'section-completed-$title',
                                    ),
                                    style: TextStyle(
                                      color: context
                                          .genesisCreateColors
                                          .successText,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1,
                                    ),
                                  ),
                                ],
                                if (modified) ...[
                                  SizedBox(width: 6),
                                  _ModifiedSectionBadge(
                                    key: ValueKey('section-modified-$title'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (onTap != null && !createHubStyle) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              key: ValueKey<String>('section-chevron-$title'),
                              size: 24,
                              color: context.genesisCreateColors.muted,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            int index = 0;
                            index < _summaryLines.length;
                            index++
                          )
                            SizedBox(
                              width: double.infinity,
                              child: Text.rich(
                                TextSpan(
                                  children: _summaryLineSpans(
                                    context,
                                    _summaryLines[index],
                                  ),
                                ),
                                key: ValueKey<String>(
                                  'section-summary-line-$title-$index',
                                ),
                                textAlign: TextAlign.left,
                                maxLines: wrapFirstSummaryLine && index == 0
                                    ? null
                                    : 1,
                                overflow: wrapFirstSummaryLine && index == 0
                                    ? null
                                    : TextOverflow.ellipsis,
                                softWrap: wrapFirstSummaryLine && index == 0,
                                style: TextStyle(
                                  color: createHubStyle
                                      ? GenesisPalette.redesignWhite60
                                      : context.genesisColors.textQuaternary,
                                  fontSize: createHubStyle ? 11 : 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onTap != null && createHubStyle) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    key: ValueKey<String>('section-chevron-$title'),
                    size: 20,
                    color: GenesisPalette.redesignWhite45,
                  ),
                ],
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              thickness: 1,
              color: createHubStyle
                  ? GenesisPalette.redesignWhite14
                  : context.genesisCreateColors.divider,
            ),
        ],
      ),
    );
  }

  List<String> get _summaryLines {
    if (createHubStyle) {
      return <String>[
        summary.split('\n').map((line) => line.trim()).join(' · '),
      ];
    }
    return summary
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  List<InlineSpan> _summaryLineSpans(BuildContext context, String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex < 0) return <InlineSpan>[TextSpan(text: line)];
    return <InlineSpan>[
      TextSpan(
        text: line.substring(0, colonIndex + 1),
        style: TextStyle(color: context.genesisColors.textPlaceholder),
      ),
      TextSpan(text: line.substring(colonIndex + 1)),
    ];
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
