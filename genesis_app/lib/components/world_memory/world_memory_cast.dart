part of 'world_memory.dart';

String _statusLabel(BuildContext context, WorldMemoryCharacterStatus status) =>
    status == WorldMemoryCharacterStatus.dead
    ? context.l10n.memoryDeceased
    : context.l10n.memoryLeft;

/// The profile spells out what the list's short status tag abbreviates.
String _statusText(BuildContext context, WorldMemoryCharacterStatus status) =>
    status == WorldMemoryCharacterStatus.dead
    ? context.l10n.memoryDeceased
    : context.l10n.memoryLeftTheStory;

String _activityLabel(BuildContext context, WorldMemoryCharacter character) =>
    character.hasLeft
    ? context.l10n.memoryLastSeen
    : character.isPlayer
    ? context.l10n.memoryRecent
    : context.l10n.memoryNow;

class _MemoryCast extends StatelessWidget {
  const _MemoryCast({
    required this.snapshot,
    required this.phone,
    required this.expandedIds,
    required this.onToggle,
  });
  final WorldMemorySnapshot snapshot;
  final bool phone;
  final Set<String> expandedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final active = snapshot.cast.where((c) => !c.hasLeft).toList();
    final gone = snapshot.cast.where((c) => c.hasLeft).toList();
    final players = active.where((c) => c.isPlayer).toList();
    final others = active.where((c) => !c.isPlayer).toList();
    Widget row(WorldMemoryCharacter c) => _MemoryCharacterTile(
      character: c,
      expanded: !phone && expandedIds.contains(c.person.id),
      phone: phone,
      // Nothing above the first World row, so it starts at the shared gap.
      flushTop:
          !phone &&
          snapshot.hasStoryMemory &&
          active.isNotEmpty &&
          identical(c, active.first),
      onTap: () => onToggle(c.person.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!snapshot.hasStoryMemory)
          Container(
            margin: EdgeInsets.only(bottom: phone ? 14 : 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _MemoryText(
              context.l10n.memoryCastSetupNote,
              small: true,
              color: GenesisColors.darkTextSecondary,
            ),
          ),
        if (snapshot.cast.isEmpty)
          _MemoryEmpty(
            title: context.l10n.memoryCastEmpty,
            body: '',
            glyph: _MemoryGlyphs.clock,
          ),
        if (phone) ...[
          if (players.isNotEmpty)
            _MemoryHeading(
              context.l10n.memoryYou,
              top: 0,
              bottom: 2,
              fontSize: 12,
            ),
          ...players.map(row),
          if (others.isNotEmpty)
            _MemoryHeading(
              '${context.l10n.memoryCharacters} · ${others.length}',
              top: 10,
              bottom: 2,
              fontSize: 12,
            ),
          ...others.map(row),
        ] else
          ...active.map(row),
        if (gone.isNotEmpty) ...[
          _MemoryHeading(
            '${context.l10n.memoryLeftTheStory} · ${gone.length}',
            top: phone ? 10 : 20,
            bottom: 2,
            fontSize: 12,
          ),
          ...gone.map(row),
        ],
      ],
    );
  }
}

class _MemoryCharacterTile extends StatelessWidget {
  const _MemoryCharacterTile({
    required this.character,
    required this.expanded,
    required this.phone,
    required this.onTap,
    this.flushTop = false,
  });
  final WorldMemoryCharacter character;
  final bool expanded;
  final bool phone;
  final VoidCallback onTap;
  final bool flushTop;

