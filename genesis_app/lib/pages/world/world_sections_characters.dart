// ignore_for_file: use_key_in_widget_constructors

part of 'world_sections_library.dart';

class WorldStatusSection extends StatelessWidget {
  const WorldStatusSection({required this.world, required this.currentUid});

  final WorldDetail world;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return WorldCharacterList(
      characters: world.characters,
      currentUid: currentUid,
      emptyText: 'No character status yet.',
      subtitleBuilder: (character) =>
          worldMetricStatusText(world.metric, character),
      subtitleColor: context.genesisColors.textMuted,
      showCharacterDetails: false,
      statusProgressStyle: true,
      metric: world.metric,
      locationNameBuilder: (character) =>
          worldCharacterLocationName(world, character),
    );
  }
}

class WorldCharactersSection extends StatelessWidget {
  const WorldCharactersSection({required this.world, required this.currentUid});

  final WorldDetail world;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return WorldCharacterList(
      characters: world.characters,
      currentUid: currentUid,
      emptyText: 'No characters yet.',
      subtitleBuilder: worldCharacterDescriptionText,
      subtitleColor: context.genesisColors.textMuted,
      showCharacterDetails: true,
    );
  }
}

class WorldCharacterListView extends StatelessWidget {
  const WorldCharacterListView({
    required this.storageKey,
    required this.characters,
    required this.currentUid,
    required this.emptyText,
    required this.subtitleBuilder,
    required this.subtitleColor,
    required this.showCharacterDetails,
    this.scrollController,
    this.cardStyle = false,
    this.statusProgressStyle = false,
    this.metric = const <String, dynamic>{},
    this.locationNameBuilder,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 32),
  });

  final String storageKey;
  final List<Map<String, dynamic>> characters;
  final String currentUid;
  final String emptyText;
  final String Function(Map<String, dynamic> character) subtitleBuilder;
  final Color subtitleColor;
  final bool showCharacterDetails;
  final ScrollController? scrollController;
  final bool cardStyle;
  final bool statusProgressStyle;
  final Map<String, dynamic> metric;
  final String Function(Map<String, dynamic> character)? locationNameBuilder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final sortedCharacters = worldSortedCharacters(characters, currentUid);
    return WorldSectionListView.builder(
      storageKey: storageKey,
      scrollController: scrollController,
      padding: padding,
      itemCount: math.max(sortedCharacters.length, 1),
      itemBuilder: (context, index) {
        if (sortedCharacters.isEmpty) {
          return WorldEmptySection(text: emptyText);
        }
        final character = sortedCharacters[index];
        return Padding(
          padding: EdgeInsets.only(
            top: index == 0 ? 0 : (cardStyle || statusProgressStyle ? 10 : 11),
          ),
          child: WorldCharacterRow(
            character: character,
            currentUid: currentUid,
            subtitle: subtitleBuilder(character),
            subtitleColor: subtitleColor,
            showCharacterDetails: showCharacterDetails,
            cardStyle: cardStyle,
            statusProgressStyle: statusProgressStyle,
            metric: metric,
            locationName: locationNameBuilder?.call(character) ?? '',
          ),
        );
      },
    );
  }
}

class WorldCharacterList extends StatelessWidget {
  const WorldCharacterList({
    required this.characters,
    required this.currentUid,
    required this.emptyText,
    required this.subtitleBuilder,
    required this.subtitleColor,
    required this.showCharacterDetails,
    this.cardStyle = false,
    this.statusProgressStyle = false,
    this.metric = const <String, dynamic>{},
    this.locationNameBuilder,
  });

  final List<Map<String, dynamic>> characters;
  final String currentUid;
  final String emptyText;
  final String Function(Map<String, dynamic> character) subtitleBuilder;
  final Color subtitleColor;
  final bool showCharacterDetails;
  final bool cardStyle;
  final bool statusProgressStyle;
  final Map<String, dynamic> metric;
  final String Function(Map<String, dynamic> character)? locationNameBuilder;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return WorldEmptySection(text: emptyText);
    }
    final hasCharacterRole = characters.any(worldIsCharacterRole);
    final sortedCharacters = worldSortedCharacters(characters, currentUid);

    return Padding(
      padding: EdgeInsets.only(top: hasCharacterRole ? 5 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < sortedCharacters.length; i++) ...[
            WorldCharacterRow(
              character: sortedCharacters[i],
              currentUid: currentUid,
              subtitle: subtitleBuilder(sortedCharacters[i]),
              subtitleColor: subtitleColor,
              showCharacterDetails: showCharacterDetails,
              cardStyle: cardStyle,
              statusProgressStyle: statusProgressStyle,
              metric: metric,
              locationName:
                  locationNameBuilder?.call(sortedCharacters[i]) ?? '',
            ),
            if (i != sortedCharacters.length - 1)
              SizedBox(height: cardStyle || statusProgressStyle ? 10 : 11),
          ],
        ],
      ),
    );
  }
}

