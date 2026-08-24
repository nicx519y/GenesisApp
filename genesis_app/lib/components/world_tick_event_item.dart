import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../icons/custom_icon_assets.dart';
import '../ui/components/genesis_soft_italic_text.dart';
import '../ui/theme/genesis_semantic_colors.dart';
import '../utils/genesis_timestamp_formatter.dart';
import 'world/genesis_world_theme.dart';

class WorldTickEventItem extends StatelessWidget {
  const WorldTickEventItem({
    super.key,
    required this.tick,
    required this.tickNumber,
    this.subTickNumber = 0,
    required this.fallbackBody,
    this.locationsById = const <String, Map<String, dynamic>>{},
    this.charactersById = const <String, Map<String, dynamic>>{},
    this.isLast = true,
    this.dateLabel,
    this.timeAgoLabel,
    this.stackedContent = false,
    this.contentTextStyle,
    this.contentLabelStyle,
    this.contentTimestampStyle,
    this.metricUnit = '',
    this.showParagraphClue = false,
    this.timelineStyle = false,
  });

  final Map<String, dynamic> tick;
  final int tickNumber;
  final int subTickNumber;
  final String fallbackBody;
  final Map<String, Map<String, dynamic>> locationsById;
  final Map<String, Map<String, dynamic>> charactersById;
  final bool isLast;
  final String? dateLabel;
  final String? timeAgoLabel;
  final bool stackedContent;
  final TextStyle? contentTextStyle;
  final TextStyle? contentLabelStyle;
  final TextStyle? contentTimestampStyle;
  final String metricUnit;
  final bool showParagraphClue;
  final bool timelineStyle;

  @override
  Widget build(BuildContext context) {
    final tickResult = _tickResult(tick);
    final createdAt = _tickDateTime(tick['created_at']);
    final date = dateLabel ?? formatGenesisDateTime(createdAt);
    final timeAgo = timeAgoLabel ?? '';
    final body = _mapString(tickResult, const [
      'narrator',
    ], fallback: fallbackBody);
    final paragraphs = _tickParagraphs(tickResult);

    if (timelineStyle) {
      return _WorldTimelineTickItem(
        tickNumber: tickNumber,
        subTickNumber: subTickNumber,
        date: date,
        body: body,
        paragraphs: paragraphs,
        locationsById: locationsById,
        charactersById: charactersById,
        metricUnit: metricUnit,
        showParagraphClue: showParagraphClue,
        isLast: isLast,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TickHeader(
            tickNumber: tickNumber,
            subTickNumber: subTickNumber,
            date: date,
            timeAgo: timeAgo,
          ),
          SizedBox(height: 6),
          _GlobalEventCard(
            body: body,
            stacked: stackedContent,
            labelStyle: contentLabelStyle,
            bodyStyle: contentTextStyle,
          ),
          SizedBox(height: 6),
          for (final paragraph in paragraphs) ...[
            _TickParagraphRow(
              paragraph: paragraph,
              locationsById: locationsById,
              charactersById: charactersById,
              stacked: stackedContent,
              labelStyle: contentLabelStyle,
              bodyStyle: contentTextStyle,
              timestampStyle: contentTimestampStyle,
              metricUnit: metricUnit,
              showClue: showParagraphClue,
            ),
            SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _WorldTimelineTickItem extends StatelessWidget {
  const _WorldTimelineTickItem({
    required this.tickNumber,
    required this.subTickNumber,
    required this.date,
    required this.body,
    required this.paragraphs,
    required this.locationsById,
    required this.charactersById,
    required this.metricUnit,
    required this.showParagraphClue,
    required this.isLast,
  });

  final int tickNumber;
  final int subTickNumber;
  final String date;
  final String body;
  final List<Map<String, dynamic>> paragraphs;
  final Map<String, Map<String, dynamic>> locationsById;
  final Map<String, Map<String, dynamic>> charactersById;
  final String metricUnit;
  final bool showParagraphClue;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 30),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: context.genesisColors.surfaceTag,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              'Tick $tickNumber${subTickNumber > 0 ? '-$subTickNumber' : ''}'
              '${date.isEmpty ? '' : ' · $date'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.genesisColors.textPrimary,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _WorldTimelineEventRow(
            label: 'Global',
            body: body,
            timestamp: '',
            isGlobal: true,
            drawLine: paragraphs.isNotEmpty,
          ),
          for (var index = 0; index < paragraphs.length; index++)
            _WorldTimelineParagraphRow(
              paragraph: paragraphs[index],
              locationsById: locationsById,
              charactersById: charactersById,
              metricUnit: metricUnit,
              showClue: showParagraphClue,
              drawLine: index < paragraphs.length - 1,
            ),
        ],
      ),
    );
  }
}

