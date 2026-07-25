part of 'origin_world_page.dart';

class CopyWorldProgressSection extends StatefulWidget {
  const CopyWorldProgressSection({
    super.key,
    required this.originId,
    this.summaries = const <WorldSummaryLatestItem>[],
  });

  final String originId;
  final List<WorldSummaryLatestItem> summaries;

  @override
  State<CopyWorldProgressSection> createState() =>
      _CopyWorldProgressSectionState();
}

class _CopyWorldProgressSectionState extends State<CopyWorldProgressSection> {
  static const _rotationInterval = Duration(seconds: 8);

  Timer? _timer;
  var _visibleIndex = 0;

  @override
  void initState() {
    super.initState();
    _applySummaries(widget.summaries);
  }

  @override
  void didUpdateWidget(covariant CopyWorldProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originId != widget.originId) {
      _hiddenWorldIds.clear();
      _applySummaries(widget.summaries);
      return;
    }
    if (!_sameSummaries(oldWidget.summaries, widget.summaries)) {
      _applySummaries(widget.summaries);
    }
  }

  void _applySummaries(List<WorldSummaryLatestItem> summaries) {
    _timer?.cancel();
    final visible = summaries
        .where((item) => item.summary.trim().isNotEmpty)
        .toList(growable: false);
    setState(() {
      _visibleIndex = 0;
    });
    if (visible.length <= 1) return;
    _timer = Timer.periodic(_rotationInterval, (_) {
      if (!mounted || visible.length <= 1) return;
      setState(() {
        _visibleIndex = (_visibleIndex + 1) % visible.length;
      });
    });
  }

  bool _sameSummaries(
    List<WorldSummaryLatestItem> a,
    List<WorldSummaryLatestItem> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      final left = a[index];
      final right = b[index];
      if (left.worldId != right.worldId ||
          left.tickNo != right.tickNo ||
          left.tickTime != right.tickTime ||
          left.createdAt != right.createdAt ||
          left.summary != right.summary ||
          left.deleted != right.deleted) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _openWorld(WorldSummaryLatestItem item) async {
    final result = await Navigator.of(context).pushNamed<WorldPageResult>(
      RouteNames.world,
      arguments: {'wid': item.worldId},
    );
    if (!mounted || result == null) return;
    final deletedWorldId = result.deletedWorldId.trim();
    if (deletedWorldId.isEmpty) return;
    // The page owns the loaded data. A deleted world is simply hidden for the
    // lifetime of this section instead of causing another network refresh.
    _hiddenWorldIds.add(deletedWorldId);
    setState(() {});
  }

  final _hiddenWorldIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final summaries = widget.summaries
        .where((item) => !_hiddenWorldIds.contains(item.worldId.trim()))
        .where((item) => item.summary.trim().isNotEmpty)
        .toList(growable: false);
    final summaryIndex = _visibleIndex >= summaries.length ? 0 : _visibleIndex;
    final summary = summaries.isEmpty ? null : summaries[summaryIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: MyFlutterApp.lastProgress,
          iconColor: Color(0xFFFF2442),
          title: 'Copy World Progress',
        ),
        const SizedBox(height: 8),
        _CopyWorldProgressCard(summary: summary, onOpen: _openWorld),
      ],
    );
  }
}

class _CopyWorldProgressCard extends StatelessWidget {
  const _CopyWorldProgressCard({required this.summary, required this.onOpen});

  static const double _bodyFontSize = 13;
  static const double _bodyLineHeight = 1.45;
  static const double _bodyHeight = _bodyFontSize * _bodyLineHeight * 5 + 6;
  static const _bodyStrutStyle = StrutStyle(
    fontSize: _bodyFontSize,
    height: _bodyLineHeight,
    forceStrutHeight: true,
  );

  final WorldSummaryLatestItem? summary;
  final ValueChanged<WorldSummaryLatestItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final item = summary;
    final body = item?.summary.trim();
    if (item == null || body == null || body.isEmpty) {
      return const Text(
        'No launched world',
        key: ValueKey('copy-world-progress-empty'),
        style: TextStyle(
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.deleted ? null : () => onOpen(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: const ValueKey('copy-world-progress-body'),
            height: _bodyHeight,
            child: Text(
              body,
              key: ValueKey(item.worldId),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              strutStyle: _bodyStrutStyle,
              style: const TextStyle(
                fontSize: _bodyFontSize,
                height: _bodyLineHeight,
                fontWeight: FontWeight.w400,
                color: Color(0xFF111111),
              ),
            ),
          ),
          const SizedBox(height: 0),
          _CopyWorldProgressMeta(summary: item),
        ],
      ),
    );
  }
}

class _CopyWorldProgressMeta extends StatelessWidget {
  const _CopyWorldProgressMeta({required this.summary});

  final WorldSummaryLatestItem? summary;

  @override
  Widget build(BuildContext context) {
    final item = summary;
    if (item == null) return const SizedBox(height: 18);
    final timestamp = _formatSummaryTimestamp(
      item.tickTime == 0 ? item.createdAt : item.tickTime,
    );
    return LayoutBuilder(
      key: const ValueKey('copy-world-progress-meta'),
      builder: (context, constraints) {
        const gap = 12.0;
        final hasTimestamp = timestamp.isNotEmpty;
        final timeWidth = hasTimestamp
            ? constraints.maxWidth.clamp(0, 96).toDouble()
            : 0.0;
        final leftWidth =
            (constraints.maxWidth - (hasTimestamp ? timeWidth + gap : 0))
                .clamp(0.0, constraints.maxWidth)
                .toDouble();
        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: Row(
                key: const ValueKey('copy-world-progress-left-meta'),
                children: [
                  Flexible(
                    child: Text(
                      'WID: ${deletedAwareIdLabel(item.worldId, deleted: item.deleted)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DiscussStoryBadge(count: item.tickNo),
                ],
              ),
            ),
            if (hasTimestamp) ...[
              const SizedBox(width: gap),
              SizedBox(
                width: timeWidth,
                child: Text(
                  timestamp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8C8C8C),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _formatSummaryTimestamp(int seconds) {
  if (seconds <= 0) return '';
  return formatGenesisTimestamp(seconds);
}
