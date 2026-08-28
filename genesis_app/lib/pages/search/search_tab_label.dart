part of 'search_page.dart';

class _SearchTabLabel extends StatelessWidget {
  const _SearchTabLabel({super.key, required this.tab, required this.total});

  final _SearchTab tab;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final labelStyle = DefaultTextStyle.of(context).style;
    final countStyle = labelStyle.copyWith(fontWeight: FontWeight.w400);
    final labelMetrics = _measureText(context, tab.label, labelStyle);
    final countText = switch (total) {
      null => null,
      final value when value > 99 => '99+',
      final value => '$value',
    };
    final countMetrics = countText == null
        ? null
        : _measureText(context, countText, countStyle);

    return SizedBox(
      width: labelMetrics.size.width,
      height: labelMetrics.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Text(tab.label, maxLines: 1)),
          if (countText != null && countMetrics != null)
            Positioned(
              left: labelMetrics.size.width + 4,
              top: labelMetrics.baseline - countMetrics.baseline,
              child: KeyedSubtree(
                key: ValueKey<String>('search-tab-count-${tab.name}'),
                child: Text(countText, maxLines: 1, style: countStyle),
              ),
            ),
        ],
      ),
    );
  }

  _SearchTabTextMetrics _measureText(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return _SearchTabTextMetrics(
      size: painter.size,
      baseline: painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      ),
    );
  }
}

class _SearchTabTextMetrics {
  const _SearchTabTextMetrics({required this.size, required this.baseline});

  final Size size;
  final double baseline;
}