class _WorldTimelineEventRow extends StatelessWidget {
  const _WorldTimelineEventRow({
    required this.label,
    required this.body,
    required this.timestamp,
    required this.isGlobal,
    required this.drawLine,
    this.metadata,
    this.clue,
    this.characterDetails,
  });

  final String label;
  final String body;
  final String timestamp;
  final bool isGlobal;
  final bool drawLine;
  final Widget? metadata;
  final String? clue;
  final Widget? characterDetails;

  @override
  Widget build(BuildContext context) {
    final accent = isGlobal
        ? context.genesisColors.accentText
        : context.genesisColors.textPrimary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 12,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    isGlobal ? Icons.adjust_rounded : Icons.place_outlined,
                    size: isGlobal ? 12 : 13,
                    color: accent,
                  ),
                ),
                if (drawLine) ...[
                  const SizedBox(height: 5),
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: isGlobal
                          ? context.genesisColors.accentText
                          : context.genesisColors.dividerAction,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (timestamp.isNotEmpty)
                        Text(
                          timestamp,
                          style: TextStyle(
                            color: context.genesisColors.textBody,
                            fontSize: 9.5,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (metadata != null) ...[
                    const SizedBox(height: 8),
                    metadata!,
                  ],
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(
                      color: context.genesisColors.textBody,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if ((clue ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ClueText(
                      text: clue!,
                      style: TextStyle(
                        color: context.genesisColors.textMuted,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (characterDetails != null) ...[
                    const SizedBox(height: 6),
                    characterDetails!,
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

class _WorldTimelineParagraphRow extends StatelessWidget {
  const _WorldTimelineParagraphRow({
    required this.paragraph,
    required this.locationsById,
    required this.charactersById,
    required this.metricUnit,
    required this.showClue,
    required this.drawLine,
  });

  final Map<String, dynamic> paragraph;
  final Map<String, Map<String, dynamic>> locationsById;
  final Map<String, Map<String, dynamic>> charactersById;
  final String metricUnit;
  final bool showClue;
  final bool drawLine;

  @override
  Widget build(BuildContext context) {
    final locationId = _mapString(paragraph, const ['location_id']);
    final mappedName = _locationName(locationId, locationsById);
    final label = mappedName.isEmpty
        ? _mapString(paragraph, const ['label'], fallback: locationId)
        : mappedName;
    final body = _mapString(paragraph, const [
      'text',
    ], fallback: _mapString(paragraph, const ['content', 'summary']));
    final timestamp = _mapString(paragraph, const [
      'timestamp',
      'timesamp',
      'time',
    ]);
    final visibleRoles = _visibleRoles(paragraph, charactersById);
    final details = _characterDetails(paragraph, metricUnit: metricUnit);
    final detailStyle = TextStyle(
      color: context.genesisColors.textPrimary,
      fontSize: 13,
      height: 1.5,
    );
    return _WorldTimelineEventRow(
      label: label.isEmpty ? 'Location' : label,
      body: body,
      timestamp: timestamp,
      isGlobal: false,
      drawLine: drawLine,
      metadata: visibleRoles.isEmpty
          ? null
          : _EventMetadata(
              timestamp: null,
              visibleRoles: visibleRoles,
              style: TextStyle(
                color: context.genesisColors.textSecondary,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
      clue: showClue ? _mapString(paragraph, const ['clue']) : null,
      characterDetails: details.isEmpty
          ? null
          : _CharacterDetailsText(details: details, style: detailStyle),
    );
  }
}

int worldTickEventNumber(Map<String, dynamic> tick, {int fallback = 0}) {
  return _mapInt(tick, const ['tick_no'], fallback: fallback);
}

class _TickHeader extends StatelessWidget {
  const _TickHeader({
    required this.tickNumber,
    required this.subTickNumber,
    required this.date,
    required this.timeAgo,
  });

  final int tickNumber;
  final int subTickNumber;
  final String date;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.genesisWorldColors.tickSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tick $tickNumber${subTickNumber > 0 ? '-$subTickNumber' : ''}'
              '${date.isEmpty ? '' : ' · $date'}',
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: context.genesisColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timeAgo.isNotEmpty) ...[
            SizedBox(width: 12),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w400,
                color: context.genesisColors.textLabelMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlobalEventCard extends StatelessWidget {
  const _GlobalEventCard({
    required this.body,
    required this.stacked,
    this.labelStyle,
    this.bodyStyle,
  });

  final String body;
  final bool stacked;
  final TextStyle? labelStyle;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    final label = Text('Global', style: labelStyle ?? _labelStyle(context));
    final bodyText = Text(body, style: bodyStyle ?? _bodyStyle(context));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.genesisWorldColors.tickPositiveSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, SizedBox(height: 4), bodyText],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 82, child: label),
                Expanded(child: bodyText),
              ],
            ),
    );
  }
}

class _TickParagraphRow extends StatelessWidget {
  const _TickParagraphRow({
    required this.paragraph,
    required this.locationsById,
    required this.charactersById,
    required this.stacked,
    this.labelStyle,
    this.bodyStyle,
    this.timestampStyle,
    this.metricUnit = '',
    this.showClue = false,
  });

  final Map<String, dynamic> paragraph;
  final Map<String, Map<String, dynamic>> locationsById;
  final Map<String, Map<String, dynamic>> charactersById;
  final bool stacked;
  final TextStyle? labelStyle;
  final TextStyle? bodyStyle;
  final TextStyle? timestampStyle;
  final String metricUnit;
  final bool showClue;

  @override
  Widget build(BuildContext context) {
    final locationId = _mapString(paragraph, const ['location_id']);
    final mappedName = _locationName(locationId, locationsById);
    final name = mappedName.isEmpty
        ? _mapString(paragraph, const ['label'], fallback: locationId)
        : mappedName;
    final body = _mapString(paragraph, const [
      'text',
    ], fallback: _mapString(paragraph, const ['content', 'summary']));
    final timestamp = _mapString(paragraph, const [
      'timestamp',
      'timesamp',
      'time',
    ]);
    final clue = showClue ? _mapString(paragraph, const ['clue']) : '';
    final characterDetails = _characterDetails(
      paragraph,
      metricUnit: metricUnit,
    );
    final visibleRoles = _visibleRoles(paragraph, charactersById);

    final label = _LocationLabel(
      text: name.isEmpty ? 'Location' : name,
      style: labelStyle,
    );
    final resolvedBodyStyle = bodyStyle ?? _bodyStyle(context);
    final bodyText = Text(body, style: resolvedBodyStyle);
    final clueText = clue.isEmpty
        ? null
        : _ClueText(text: clue, style: resolvedBodyStyle);
    final timestampText = timestamp.isEmpty
        ? null
        : _TimestampLabel(text: timestamp, style: timestampStyle);
    final metadata = timestampText == null && visibleRoles.isEmpty
        ? null
        : _EventMetadata(
            timestamp: timestampText,
            visibleRoles: visibleRoles,
            style: timestampStyle,
          );
    final characterDetailsText = characterDetails.isEmpty
        ? null
        : _CharacterDetailsText(
            details: characterDetails,
            style: resolvedBodyStyle,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                SizedBox(height: 4),
                if (metadata != null) ...[metadata, SizedBox(height: 2)],
                bodyText,
                if (clueText != null) ...[SizedBox(height: 8), clueText],
                if (characterDetailsText != null) ...[
                  SizedBox(height: 6),
                  characterDetailsText,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 82, child: label),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (metadata != null) ...[metadata, SizedBox(height: 2)],
                      bodyText,
                      if (clueText != null) ...[SizedBox(height: 8), clueText],
                      if (characterDetailsText != null) ...[
                        SizedBox(height: 6),
                        characterDetailsText,
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ClueText extends StatelessWidget {
  const _ClueText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final iconColor = context.genesisColors.textQuaternary;
    final textStyle = style.copyWith(
      color: context.genesisColors.textMuted,
      height: 1.35,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SvgPicture.asset(
            clueIconAsset,
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
        SizedBox(width: 5),
        Expanded(child: GenesisSoftItalicText(text, style: textStyle)),
      ],
    );
  }
}

TextStyle _labelStyle(BuildContext context) => TextStyle(
  fontSize: 11,
  height: 1.6,
  fontWeight: FontWeight.w800,
  color: context.genesisColors.textPrimary,
);

TextStyle _bodyStyle(BuildContext context) => TextStyle(
  fontSize: 11,
  height: 1.6,
  fontWeight: FontWeight.w400,
  color: context.genesisColors.textQuaternary,
);

TextStyle _timestampStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: context.genesisColors.textPrimary,
);

class _CharacterDetailsText extends StatelessWidget {
  const _CharacterDetailsText({required this.details, required this.style});

  final List<_CharacterDetailLine> details;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final nameStyle = style.copyWith(
      color: context.genesisColors.accentText,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (int index = 0; index < details.length; index++) ...[
            if (index > 0) const TextSpan(text: '\n'),
            if (details[index].name.isNotEmpty)
              TextSpan(text: details[index].name, style: nameStyle),
            if (details[index].delta.isNotEmpty)
              TextSpan(
                text: details[index].name.isEmpty
                    ? details[index].delta
                    : ' ${details[index].delta}',
                style: details[index].deltaDirection == 0
                    ? null
                    : style.copyWith(
                        color: details[index].deltaDirection > 0
                            ? context.genesisColors.primary
                            : context.genesisColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
              ),
          ],
        ],
      ),
      style: style,
    );
  }
}

class _LocationLabel extends StatelessWidget {
  const _LocationLabel({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.place_outlined,
          size: 12,
          color: context.genesisColors.textPrimary,
        ),
        SizedBox(width: 4),
        Flexible(child: Text(text, style: style ?? _labelStyle(context))),
      ],
    );
  }
}

class _TimestampLabel extends StatelessWidget {
  const _TimestampLabel({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = (style ?? _timestampStyle(context)).copyWith(
      fontWeight: FontWeight.w400,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule,
          size: 12,
          color: context.genesisColors.textPrimary,
        ),
        SizedBox(width: 4),
        Flexible(child: Text(text, style: resolvedStyle)),
      ],
    );
  }
}

class _EventMetadata extends StatelessWidget {
  const _EventMetadata({
    required this.timestamp,
    required this.visibleRoles,
    this.style,
  });

  final Widget? timestamp;
  final List<_VisibleRole> visibleRoles;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final aiNames = visibleRoles
        .where((role) => role.isAi)
        .map((role) => role.name)
        .toList(growable: false);
    final userNames = visibleRoles
        .where((role) => !role.isAi)
        .map((role) => role.name)
        .toList(growable: false);
    final roleGroups = Wrap(
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: 8,
      runSpacing: 4,
      children: [
        if (aiNames.isNotEmpty)
          _VisibleRoleGroup(
            iconAsset: characterStatIconAsset,
            names: aiNames,
            style: style,
          ),
        if (userNames.isNotEmpty)
          _VisibleRoleGroup(
            iconAsset: userStatIconAsset,
            names: userNames,
            style: style,
          ),
      ],
    );
    if (timestamp == null) return roleGroups;
    if (visibleRoles.isEmpty) return timestamp!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        timestamp!,
        SizedBox(width: 8),
        Expanded(child: roleGroups),
      ],
    );
  }
}

