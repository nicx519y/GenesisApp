part of 'world_memory.dart';

const _memoryRule = Color(0x0DFFFFFF);
const _memoryBarFill = Color(0x14FFFFFF);
const _memoryBarStrongFill = Color(0x1FFFFFFF);

/// Stroke glyphs from the design; Material icons of the same name read heavier
/// at these sizes.
abstract final class _MemoryGlyphs {
  static const lock =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';
  static const chevronDown =
      '<svg viewBox="0 0 16 16" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6l4 4 4-4"/></svg>';
  static const chevronRight =
      '<svg viewBox="0 0 16 16" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4l4 4-4 4"/></svg>';
  static const arrowRight =
      '<svg viewBox="0 0 16 16" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8h10M9 4l4 4-4 4"/></svg>';
  static const clock =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a9 9 0 1 0 0 18 9 9 0 1 0 0-18z"/><path d="M12 7v5l3 2"/></svg>';
  static const message =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7.5 8.25h9m-9 3H12m-9.75 1.51c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.076-4.076a1.526 1.526 0 0 1 1.037-.443 48.282 48.282 0 0 0 5.68-.494c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0 0 12 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018Z"/></svg>';
  static const bonds =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8"><path d="M9 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 1 0 0-11z"/><path d="M15 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 1 0 0-11z"/></svg>';
}

class _MemoryGlyph extends StatelessWidget {
  const _MemoryGlyph(this.svg, {required this.size, required this.color});
  final String svg;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    svg,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class _MemoryText extends StatelessWidget {
  const _MemoryText(
    this.text, {
    this.small = false,
    this.bold = false,
    this.color = GenesisColors.darkTextPrimary,
    this.align,
    this.fontSize,
    this.lineHeight,
    this.weight,
    this.maxLines,
  });
  final String text;
  final bool small;
  final bool bold;
  final Color color;
  final TextAlign? align;
  final double? fontSize;
  final double? lineHeight;
  final FontWeight? weight;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    genesisSafeDisplayText(text, source: 'world_memory'),
    textAlign: align,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: fontSize ?? (small ? 12 : 14),
      height: lineHeight ?? 1.5,
      fontWeight: weight ?? (bold ? FontWeight.w600 : FontWeight.w400),
      letterSpacing: 0,
      color: color,
    ),
  );
}

class _MemoryBadge extends StatelessWidget {
  const _MemoryBadge(
    this.text, {
    this.outlined = false,
    this.accent = false,
    this.compact = false,
  });
  final String text;
  final bool outlined;
  final bool accent;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: compact ? 16 : 18),
    padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: outlined
          ? null
          : accent
          ? const Color(0x1FFF2442)
          : _memoryBarFill,
      border: outlined ? Border.all(color: const Color(0x26FFFFFF)) : null,
    ),
    child: Center(
      widthFactor: 1,
      heightFactor: 1,
      child: _MemoryText(
        text,
        fontSize: compact ? 9 : 10,
        lineHeight: compact ? 12 / 9 : 1.4,
        bold: true,
        color: accent
            ? GenesisColors.redSecondary
            : GenesisColors.darkTextSecondary,
      ),
    ),
  );
}

class _MemoryAvatar extends StatelessWidget {
  const _MemoryAvatar(this.person, {this.size = 48, this.departed = false});
  final WorldMemoryPerson person;
  final double size;
  final bool departed;

  @override
  Widget build(BuildContext context) {
    final avatar = GenesisCharacterAvatar(
      url: person.avatarAsset.isNotEmpty
          ? person.avatarAsset
          : person.avatarUrl,
      name: person.name,
      size: size,
      borderRadius: size >= 96
          ? 20
          : size <= 24
          ? 5
          : 8,
    );
    return ExcludeSemantics(
      child: departed
          ? Opacity(
              opacity: .55,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  .2126,
                  .7152,
                  .0722,
                  0,
                  0,
                  .2126,
                  .7152,
                  .0722,
                  0,
                  0,
                  .2126,
                  .7152,
                  .0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: avatar,
              ),
            )
          : avatar,
    );
  }
}

class _MemoryHeading extends StatelessWidget {
  const _MemoryHeading(
    this.text, {
    this.top = 12,
    this.bottom = 6,
    this.left = 0,
    this.fontSize = 11,
    this.lineHeight = 16,
    this.color = GenesisColors.darkTextTertiary,
  });
  final String text;
  final double top;
  final double bottom;
  final double left;
  final double fontSize;
  final double lineHeight;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: bottom, left: left),
    child: Semantics(
      header: true,
      child: _MemoryText(
        text,
        fontSize: fontSize,
        lineHeight: lineHeight / fontSize,
        bold: true,
        color: color,
      ),
    ),
  );
}