class WorldCharacterRow extends StatelessWidget {
  const WorldCharacterRow({
    required this.character,
    required this.currentUid,
    required this.subtitle,
    required this.subtitleColor,
    required this.showCharacterDetails,
    this.cardStyle = false,
    this.statusProgressStyle = false,
    this.metric = const <String, dynamic>{},
    this.locationName = '',
  });

  final Map<String, dynamic> character;
  final String currentUid;
  final String subtitle;
  final Color subtitleColor;
  final bool showCharacterDetails;
  final bool cardStyle;
  final bool statusProgressStyle;
  final Map<String, dynamic> metric;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final name = worldMapString(character, const [
      'name',
    ], fallback: 'Character');
    final avatarUrl = worldResizedCharacterAvatarUrl(context, character);
    final playerUid = worldMapString(character, const ['player_uid']);
    final username = worldMapString(character, const ['player_username']);
    final playerDeleted = entityDeleted(character['player_deleted']);
    final isCurrentUser = worldIsCurrentUserCharacter(character, currentUid);
    final defaultSuffix = worldCharacterNameSuffix(
      currentUid: currentUid,
      playerUid: playerUid,
      username: username,
      playerDeleted: playerDeleted,
    );
    final suffix = statusProgressStyle && isCurrentUser && !playerDeleted
        ? 'You'
        : defaultSuffix;
    final isCharacterRole = worldIsCharacterRole(character);
    final roleLabel = isCharacterRole ? 'Character' : 'Player';
    final showAiCharacterDetails = showCharacterDetails && isCharacterRole;
    final identity = worldMapString(character, const ['identity']);
    final brief = worldMapString(character, const ['brief']);
    final goal = worldMapString(character, const ['goal']);
    final hasOriginStyleDetails =
        identity.isNotEmpty || brief.isNotEmpty || goal.isNotEmpty;
    final bodyStyle = TextStyle(
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: context.genesisColors.textPrimary,
    );

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GenesisCharacterAvatar(
          url: avatarUrl,
          name: name,
          showStar: false,
          size: cardStyle || statusProgressStyle ? 44 : 40,
          borderRadius: cardStyle || statusProgressStyle ? 13 : 12,
          border:
              (!statusProgressStyle && !isCharacterRole) ||
                  (statusProgressStyle && isCurrentUser)
              ? Border.all(color: context.genesisColors.danger, width: 2)
              : null,
          showFallbackWhileLoading: false,
        ),
        SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: name,
                          children: [
                            if (suffix.isNotEmpty)
                              TextSpan(
                                text: ' $suffix',
                                style: TextStyle(
                                  color: statusProgressStyle
                                      ? context.genesisColors.textSecondary
                                      : context.genesisColors.textFaint,
                                ),
                              ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: cardStyle || statusProgressStyle ? 14 : 13,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: context.genesisColors.foregroundStrong,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!statusProgressStyle) ...[
                      SizedBox(width: 8),
                      Text(
                        roleLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1.15,
                          fontWeight: FontWeight.w400,
                          color: context.genesisColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                if (statusProgressStyle) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _WorldStatusProgressBar(
                          progressKey: ValueKey<String>(
                            'world-status-progress-${worldCharacterStableId(character)}',
                          ),
                          value: worldMetricProgressValue(metric, character),
                          semanticsValue: worldMetricProgressText(
                            metric,
                            character,
                          ),
                          backgroundColor: context.genesisColors.surfaceTag,
                          valueColor: isCurrentUser
                              ? context.genesisColors.danger
                              : context.genesisColors.accentText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        worldMetricProgressText(metric, character),
                        style: TextStyle(
                          fontSize: 11,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: context.genesisColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (locationName.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      locationName,
                      key: ValueKey<String>(
                        'world-status-location-${worldCharacterStableId(character)}',
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: isCurrentUser
                            ? context.genesisColors.danger
                            : context.genesisColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ] else if (showAiCharacterDetails) ...[
                  if (identity.isNotEmpty) ...[
                    SizedBox(height: 5),
                    Text(
                      identity,
                      style: bodyStyle.copyWith(
                        color: context.genesisColors.textPrimary.withValues(
                          alpha: 0.92,
                        ),
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (brief.isNotEmpty) ...[
                    SizedBox(height: 5),
                    Text(
                      brief,
                      style: bodyStyle.copyWith(
                        color: context.genesisColors.accentText,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (goal.isNotEmpty) ...[
                    SizedBox(height: 5),
                    Text.rich(
                      TextSpan(
                        style: bodyStyle.copyWith(
                          color: context.genesisColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Goal: ',
                            style: TextStyle(
                              color: context.genesisColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: goal),
                        ],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (!hasOriginStyleDetails) ...[
                    SizedBox(height: 5),
                    Text(
                      'No character details yet.',
                      style: bodyStyle.copyWith(color: subtitleColor),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ] else if (showCharacterDetails) ...[
                  SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: bodyStyle,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  SizedBox(height: cardStyle ? 8 : 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: cardStyle ? 11 : 12,
                      height: cardStyle ? 1.3 : 1.5,
                      fontWeight: FontWeight.w400,
                    ).copyWith(color: subtitleColor),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    if (!cardStyle && !statusProgressStyle) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: context.genesisColors.dividerAction,
              width: 1,
            ),
          ),
        ),
        child: content,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: statusProgressStyle
            ? context.genesisColors.surfaceSubtle
            : context.genesisColors.surfaceTag,
        borderRadius: BorderRadius.circular(14),
        border: isCurrentUser
            ? Border.all(color: context.genesisColors.danger, width: 1.5)
            : null,
      ),
      child: content,
    );
  }
}

String worldResizedCharacterAvatarUrl(
  BuildContext context,
  Map<String, dynamic> character,
) {
  final rawUrl = worldMapString(character, const ['avatar']).trim();
  final resizedUrl = resizeGenesisImageUrl(
    rawUrl,
    logicalWidth: worldCharacterAvatarLogicalSize,
    devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
  );
  return resizedUrl.isNotEmpty ? resizedUrl : rawUrl;
}

List<Map<String, dynamic>> worldSortedCharacters(
  List<Map<String, dynamic>> characters,
  String currentUid,
) {
  final indexed = characters.indexed.toList(growable: false);
  indexed.sort((a, b) {
    final rankCompare = worldCharacterSortRank(
      a.$2,
      currentUid,
    ).compareTo(worldCharacterSortRank(b.$2, currentUid));
    if (rankCompare != 0) return rankCompare;
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

int worldCharacterSortRank(Map<String, dynamic> character, String currentUid) {
  if (worldIsCurrentUserCharacter(character, currentUid)) return 0;
  return worldIsCharacterRole(character) ? 2 : 1;
}

bool worldIsCurrentUserCharacter(
  Map<String, dynamic> character,
  String currentUid,
) {
  final playerUid = worldMapString(character, const ['player_uid']);
  return currentUid.isNotEmpty &&
      playerUid.isNotEmpty &&
      playerUid == currentUid;
}

bool worldIsCharacterRole(Map<String, dynamic> character) {
  return worldMapString(character, const ['player_uid']).isEmpty;
}

String worldCharacterNameSuffix({
  required String currentUid,
  required String playerUid,
  required String username,
  required bool playerDeleted,
}) {
  if (playerUid.isNotEmpty && playerDeleted) {
    return '($deletedEntityDisplayText)';
  }
  if (currentUid.isNotEmpty &&
      playerUid.isNotEmpty &&
      playerUid == currentUid) {
    return '(Me)';
  }
  if (playerUid.isNotEmpty && username.isNotEmpty) return '($username)';
  return '';
}

String worldCharacterStableId(Map<String, dynamic> character) {
  return worldMapString(character, const [
    'char_id',
    'character_id',
    'id',
    'player_uid',
  ], fallback: worldMapString(character, const ['name'], fallback: 'unknown'));
}

String worldCharacterLocationName(
  WorldDetail world,
  Map<String, dynamic> character,
) {
  var locationId = worldMapString(character, const [
    'location_id',
    'current_location_id',
    'initial_location_id',
  ]);
  if (locationId.isEmpty) {
    final characterId = worldCharacterStableId(character);
    final playerUid = worldMapString(character, const ['player_uid']);
    for (final position in world.characterPositions) {
      final rawCharacter = position['character'];
      final positionedCharacter = rawCharacter is Map
          ? rawCharacter.map((key, value) => MapEntry('$key', value))
          : position;
      final positionedId = worldCharacterStableId(positionedCharacter);
      final positionedUid = worldMapString(positionedCharacter, const [
        'player_uid',
        'uid',
        'user_id',
      ]);
      if (positionedId != characterId &&
          (playerUid.isEmpty || positionedUid != playerUid)) {
        continue;
      }
      locationId = worldMapString(position, const [
        'location_id',
        'current_location_id',
      ]);
      if (locationId.isNotEmpty) break;
    }
    if (locationId.isEmpty && playerUid.isNotEmpty) {
      for (final position in world.userPositions) {
        final positionedUid = worldMapString(position, const [
          'uid',
          'player_uid',
          'user_id',
        ]);
        if (positionedUid != playerUid) continue;
        locationId = worldMapString(position, const [
          'location_id',
          'current_location_id',
        ]);
        if (locationId.isNotEmpty) break;
      }
    }
  }
  if (locationId.isEmpty) return '';
  for (final location in world.locations) {
    final id = worldMapString(location, const ['location_id', 'id']);
    if (id != locationId) continue;
    return worldMapString(location, const ['location_name', 'name']);
  }
  return '';
}

class _WorldStatusProgressBar extends StatelessWidget {
  const _WorldStatusProgressBar({
    required this.progressKey,
    required this.value,
    required this.semanticsValue,
    required this.backgroundColor,
    required this.valueColor,
  });

  final Key progressKey;
  final double value;
  final String semanticsValue;
  final Color backgroundColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        key: progressKey,
        value: value.clamp(0.0, 1.0),
        semanticsValue: semanticsValue,
        minHeight: 5,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation<Color>(valueColor),
      ),
    );
  }
}

class WorldEmptySection extends StatelessWidget {
  const WorldEmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.genesisColors.textSupporting,
          ),
        ),
      ),
    );
  }
}

String worldEventBody(WorldDetail world) {
  final candidates = [
    world.latestNarrator,
    world.origin.worldView,
    world.origin.description,
    world.name,
  ];
  for (final item in candidates) {
    final value = item.trim();
    if (value.isNotEmpty) return value;
  }
  return 'No world events yet.';
}

String worldCharacterDescriptionText(Map<String, dynamic> character) {
  final identity = worldMapString(character, const ['identity']);
  if (!worldIsCharacterRole(character)) {
    return identity.isEmpty ? 'No character details yet.' : identity;
  }

  final brief = worldMapString(character, const ['brief']);
  final goal = worldMapString(character, const ['goal']);
  final details = worldOrderedNonEmptyStrings([
    identity,
    brief,
    goal.isEmpty ? '' : 'Goal: $goal',
  ]);
  return details.isEmpty ? 'No character details yet.' : details.join('\n');
}

String worldMetricStatusText(
  Map<String, dynamic> metric,
  Map<String, dynamic> character,
) {
  final label = worldMapString(metric, const ['label']);
  final unit = worldMapString(metric, const ['unit']);
  final value = worldResolvedMetricValueText(
    character['metric_value'],
    metric['default'],
  );
  return '$label: $value$unit';
}

String worldResolvedMetricValueText(Object? metricValue, Object? defaultValue) {
  return worldMetricDisplayValue(
    worldResolvedMetricValue(metricValue, defaultValue),
  );
}

Object? worldResolvedMetricValue(Object? metricValue, Object? defaultValue) {
  final parsedMetricValue = worldMetricNumber(metricValue);
  return parsedMetricValue == null || parsedMetricValue == 0
      ? defaultValue
      : metricValue;
}

double worldMetricProgressValue(
  Map<String, dynamic> metric,
  Map<String, dynamic> character,
) {
  final value = worldMetricNumber(
    worldResolvedMetricValue(character['metric_value'], metric['default']),
  );
  if (value == null) return 0;
  return (value / 100).clamp(0, 1).toDouble();
}

String worldMetricProgressText(
  Map<String, dynamic> metric,
  Map<String, dynamic> character,
) {
  final value = worldResolvedMetricValueText(
    character['metric_value'],
    metric['default'],
  );
  return '$value${worldMapString(metric, const ['unit'])}';
}

num? worldMetricNumber(Object? value) {
  if (value is num) return value;
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  return num.tryParse(text);
}

String worldMetricDisplayValue(Object? value) {
  if (value is num) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '0';
  return text;
}