class _VisibleRoleGroup extends StatelessWidget {
  const _VisibleRoleGroup({
    required this.iconAsset,
    required this.names,
    this.style,
  });

  final String iconAsset;
  final List<String> names;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = (style ?? _timestampStyle(context)).copyWith(
      fontWeight: FontWeight.w400,
      color: style?.color ?? context.genesisColors.textQuaternary,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SvgPicture.asset(
            iconAsset,
            width: 12,
            height: 12,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        SizedBox(width: 4),
        Flexible(child: Text(names.join(', '), style: resolvedStyle)),
      ],
    );
  }
}

DateTime? _tickDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    );
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text);
}

List<Map<String, dynamic>> _tickParagraphs(Map<String, dynamic> tick) {
  final raw = tick['paragraphs'];
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList(growable: false);
}

Map<String, dynamic> _tickResult(Map<String, dynamic> tick) {
  final raw = tick['tick_result'];
  if (raw is Map) return raw.cast<String, dynamic>();
  return const <String, dynamic>{};
}

String _locationName(
  String locationId,
  Map<String, Map<String, dynamic>> locationsById,
) {
  final location = locationsById[locationId];
  if (location == null) return '';
  return _mapString(location, const ['location_name', 'name']);
}

class _VisibleRole {
  const _VisibleRole({required this.name, required this.isAi});

