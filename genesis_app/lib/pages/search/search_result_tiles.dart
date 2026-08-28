part of 'search_page.dart';

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final _SearchResultItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUser = item.tab == _SearchTab.user;
    const titleStyle = TextStyle(
      color: Color(0xFF4B6192),
      fontSize: 14,
      height: 1.1,
      fontWeight: FontWeight.w600,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          _ResultThumb(item: item),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    _searchResultTitleSpan(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  SizedBox(height: isUser ? 7 : 5),
                  if (item.tab == _SearchTab.origin)
                    _OriginSearchMetadata(item: item)
                  else if (isUser)
                    Text(
                      'UID: ${formatCopyableIdValue(item.displaySubtitle)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CopyableIdLabel.textStyle,
                    )
                  else
                    Text(
                      item.displaySubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  if (!isUser) ...[
                    const SizedBox(height: 8),
                    _ResultStats(item: item),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _searchMetadataStyle = TextStyle(
  color: Color(0xFF888888),
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.3,
);

const _searchMatchStyle = TextStyle(
  color: GenesisColors.danger,
  fontWeight: FontWeight.w600,
);

class _OriginSearchMetadata extends StatelessWidget {
  const _OriginSearchMetadata({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final origin = item.originV2!;
    final brief = origin.brief.isEmpty ? '-' : origin.brief;
    final briefRanges = origin.brief.isEmpty
        ? const <SearchV2HighlightRange>[]
        : _originRanges(origin, 'brief');
    final showBrief = origin.matches.whereType<SearchV2TextMatch>().any(
      (match) => match.field == 'brief',
    );
    final showCharacters = origin.matches
        .whereType<SearchV2CharacterMatch>()
        .any((match) => match.field == 'character_name');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OID: ${_dashOrValue(origin.originId)}  '
          'Originator: ${formatUidForDisplay(origin.owner.name, fallback: '-')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _searchMetadataStyle,
        ),
        if (showBrief)
          _SearchBriefExcerpt(text: brief, highlightRanges: briefRanges),
        if (showCharacters) _OriginCharactersExcerpt(origin: origin),
        Text(
          'Latest Version: ${_originVersionLabel(origin.originVersion)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _searchMetadataStyle,
        ),
      ],
    );
  }
}

class _OriginCharactersExcerpt extends StatelessWidget {
  const _OriginCharactersExcerpt({required this.origin});

  final SearchV2OriginItem origin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleIndexes = _originCharacterIndexesForWidth(
          context,
          origin: origin,
          maxWidth: constraints.maxWidth,
        );
        return Text.rich(
          _originCharactersSpan(origin, visibleIndexes: visibleIndexes),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: _searchMetadataStyle,
        );
      },
    );
  }
}

List<int> _originCharacterIndexesForWidth(
  BuildContext context, {
  required SearchV2OriginItem origin,
  required double maxWidth,
}) {
  final allIndexes = List<int>.generate(
    origin.characters.length,
    (index) => index,
  );
  if (!maxWidth.isFinite ||
      _originCharactersFit(
        context,
        origin: origin,
        visibleIndexes: allIndexes,
        maxWidth: maxWidth,
      )) {
    return allIndexes;
  }

  final matchedCharacterIds = origin.matches
      .whereType<SearchV2CharacterMatch>()
      .where((match) => match.field == 'character_name')
      .map((match) => match.characterId)
      .toSet();
  final matchedIndexes = allIndexes
      .where(
        (index) =>
            matchedCharacterIds.contains(origin.characters[index].characterId),
      )
      .toList(growable: false);
  final visibleIndexes = <int>[...matchedIndexes];
  if (allIndexes.isNotEmpty && !visibleIndexes.contains(0)) {
    final withFirstName = <int>[0, ...visibleIndexes]..sort();
    if (_originCharactersFit(
      context,
      origin: origin,
      visibleIndexes: withFirstName,
      maxWidth: maxWidth,
    )) {
      visibleIndexes
        ..clear()
        ..addAll(withFirstName);
    }
  }
  final referenceIndexes = matchedIndexes.isEmpty
      ? const <int>[0]
      : matchedIndexes;
  final remainingIndexes =
      allIndexes.where((index) => !visibleIndexes.contains(index)).toList()
        ..sort((left, right) {
          int distanceToMatch(int index) => referenceIndexes
              .map((matchedIndex) => (matchedIndex - index).abs())
              .reduce((a, b) => a < b ? a : b);
          final byDistance = distanceToMatch(
            left,
          ).compareTo(distanceToMatch(right));
          return byDistance != 0 ? byDistance : left.compareTo(right);
        });

  for (final index in remainingIndexes) {
    final candidate = [...visibleIndexes, index]..sort();
    if (!_originCharactersFit(
      context,
      origin: origin,
      visibleIndexes: candidate,
      maxWidth: maxWidth,
    )) {
      continue;
    }
    visibleIndexes
      ..clear()
      ..addAll(candidate);
  }
  visibleIndexes.sort();
  return visibleIndexes;
}

