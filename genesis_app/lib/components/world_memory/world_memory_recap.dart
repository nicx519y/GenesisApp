part of 'world_memory.dart';

class _MemoryRecapTabs extends StatelessWidget {
  const _MemoryRecapTabs({
    required this.timeline,
    required this.premium,
    required this.deluxe,
    required this.onChanged,
  });
  final bool timeline;
  final bool premium;
  final bool deluxe;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: GenesisColors.darkCardBackground,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        _tab(context, true, context.l10n.memoryTimeline, !deluxe),
        const SizedBox(width: 3),
        _tab(context, false, context.l10n.memorySummary, !premium),
      ],
    ),
  );

  Widget _tab(BuildContext context, bool value, String label, bool locked) =>
      Expanded(
        child: Semantics(
          selected: timeline == value,
          button: true,
          child: Material(
            color: timeline == value
                ? GenesisColors.darkFaintFill
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              key: ValueKey('memory-tab-${value ? 'timeline' : 'summary'}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _MemoryText(
                          label,
                          fontSize: 13,
                          lineHeight: 20 / 13,
                          bold: true,
                          color: timeline == value
                              ? GenesisColors.darkTextPrimary
                              : GenesisColors.darkTextSecondary,
                          align: TextAlign.center,
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Semantics(
                          label: context.l10n.memoryLocked,
                          child: const _MemoryGlyph(
                            _MemoryGlyphs.lock,
                            size: 12,
                            color: Color(0x8CFFFFFF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _MemorySummary extends StatelessWidget {
  const _MemorySummary({required this.ticks});
  final List<WorldMemorySummaryTick> ticks;
  @override
  Widget build(BuildContext context) => ticks.isEmpty
      ? _MemoryText(
          context.l10n.recapEmpty,
          color: GenesisColors.darkTextSecondary,
          align: TextAlign.center,
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, tick) in ticks.indexed)
              WorldMemoryTickTile(
                tickNo: tick.tickNo,
                bodies: tick.bodies,
                isFirst: index == 0,
                isLast: index == ticks.length - 1,
              ),
          ],
        );
}

class _MemoryTimeline extends StatelessWidget {
  const _MemoryTimeline({required this.events});
  final List<WorldMemoryEvent> events;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _MemoryEmpty(
        title: context.l10n.memoryTimelineEmptyTitle,
        body: context.l10n.memoryTimelineEmptyBody,
        glyph: _MemoryGlyphs.clock,
      );
    }
    // Reads down to the latest. Only the ten most recent are kept.
    final sorted = events.indexed.toList()
      ..sort((a, b) {
        final order = a.$2.order.compareTo(b.$2.order);
        return order == 0 ? a.$1.compareTo(b.$1) : order;
      });
    final visible = sorted
        .skip(sorted.length > 10 ? sorted.length - 10 : 0)
        .map((e) => e.$2)
        .toList();
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++)
          _MemoryEventTile(
            event: visible[i],
            first: i == 0,
            last: i == visible.length - 1,
          ),
      ],
    );
  }
}

class _MemoryEventTile extends StatelessWidget {
  const _MemoryEventTile({
    required this.event,
    required this.first,
    required this.last,
  });
  final WorldMemoryEvent event;
  final bool first;
  final bool last;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (!first)
        Positioned(
          top: 0,
          height: 10,
          left: 7.5,
          child: Container(width: 1, color: GenesisColors.darkFaintFill),
        ),
      if (!last)
        Positioned(
          top: 10,
          bottom: 0,
          left: 7.5,
          child: Container(width: 1, color: GenesisColors.darkFaintFill),
        ),
      Positioned(
        top: 6.5,
        left: 4.5,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: last
                ? GenesisColors.redPrimary
                : GenesisColors.darkTextTertiary,
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: 26, bottom: last ? 0 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MemoryText(
                  event.timeLabel,
                  fontSize: 13,
                  lineHeight: 20 / 13,
                  bold: true,
                ),
                if (event.change != WorldMemoryChange.none)
                  _MemoryBadge(
                    event.change == WorldMemoryChange.added
                        ? context.l10n.memoryNew
                        : context.l10n.memoryUpdated,
                    accent: event.change == WorldMemoryChange.added,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _MemoryText(event.body, color: GenesisColors.darkTextSecondary),
            if (event.participants.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final person in event.participants)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _MemoryAvatar(person, size: 20),
                    ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _MemoryText(
                      event.participants.map((p) => p.name).join(', '),
                      fontSize: 11,
                      color: GenesisColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