  final String name;
  final bool isAi;
}

List<_VisibleRole> _visibleRoles(
  Map<String, dynamic> paragraph,
  Map<String, Map<String, dynamic>> charactersById,
) {
  final visibility = _mapString(paragraph, const ['visibility']).toLowerCase();
  if (visibility == 'public') return const <_VisibleRole>[];
  final rawVisibleTo = paragraph['visible_to'] ?? paragraph['visibleTo'];
  if (rawVisibleTo is! List) return const <_VisibleRole>[];
  final roles = <_VisibleRole>[];
  final seenNames = <String>{};
  for (final rawRoleId in rawVisibleTo) {
    final roleId = '$rawRoleId'.trim();
    if (roleId.isEmpty) continue;
    final character = charactersById[roleId];
    if (character == null) continue;
    final name = _mapString(character, const ['name']).trim();
    if (name.isEmpty || !seenNames.add(name)) continue;
    roles.add(
      _VisibleRole(
        name: name,
        isAi: _mapString(character, const ['player_uid']).isEmpty,
      ),
    );
  }
  return roles;
}

class _CharacterDetailLine {
  const _CharacterDetailLine({
    required this.name,
    required this.delta,
    this.deltaDirection = 0,
  });

  final String name;
  final String delta;
  final int deltaDirection;