bool _originCharactersFit(
  BuildContext context, {
  required SearchV2OriginItem origin,
  required List<int> visibleIndexes,
  required double maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(
      style: _searchMetadataStyle,
      children: [_originCharactersSpan(origin, visibleIndexes: visibleIndexes)],
    ),
    maxLines: 2,
    ellipsis: '…',
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.localeOf(context),
  )..layout(maxWidth: maxWidth);
  return !painter.didExceedMaxLines;
}

class _SearchBriefExcerpt extends StatelessWidget {
  const _SearchBriefExcerpt({
    required this.text,
    required this.highlightRanges,
  });

  final String text;
  final Iterable<SearchV2HighlightRange> highlightRanges;

  @override
  Widget build(BuildContext context) {
    final ranges = _mergedSearchHighlightRanges(text, highlightRanges);
    return LayoutBuilder(
      builder: (context, constraints) {
        final excerpt = _searchBriefExcerptForWidth(
          context,
          text: text,
          ranges: ranges,
          maxWidth: constraints.maxWidth,
        );
        return Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Brief: '),
              _highlightedSearchSpan(excerpt.text, excerpt.highlightRanges),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: _searchMetadataStyle,
        );
      },
    );
  }
}

_SearchBriefExcerptData _searchBriefExcerptForWidth(
  BuildContext context, {
  required String text,
  required List<_SearchHighlightRange> ranges,
  required double maxWidth,
}) {
  final full = _SearchBriefExcerptData(
    text: text,
    highlightRanges: [
      for (final range in ranges)
        SearchV2HighlightRange(
          start: range.start,
          length: range.end - range.start,
        ),
    ],
  );
  if (!maxWidth.isFinite ||
      ranges.isEmpty ||
      _searchBriefFits(context, excerpt: full, maxWidth: maxWidth)) {
    return full;
  }

  var lowerContextLength = 0;
  var upperContextLength = text.length;
  var best = _buildSearchBriefExcerpt(text, ranges, contextLength: 0);
  while (lowerContextLength <= upperContextLength) {
    final contextLength = (lowerContextLength + upperContextLength) ~/ 2;
    final candidate = _buildSearchBriefExcerpt(
      text,
      ranges,
      contextLength: contextLength,
    );
    if (_searchBriefFits(context, excerpt: candidate, maxWidth: maxWidth)) {
      best = candidate;
      lowerContextLength = contextLength + 1;
    } else {
      upperContextLength = contextLength - 1;
    }
  }
  return best;
}

bool _searchBriefFits(
  BuildContext context, {
  required _SearchBriefExcerptData excerpt,
  required double maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(
      style: _searchMetadataStyle,
      children: [
        const TextSpan(text: 'Brief: '),
        _highlightedSearchSpan(excerpt.text, excerpt.highlightRanges),
      ],
    ),
    maxLines: 2,
    ellipsis: '…',
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.localeOf(context),
  )..layout(maxWidth: maxWidth);
  return !painter.didExceedMaxLines;
}

