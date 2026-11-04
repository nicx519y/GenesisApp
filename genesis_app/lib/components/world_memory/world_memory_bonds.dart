part of 'world_memory.dart';

class _MemoryBonds extends StatelessWidget {
  const _MemoryBonds({required this.relations});
  final List<WorldMemoryRelation> relations;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final group in WorldMemoryRelationGroup.values) ...[
        _MemoryHeading(
          group == WorldMemoryRelationGroup.towardPlayer
              ? context.l10n.memoryHowTheySeeYou
              : context.l10n.memoryBetweenThem,
          top: 0,
          bottom: 12,
          fontSize: 13,
          lineHeight: 18,
          color: GenesisColors.darkTextPrimary,
        ),
        if (!relations.any((r) => r.group == group))
          Padding(
            padding: EdgeInsets.only(
              bottom: group == WorldMemoryRelationGroup.towardPlayer ? 22 : 0,
            ),
            child: _MemoryBondEmpty(
              text: group == WorldMemoryRelationGroup.towardPlayer
                  ? context.l10n.memoryToYouEmpty
                  : context.l10n.memoryBetweenEmpty,
            ),
          ),
        for (final relation in relations.where((r) => r.group == group))
          _MemoryBondTile(relation: relation),
      ],
    ],
  );
}

class _MemoryBondTile extends StatelessWidget {
  const _MemoryBondTile({required this.relation});
  final WorldMemoryRelation relation;

  @override
  Widget build(BuildContext context) {
    final r = relation;
    final towardPlayer = r.group == WorldMemoryRelationGroup.towardPlayer;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (towardPlayer)
            _MemoryAvatar(r.from, size: 44)
          else
            SizedBox(
              width: 54,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _MemoryAvatar(r.from, size: 32),
                  Positioned(
                    left: 20,
                    top: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: GenesisColors.darkBackground,
                          width: 2,
                        ),
                      ),
                      child: _MemoryAvatar(r.to, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (towardPlayer) ...[
                      _MemoryText(r.from.name, bold: true, lineHeight: 20 / 14),
                      const _MemoryGlyph(
                        _MemoryGlyphs.arrowRight,
                        size: 12,
                        color: GenesisColors.darkTextTertiary,
                      ),
                      _MemoryText(
                        r.to.name,
                        weight: FontWeight.w500,
                        lineHeight: 20 / 14,
                        color: GenesisColors.darkTextSecondary,
                      ),
                    ] else
                      _MemoryText(
                        '${r.from.name} & ${r.to.name}',
                        bold: true,
                        lineHeight: 20 / 14,
                      ),
                    if (r.updated) _MemoryBadge(context.l10n.memoryUpdated),
                  ],
                ),
                const SizedBox(height: 5),
                _MemoryText(
                  r.body,
                  fontSize: 13,
                  color: GenesisColors.darkTextSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryBondEmpty extends StatelessWidget {
  const _MemoryBondEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _MemoryDashedBorder(),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: _MemoryText(text, fontSize: 13, color: const Color(0x8CFFFFFF)),
    ),
  );
}

class _MemoryDashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      );
    final paint = Paint()
      ..color = const Color(0x26FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 9) {
        canvas.drawPath(metric.extractPath(offset, offset + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MemoryDashedBorder oldDelegate) => false;
}