  @override
  Widget build(BuildContext context) {
    final c = character;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: phone ? null : expanded,
            child: InkWell(
              key: ValueKey('memory-character-${c.person.id}'),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.only(
                  top: flushTop ? 0 : (phone ? 10 : 12),
                  bottom: phone ? 10 : 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MemoryAvatar(c.person, departed: c.hasLeft),
                    SizedBox(width: phone ? 13 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _MemoryText(
                                c.person.name,
                                bold: true,
                                lineHeight: 20 / 14,
                                color: c.hasLeft
                                    ? GenesisColors.darkTextSecondary
                                    : GenesisColors.darkTextPrimary,
                              ),
                              if (c.isPlayer && !phone)
                                _MemoryBadge(
                                  context.l10n.memoryYou,
                                  accent: true,
                                ),
                              if (c.hasLeft)
                                _MemoryBadge(
                                  _statusLabel(context, c.status),
                                  outlined: true,
                                ),
                              if (c.updated)
                                _MemoryBadge(context.l10n.memoryUpdated),
                            ],
                          ),
                          if (c.identity.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: _MemoryText(
                                c.identity,
                                small: true,
                                lineHeight: 17 / 12,
                                maxLines: 1,
                                color: GenesisColors.darkTextSecondary,
                              ),
                            ),
                          if (c.now.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${_activityLabel(context, c)} · ',
                                      style: const TextStyle(
                                        color: GenesisColors.darkTextTertiary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: genesisSafeDisplayText(
                                        c.now,
                                        source: 'world_memory',
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: phone ? 1 : null,
                                overflow: phone
                                    ? TextOverflow.ellipsis
                                    : TextOverflow.clip,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 17 / 12,
                                  color: Color(0xD9FFFFFF),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: EdgeInsets.only(top: phone ? 4 : 2),
                      child: phone
                          ? const _MemoryGlyph(
                              _MemoryGlyphs.chevronRight,
                              size: 14,
                              color: Color(0x59FFFFFF),
                            )
                          : RotatedBox(
                              quarterTurns: expanded ? 2 : 0,
                              child: const _MemoryGlyph(
                                _MemoryGlyphs.chevronDown,
                                size: 16,
                                color: GenesisColors.darkTextTertiary,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MemoryProfileForm(character: c, firstGap: 0),
            ),
        ],
      ),
    );
  }
}

/// Separate phone detail body; the outer MiniPhone host retains its own close
/// control. The inner back action returns only to the Cast list.
class _MemoryPhoneProfile extends StatelessWidget {
  const _MemoryPhoneProfile({
    required this.character,
    required this.relations,
    required this.onBack,
    required this.onMessage,
    required this.onBonds,
    this.showBack = true,
  });
  final WorldMemoryCharacter character;
  final List<WorldMemoryRelation> relations;
  final VoidCallback onBack;
  final VoidCallback onMessage;
  final VoidCallback onBonds;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final relation = relations
        .where(
          (r) =>
              r.group == WorldMemoryRelationGroup.towardPlayer &&
              r.from.id == c.person.id,
        )
        .firstOrNull;
    final towardYou = c.towardYou.trim().isNotEmpty
        ? c.towardYou
        : relation?.body ?? '';
    return Column(
      key: const ValueKey('memory-phone-profile'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBack)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkWell(
              key: const ValueKey('memory-profile-back'),
              onTap: onBack,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: GenesisColors.darkTextPrimary,
                    ),
                    const SizedBox(width: 6),
                    _MemoryText(context.l10n.memoryCast, bold: true),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(height: showBack ? 8 : 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _MemoryAvatar(c.person, size: 96, departed: c.hasLeft),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              genesisSafeDisplayText(c.person.name, source: 'world_memory'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: GenesisColors.darkTextPrimary,
              ),
            ),
            if (c.identity.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  genesisSafeDisplayText(c.identity, source: 'world_memory'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    letterSpacing: 0,
                    color: GenesisColors.darkTextSecondary,
                  ),
                ),
              ),
            if (c.hasLeft)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x26FFFFFF)),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: _MemoryText(
                        _statusText(context, c.status),
                        fontSize: 11,
                        lineHeight: 1,
                        bold: true,
                        color: GenesisColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: onMessage,
                icon: const _MemoryGlyph(
                  _MemoryGlyphs.message,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(context.l10n.meMessage),
                style: TextButton.styleFrom(
                  backgroundColor: GenesisColors.redPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: GenesisTypography.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBonds,
                icon: const _MemoryGlyph(
                  _MemoryGlyphs.bonds,
                  size: 16,
                  color: Color(0xD9FFFFFF),
                ),
                label: Text(context.l10n.memoryBonds),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xD9FFFFFF),
                  side: const BorderSide(color: Color(0x22FFFFFF)),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: GenesisTypography.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (c.now.trim().isNotEmpty || towardYou.trim().isNotEmpty) ...[
          _MemoryHeading(
            c.hasLeft
                ? context.l10n.memoryLastSeen
                : context.l10n.memoryRightNow,
            left: 2,
          ),
          _MemoryFormGroup(
            rows: [
              if (c.now.trim().isNotEmpty)
                _ProfileRow(
                  _activityLabel(context, c),
                  c.now,
                  updated: c.updated,
                  strong: true,
                ),
              if (towardYou.trim().isNotEmpty)
                _ProfileRow(
                  context.l10n.memoryTowardYou,
                  towardYou,
                  updated: relation?.updated ?? false,
                  strong: true,
                ),
            ],
          ),
        ],
        _MemoryProfileForm(character: c),
      ],
    );
  }
}