_SearchBriefExcerptData _buildSearchBriefExcerpt(
  String text,
  List<_SearchHighlightRange> ranges, {
  required int contextLength,
}) {
  final windows = <_SearchHighlightRange>[];
  for (final range in ranges) {
    final expanded = _SearchHighlightRange(
      (range.start - contextLength).clamp(0, text.length).toInt(),
      (range.end + contextLength).clamp(0, text.length).toInt(),
    );
    if (windows.isEmpty || expanded.start > windows.last.end) {
      windows.add(expanded);
      continue;
    }
    final previous = windows.removeLast();
    windows.add(
      _SearchHighlightRange(
        previous.start,
        expanded.end > previous.end ? expanded.end : previous.end,
      ),
    );
  }

  final buffer = StringBuffer();
  final excerptRanges = <SearchV2HighlightRange>[];
  for (var index = 0; index < windows.length; index += 1) {
    final window = windows[index];
    if (index == 0 && window.start > 0) {
      final leadingEnd = _searchBriefLeadingContextEnd(text, window.start);
      buffer.write(text.substring(0, leadingEnd));
      if (leadingEnd < window.start) buffer.write('…');
    } else if (index > 0 && window.start > windows[index - 1].end) {
      buffer.write('…');
    }
    final outputStart = buffer.length;
    buffer.write(text.substring(window.start, window.end));
    for (final range in ranges) {
      final start = range.start > window.start ? range.start : window.start;
      final end = range.end < window.end ? range.end : window.end;
      if (end <= start) continue;
      excerptRanges.add(
        SearchV2HighlightRange(
          start: outputStart + start - window.start,
          length: end - start,
        ),
      );
    }
  }
  if (windows.last.end < text.length) buffer.write('…');
  return _SearchBriefExcerptData(
    text: buffer.toString(),
    highlightRanges: excerptRanges,
  );
}

int _searchBriefLeadingContextEnd(String text, int omittedEnd) {
  const preferredLength = 18;
  if (omittedEnd <= preferredLength) return omittedEnd;
  final boundary = text.lastIndexOf(' ', preferredLength);
  return boundary > 0 ? boundary : preferredLength;
}

class _SearchBriefExcerptData {
  const _SearchBriefExcerptData({
    required this.text,
    required this.highlightRanges,
  });

  final String text;
  final List<SearchV2HighlightRange> highlightRanges;
}

TextSpan _searchResultTitleSpan(_SearchResultItem item) {
  switch (item.tab) {
    case _SearchTab.origin:
      final origin = item.originV2!;
      final rawName = origin.originName;
      if (rawName.trim().isEmpty) {
        return TextSpan(text: item.displayTitle);
      }
      return TextSpan(
        children: [
          if (!rawName.startsWith('#')) const TextSpan(text: '#'),
          _highlightedSearchSpan(rawName, _originRanges(origin, 'origin_name')),
        ],
      );
    case _SearchTab.world:
      final world = item.worldV2!;
      final rawName = world.worldName;
      return _highlightedSearchSpan(
        rawName.trim().isEmpty ? item.displayTitle : rawName,
        world.matches
            .where((match) => match.field == 'world_name')
            .expand((match) => match.highlightRanges),
      );
    case _SearchTab.user:
      final user = item.userV2!;
      final rawName = user.name;
      return _highlightedSearchSpan(
        rawName.trim().isEmpty ? item.displayTitle : rawName,
        user.matches
            .where((match) => match.field == 'user_name')
            .expand((match) => match.highlightRanges),
      );
  }
}

TextSpan _originCharactersSpan(
  SearchV2OriginItem origin, {
  List<int>? visibleIndexes,
}) {
  if (origin.characters.isEmpty) {
    return const TextSpan(text: 'Characters: -');
  }
  final indexes =
      visibleIndexes ??
      List<int>.generate(origin.characters.length, (index) => index);
  final spans = <InlineSpan>[const TextSpan(text: 'Characters: ')];
  if (indexes.isEmpty) {
    spans.add(const TextSpan(text: '…'));
    return TextSpan(children: spans);
  }
  for (var visibleIndex = 0; visibleIndex < indexes.length; visibleIndex += 1) {
    final index = indexes[visibleIndex];
    if (visibleIndex > 0 && index > indexes[visibleIndex - 1] + 1) {
      spans.add(const TextSpan(text: ', …, '));
    } else if (visibleIndex > 0) {
      spans.add(const TextSpan(text: ', '));
    }
    final character = origin.characters[index];
    final name = character.name.isEmpty ? '-' : character.name;
    final ranges = character.name.isEmpty
        ? const <SearchV2HighlightRange>[]
        : origin.matches
              .whereType<SearchV2CharacterMatch>()
              .where((match) => match.characterId == character.characterId)
              .expand((match) => match.highlightRanges);
    spans.add(_highlightedSearchSpan(name, ranges));
  }
  if (indexes.last < origin.characters.length - 1) {
    spans.add(const TextSpan(text: ', …'));
  }
  return TextSpan(children: spans);
}