class _MemoryEmpty extends StatelessWidget {
  const _MemoryEmpty({
    required this.title,
    required this.body,
    required this.glyph,
  });
  final String title;
  final String body;
  final String glyph;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 48, 24, 8),
    child: Column(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: GenesisColors.darkCardBackground,
            shape: BoxShape.circle,
          ),
          child: _MemoryGlyph(
            glyph,
            size: 22,
            color: GenesisColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 14),
        _MemoryText(
          title,
          fontSize: 15,
          lineHeight: 20 / 15,
          bold: true,
          align: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (body.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: _MemoryText(
              body,
              fontSize: 13,
              color: GenesisColors.darkTextSecondary,
              align: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}

/// One placeholder line. A [width] of 1 or less is a share of the row, above
/// that it is logical pixels.
class _MemoryBar extends StatelessWidget {
  const _MemoryBar(this.width, {this.strong = false});
  final double width;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      height: 10,
      width: width > 1 ? width : null,
      decoration: BoxDecoration(
        color: strong ? _memoryBarStrongFill : _memoryBarFill,
        borderRadius: BorderRadius.circular(5),
      ),
    );
    return ExcludeSemantics(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: width > 1
            ? bar
            : FractionallySizedBox(widthFactor: width, child: bar),
      ),
    );
  }
}

class _MemoryBars extends StatelessWidget {
  const _MemoryBars(this.widths, {this.gap = 9});
  final List<double> widths;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < widths.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        _MemoryBar(widths[i]),
      ],
    ],
  );
}

/// What a locked section shows: its structure, with only names and avatars of
/// Cast filled in. Everything else stays a placeholder, never hidden content.
class _MemoryLockedStructure extends StatelessWidget {
  const _MemoryLockedStructure({
    required this.section,
    required this.timeline,
    required this.snapshot,
    this.phone = false,
  });
  final WorldMemorySection section;
  final bool timeline;
  final WorldMemorySnapshot snapshot;
  final bool phone;

  static const _railWidths = [.78, .64, .86, .52];
  static const _summaryBars = [
    [1.0, .96, .62],
    [1.0, .92, .98, .44],
    [1.0, .88, .54],
  ];
  static const _castWidths = [
    (.62, .78),
    (.70, .56),
    (.54, .72),
    (.66, .48),
    (.58, .64),
  ];
  static const _bondWidths = [.72, .58, .66];