class _ProfileRow {
  const _ProfileRow(
    this.label,
    this.value, {
    this.updated = false,
    this.accent = false,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool updated;
  final bool accent;

  /// What is true right now reads brighter than the settled profile below it.
  final bool strong;
}

class _MemoryProfileForm extends StatelessWidget {
  const _MemoryProfileForm({required this.character, this.firstGap = 12});
  final WorldMemoryCharacter character;
  final double firstGap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = {
      WorldMemoryField.age: l.memoryAge,
      WorldMemoryField.gender: l.memoryGender,
      WorldMemoryField.orientation: l.memoryOrientation,
      WorldMemoryField.appearance: l.memoryAppearance,
      WorldMemoryField.personality: l.memoryPersonality,
      WorldMemoryField.background: l.memoryBackground,
      WorldMemoryField.likesDislikes: l.memoryLikesDislikes,
      WorldMemoryField.boundaries: l.memoryBoundaries,
      WorldMemoryField.goodToKnow: l.memoryGoodToKnow,
      WorldMemoryField.arc: l.memoryArc,
      WorldMemoryField.definingMoment: l.memoryDefiningMoment,
    };
    List<_ProfileRow> rows(List<WorldMemoryField> fields) => [
      for (final field in fields)
        if (character.fields[field]?.text.trim().isNotEmpty ?? false)
          _ProfileRow(
            labels[field]!,
            character.fields[field]!.text,
            updated: character.fields[field]!.updated,
            accent: field == WorldMemoryField.definingMoment,
          ),
    ];
    final groups = <(String, List<_ProfileRow>)>[
      (
        l.memoryBasics,
        [
          if (character.hasLeft)
            _ProfileRow(l.memoryStatus, _statusText(context, character.status)),
          ...rows([
            WorldMemoryField.age,
            WorldMemoryField.gender,
            WorldMemoryField.orientation,
            WorldMemoryField.appearance,
          ]),
        ],
      ),
      (
        l.memoryAbout,
        rows([
          WorldMemoryField.personality,
          WorldMemoryField.background,
          WorldMemoryField.likesDislikes,
          WorldMemoryField.boundaries,
          WorldMemoryField.goodToKnow,
        ]),
      ),
      (
        l.memoryStory,
        rows([WorldMemoryField.arc, WorldMemoryField.definingMoment]),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups.where((g) => g.$2.isNotEmpty).indexed) ...[
          _MemoryHeading(
            group.$2.$1,
            top: group.$1 == 0 ? firstGap : 12,
            left: 2,
          ),
          _MemoryFormGroup(rows: group.$2.$2),
        ],
      ],
    );
  }
}

class _MemoryFormGroup extends StatelessWidget {
  const _MemoryFormGroup({required this.rows});
  final List<_ProfileRow> rows;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GenesisColors.darkRaisedBackground,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(top: BorderSide(color: Color(0x0DFFFFFF))),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final row = rows[i];
                  final label = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MemoryText(
                        row.label,
                        small: true,
                        color: const Color(0x8CFFFFFF),
                        lineHeight: 20 / 12,
                        weight: FontWeight.w500,
                      ),
                      if (row.updated)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _MemoryBadge(
                            context.l10n.memoryUpdated,
                            compact: true,
                          ),
                        ),
                    ],
                  );
                  final value = _MemoryText(
                    row.value,
                    fontSize: 13,
                    lineHeight: 20 / 13,
                    color: row.accent
                        ? GenesisColors.redSecondary
                        : row.strong
                        ? GenesisColors.darkTextPrimary
                        : const Color(0xD9FFFFFF),
                  );
                  if (constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [label, const SizedBox(height: 6), value],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 104, child: label),
                      const SizedBox(width: 12),
                      Expanded(child: value),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    ),
  );
}