Iterable<SearchV2HighlightRange> _originRanges(
  SearchV2OriginItem origin,
  String field,
) {
  return origin.matches
      .whereType<SearchV2TextMatch>()
      .where((match) => match.field == field)
      .expand((match) => match.highlightRanges);
}

TextSpan _highlightedSearchSpan(
  String text,
  Iterable<SearchV2HighlightRange> ranges,
) {
  final merged = _mergedSearchHighlightRanges(text, ranges);
  if (merged.isEmpty) return TextSpan(text: text);

  final spans = <InlineSpan>[];
  var offset = 0;
  for (final range in merged) {
    if (range.start > offset) {
      spans.add(TextSpan(text: text.substring(offset, range.start)));
    }
    spans.add(
      TextSpan(
        text: text.substring(range.start, range.end),
        style: _searchMatchStyle,
      ),
    );
    offset = range.end;
  }
  if (offset < text.length) {
    spans.add(TextSpan(text: text.substring(offset)));
  }
  return TextSpan(children: spans);
}

List<_SearchHighlightRange> _mergedSearchHighlightRanges(
  String text,
  Iterable<SearchV2HighlightRange> ranges,
) {
  if (text.isEmpty) return const <_SearchHighlightRange>[];
  final normalized = <_SearchHighlightRange>[];
  for (final range in ranges) {
    if (range.length <= 0 || range.start >= text.length) continue;
    final start = range.start.clamp(0, text.length).toInt();
    final end = (range.start + range.length).clamp(0, text.length).toInt();
    if (end > start) normalized.add(_SearchHighlightRange(start, end));
  }
  normalized.sort((a, b) => a.start.compareTo(b.start));

  final merged = <_SearchHighlightRange>[];
  for (final range in normalized) {
    if (merged.isEmpty || range.start > merged.last.end) {
      merged.add(range);
      continue;
    }
    final previous = merged.removeLast();
    merged.add(
      _SearchHighlightRange(
        previous.start,
        range.end > previous.end ? range.end : previous.end,
      ),
    );
  }
  return merged;
}

class _SearchHighlightRange {
  const _SearchHighlightRange(this.start, this.end);

  final int start;
  final int end;
}

class _ResultThumb extends StatelessWidget {
  const _ResultThumb({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    const userAvatarSize = 60.0;
    const resultCoverWidth = 60.0;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (item.tab == _SearchTab.user) {
      return GenesisAvatar(
        url: item.coverImage,
        name: item.title,
        size: userAvatarSize,
        borderRadius: userAvatarSize / 2,
        maxDevicePixelRatio: devicePixelRatio,
      );
    }
    final imageHeight = item.tab == _SearchTab.origin
        ? resultCoverWidth / genesisOriginCoverAspectRatio
        : resultCoverWidth;
    return GenesisListImage(
      imageUrl: item.coverImage,
      width: resultCoverWidth,
      height: imageHeight,
      maxDevicePixelRatio: devicePixelRatio,
    );
  }
}

class _ResultStats extends StatelessWidget {
  const _ResultStats({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    if (item.tab == _SearchTab.world) {
      return Text(
        formatWorldStatsLabel(
          tickNo: item.tickCount,
          subTickNo: item.subTickNo,
          messageCount: item.connectCount,
          playerCount: item.playerCount,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    final stats = item.tab == _SearchTab.origin
        ? [
            _StatData(iconAsset: copyStatIconAsset, value: item.copyCount),
            _StatData(
              iconAsset: connectStatIconAsset,
              value: item.connectCount,
            ),
            _StatData(
              iconAsset: characterStatIconAsset,
              preserveIconAssetColor: true,
              value: item.characterCount,
            ),
          ]
        : const <_StatData>[];

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final stat in stats)
          StatItem(
            icon: stat.icon,
            iconAsset: stat.iconAsset,
            preserveIconAssetColor: stat.preserveIconAssetColor,
            iconSize: 11,
            iconColor: Colors.black,
            gap: 4,
            text: formatStatCount(stat.value),
            textStyle: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

class _StatData {
  const _StatData({
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
  final int value;
}