  bool get isNotEmpty => name.isNotEmpty || delta.isNotEmpty;
}

List<_CharacterDetailLine> _characterDetails(
  Map<String, dynamic> paragraph, {
  String metricUnit = '',
}) {
  final raw = paragraph['character_deltas'];
  if (raw is! List) return const <_CharacterDetailLine>[];
  final unit = metricUnit.trim();
  return raw
      .whereType<Map>()
      .map((item) {
        final detail = item.cast<String, dynamic>();
        final rawDelta = detail['delta'];
        final delta = _characterDeltaText(rawDelta, unit);
        return _CharacterDetailLine(
          name: _mapString(detail, const ['name']),
          delta: delta,
          deltaDirection: _characterDeltaDirection(rawDelta),
        );
      })
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

String _characterDeltaText(Object? rawDelta, String unit) {
  final delta = _mapString({'delta': rawDelta}, const ['delta']);
  if (delta.isEmpty) return '';
  final number = _pureIntegerDelta(rawDelta);
  final prefix = number != null && number > 0 ? '+' : '';
  return '$prefix$delta$unit';
}

int _characterDeltaDirection(Object? rawDelta) {
  final number = _pureIntegerDelta(rawDelta);
  if (number == null) return 0;
  if (number > 0) return 1;
  if (number < 0) return -1;
  return 0;
}

int? _pureIntegerDelta(Object? value) {
  if (value is int) return value;
  if (value is num) {
    return value % 1 == 0 ? value.toInt() : null;
  }
  final text = '$value'.trim();
  if (!RegExp(r'^[+-]?\d+$').hasMatch(text)) return null;
  return int.tryParse(text);
}

int _mapInt(Map<String, dynamic> map, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

String _mapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}