  Widget _railRow(
    List<double> bars, {
    required bool first,
    required bool last,
    double labelWidth = 92,
    bool avatars = true,
  }) => Stack(
    children: [
      if (!first)
        Positioned(
          top: 0,
          height: 10,
          left: 7.5,
          child: Container(width: 1, color: _memoryBarFill),
        ),
      if (!last)
        Positioned(
          top: 10,
          bottom: 0,
          left: 7.5,
          child: Container(width: 1, color: _memoryBarFill),
        ),
      Positioned(
        top: 6.5,
        left: 4.5,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x33FFFFFF),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(left: 26, top: 5, bottom: last ? 0 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MemoryBar(labelWidth, strong: true),
            const SizedBox(height: 9),
            _MemoryBars(bars),
            if (avatars) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _memoryBarFill,
                        borderRadius: BorderRadius.circular(5),
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

  Widget _castRow(
    BuildContext context,
    WorldMemoryCharacter? character,
    int index,
  ) {
    final widths = _castWidths[index % _castWidths.length];
    final name = character?.person.name ?? '';
    final activity = character?.isPlayer ?? false
        ? context.l10n.memoryRecent
        : context.l10n.memoryNow;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _memoryRule)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: !phone && index == 0 ? 0 : (phone ? 10 : 12),
          bottom: phone ? 10 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (character == null)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _memoryBarFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                else
                  Opacity(opacity: .7, child: _MemoryAvatar(character.person)),
                SizedBox(width: phone ? 13 : 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (name.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: _MemoryBar(120, strong: true),
                          )
                        else
                          _MemoryText(
                            name,
                            bold: true,
                            lineHeight: 20 / 14,
                            maxLines: 1,
                          ),
                        const SizedBox(height: 8),
                        _MemoryBar(widths.$1),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, box) => Row(
                            children: [
                              _MemoryText(
                                '$activity ·',
                                small: true,
                                lineHeight: 1,
                                color: const Color(0x59FFFFFF),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  width: box.maxWidth * widths.$2,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _memoryBarFill,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 3),
                  child: _MemoryGlyph(
                    _MemoryGlyphs.lock,
                    size: 14,
                    color: Color(0x59FFFFFF),
                  ),
                ),
              ],
            ),
            // World shows one profile opened, so the form's shape is visible.
            if (!phone && index == 0) ...[
              const SizedBox(height: 12),
              _form(context.l10n.memoryBasics, [
                (context.l10n.memoryAge, const [32.0]),
                (context.l10n.memoryGender, const [48.0]),
                (context.l10n.memoryOrientation, const [56.0]),
                (context.l10n.memoryAppearance, const [1.0, .6]),
              ]),
              const SizedBox(height: 12),
              _form(context.l10n.memoryAbout, [
                (context.l10n.memoryPersonality, const [.84]),
                (context.l10n.memoryBackground, const [1.0, .52]),
                (context.l10n.memoryLikesDislikes, const [.72]),
                (context.l10n.memoryBoundaries, const [.78]),
                (context.l10n.memoryGoodToKnow, const [.56]),
              ]),
              const SizedBox(height: 12),
              _form(context.l10n.memoryStory, [
                (context.l10n.memoryArc, const [.8]),
                (context.l10n.memoryDefiningMoment, const [1.0, .4]),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _form(String title, List<(String, List<double>)> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _MemoryHeading(title, top: 0, left: 2),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: GenesisColors.darkRaisedBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : const Border(top: BorderSide(color: _memoryRule)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 104,
                          child: _MemoryText(
                            rows[i].$1,
                            small: true,
                            lineHeight: 20 / 12,
                            weight: FontWeight.w500,
                            color: const Color(0x8CFFFFFF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: _MemoryBars(rows[i].$2, gap: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _bondHeading(String title, int count, {double top = 0}) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: _MemoryText(
            title,
            fontSize: 13,
            lineHeight: 18 / 13,
            bold: true,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          _MemoryText(
            '$count',
            small: true,
            color: GenesisColors.darkTextTertiary,
          ),
        ],
      ],
    ),
  );

  Widget _bondRow(double width, {required bool pair}) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.only(bottom: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _memoryRule)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pair)
          SizedBox(
            width: 54,
            height: 40,
            child: Stack(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _memoryBarFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2E),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: GenesisColors.darkBackground,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _memoryBarFill,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MemoryBar(pair ? 140 : 120, strong: true),
                const SizedBox(height: 9),
                const _MemoryBar(1),
                const SizedBox(height: 9),
                _MemoryBar(width),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cast = snapshot.cast.where((c) => !c.hasLeft).toList();
    int relations(WorldMemoryRelationGroup group) =>
        snapshot.relations.where((r) => r.group == group).length;
    return Semantics(
      label: l10n.memoryLocked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (section) {
          WorldMemorySection.recap =>
            timeline
                ? [
                    if (!phone && snapshot.events.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _MemoryText(
                          l10n.memoryKeyEventsSoFar(
                            count: snapshot.events.length,
                          ),
                          small: true,
                          lineHeight: 16 / 12,
                          color: GenesisColors.darkTextTertiary,
                        ),
                      ),
                    for (var i = 0; i < _railWidths.length; i++)
                      _railRow(
                        [1, _railWidths[i]],
                        first: i == 0,
                        last: i == _railWidths.length - 1,
                      ),
                  ]
                : [
                    for (var i = 0; i < _summaryBars.length; i++)
                      _railRow(
                        _summaryBars[i],
                        first: i == 0,
                        last: i == _summaryBars.length - 1,
                        labelWidth: 56,
                        avatars: false,
                      ),
                  ],
          WorldMemorySection.cast => [
            if (cast.isEmpty)
              for (var i = 0; i < _castWidths.length; i++)
                _castRow(context, null, i)
            else
              for (var i = 0; i < cast.length; i++)
                _castRow(context, cast[i], i),
          ],
          WorldMemorySection.bonds => [
            _bondHeading(
              l10n.memoryHowTheySeeYou,
              relations(WorldMemoryRelationGroup.towardPlayer),
            ),
            for (final width in _bondWidths) _bondRow(width, pair: false),
            _bondHeading(
              l10n.memoryBetweenThem,
              relations(WorldMemoryRelationGroup.betweenCharacters),
            ),
            for (final width in _bondWidths) _bondRow(width, pair: true),
          ],
        },
      ),
    );
  }
}
