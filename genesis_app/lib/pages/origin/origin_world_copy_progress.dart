part of 'origin_world_page.dart';

class CopyWorldProgressSection extends StatefulWidget {
  const CopyWorldProgressSection({super.key, required this.originId});

  final String originId;

  @override
  State<CopyWorldProgressSection> createState() =>
      _CopyWorldProgressSectionState();
}

class _CopyWorldProgressSectionState extends State<CopyWorldProgressSection> {
  static const _rotationInterval = Duration(seconds: 8);

  Timer? _timer;
  var _summaries = const <WorldSummaryLatestItem>[];
  var _visibleIndex = 0;
  var _didLoadSummaries = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadSummaries) return;
    _didLoadSummaries = true;
    unawaited(_loadSummaries());
  }

  @override
  void didUpdateWidget(covariant CopyWorldProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originId != widget.originId) {
      _timer?.cancel();
      _summaries = const <WorldSummaryLatestItem>[];
      _visibleIndex = 0;
      unawaited(_loadSummaries());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSummaries() async {
    final originId = widget.originId.trim();
    if (originId.isEmpty) {
      _applySummaries(const <WorldSummaryLatestItem>[]);
      return;
    }
    try {
      final summaries = await AppServicesScope.read(
        context,
      ).api.getLatestWorldSummaries(originId: originId);
      if (!mounted || widget.originId.trim() != originId) return;
      _applySummaries(summaries);
    } catch (_) {
      if (!mounted || widget.originId.trim() != originId) return;
      _applySummaries(const <WorldSummaryLatestItem>[]);
    }
  }

  void _applySummaries(List<WorldSummaryLatestItem> summaries) {
    _timer?.cancel();
    final visible = summaries
        .where((item) => item.summary.trim().isNotEmpty)
        .toList(growable: false);
    setState(() {
      _summaries = visible;
      _visibleIndex = 0;
    });
    if (visible.length <= 1) return;
    _timer = Timer.periodic(_rotationInterval, (_) {
      if (!mounted || _summaries.length <= 1) return;
      setState(() {
        _visibleIndex = (_visibleIndex + 1) % _summaries.length;
      });
    });
  }

  Future<void> _openWorld(WorldSummaryLatestItem item) async {
    final result = await Navigator.of(context).pushNamed<WorldPageResult>(
      RouteNames.world,
      arguments: {'wid': item.worldId},
    );
    if (!mounted || result == null) return;
    final deletedWorldId = result.deletedWorldId.trim();
    if (deletedWorldId.isEmpty) return;
    _applySummaries(
      _summaries
          .where((summary) => summary.worldId.trim() != deletedWorldId)
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryIndex = _visibleIndex >= _summaries.length ? 0 : _visibleIndex;
    final summary = _summaries.isEmpty ? null : _summaries[summaryIndex];

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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topLeft,
                  clipBehavior: Clip.none,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
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
