// ignore_for_file: use_key_in_widget_constructors

part of 'world_sections_library.dart';

class WorldDetailsLoadingContent extends StatelessWidget {
  const WorldDetailsLoadingContent();

  @override
  Widget build(BuildContext context) {
    return const SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: WorldInfoHeaderLoadingSkeleton()),
        SliverToBoxAdapter(child: SizedBox(height: worldMainTabsHeight)),
      ],
    );
  }
}

class WorldInfoHeaderLoadingSkeleton extends StatelessWidget {
  const WorldInfoHeaderLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey<String>('world-panel-info-row'),
      height: worldInfoHeaderHeight,
      child: Column(
        children: [
          SizedBox(
            height: worldInfoHeaderHeight - 1,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 13),
              child: Row(
                children: [
                  WorldLoadingBone(width: 40, height: 40, radius: 12),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WorldLoadingBone(width: 88, height: 13),
                        SizedBox(height: 6),
                        WorldLoadingBone(width: 112, height: 10),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  WorldLoadingBone(
                    key: ValueKey<String>('world-loading-action'),
                    width: 92,
                    height: worldInfoHeaderContentHeight,
                    radius: 13,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Divider(height: 1, thickness: 1),
          ),
        ],
      ),
    );
  }
}

class WorldLoadingStatBone extends StatelessWidget {
  const WorldLoadingStatBone();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WorldLoadingBone(width: 14, height: 14, radius: 7),
        SizedBox(width: 4),
        WorldLoadingBone(width: 14, height: 12),
      ],
    );
  }
}

class WorldEventLoadingSkeleton extends StatelessWidget {
  const WorldEventLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorldLoadingBone(width: 96, height: 14),
        SizedBox(height: 14),
        WorldLoadingBone(widthFactor: 0.92, height: 12),
        SizedBox(height: 8),
        WorldLoadingBone(widthFactor: 0.78, height: 12),
        SizedBox(height: 8),
        WorldLoadingBone(widthFactor: 0.86, height: 12),
        SizedBox(height: 18),
        WorldLoadingBone(widthFactor: 0.48, height: 12),
        SizedBox(height: 14),
        WorldLoadingBone(widthFactor: 0.96, height: 92, radius: 6),
      ],
    );
  }
}

class WorldLoadingBone extends StatelessWidget {
  const WorldLoadingBone({
    super.key,
    this.width,
    this.widthFactor,
    required this.height,
    this.radius = 4,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: context.genesisWorldColors.loadingSurface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    final widthFactor = this.widthFactor;
    if (widthFactor == null) return child;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

class WorldDetailMoreMenuButton extends StatelessWidget {
  const WorldDetailMoreMenuButton({
    required this.world,
    required this.currentUid,
    required this.onDeleteWorld,
    this.buttonSize = 26,
    this.iconSize = 14,
  });

  final WorldDetail world;
  final String currentUid;
  final Future<void> Function(BuildContext context, WorldDetail world)?
  onDeleteWorld;
  final double buttonSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final canDeleteWorld = worldCanDeleteLaunchedOnlyBySelf(world, currentUid);
    return GenesisMoreActionMenuButton(
      buttonSize: buttonSize,
      iconSize: iconSize,
      iconColor: context.genesisColors.textSecondary,
      items: [
        genesisReportMenuItem(
          context: context,
          targetType: 'world',
          targetId: world.worldId,
        ),
        GenesisActionMenuItem(
          label: 'Delete',
          iconAsset: genesisDeleteIconAsset,
          textStyle: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: canDeleteWorld
                ? context.genesisColors.textInverse
                : context.genesisColors.textInverse.withValues(alpha: 0.45),
          ),
          onSelected: () {
            if (!canDeleteWorld) {
              showGenesisToast(
                context,
                'Only worlds launched by you alone can be deleted.',
                duration: const Duration(seconds: 3),
              );
              return;
            }
            unawaited(onDeleteWorld?.call(context, world));
          },
        ),
      ],
    );
  }
}

class WorldDetailSection extends StatelessWidget {
  const WorldDetailSection({
    required this.world,
    required this.currentUid,
    this.newUserJoinNotice,
    this.onDeleteWorld,
    this.showCharacters = true,
  });

  final WorldDetail world;
  final String currentUid;
  final WorldNewUserJoinNotice? newUserJoinNotice;
  final Future<void> Function(BuildContext context, WorldDetail world)?
  onDeleteWorld;
  final bool showCharacters;

  @override
  Widget build(BuildContext context) {
    final title = world.name.trim().isEmpty ? world.worldId : world.name.trim();
    final owner = worldOwnerDisplayName(world);
    final ownerUid = world.ownerUid.trim();
    final version = world.origin.versionNum <= 0 ? 1 : world.origin.versionNum;
    final sourceWorldoOid = world.origin.oid.trim();
    final sourceWorldoRouteId = sourceWorldoOid.isNotEmpty
        ? sourceWorldoOid
        : world.originId > 0
        ? '${world.originId}'
        : '';
    final sourceOid = sourceWorldoOid.isEmpty
        ? '${world.originId}'
        : sourceWorldoOid;
    final canOpenSourceWorldo = sourceWorldoRouteId.isNotEmpty;
    final brief = world.brief.trim().isEmpty ? '-' : world.brief.trim();
    final cover = worldResolveAssetUrl(world.cover).trim();
    final tags = world.origin.tags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorldDetailCoverImage(url: cover, width: 120, height: 180),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: context.genesisColors.textPrimary,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final tag in tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: context.genesisColors.surfaceTag,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 9.5,
                                height: 1,
                                fontWeight: FontWeight.w500,
                                color: context.genesisColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 7),
                  CopyableIdLabel(
                    label: 'WID',
                    value: world.worldId,
                    displayValue: world.deleted
                        ? deletedEntityDisplayText
                        : null,
                    enabled: !world.deleted,
                    customTextStyle: worldHeaderMetaTextStyle.copyWith(
                      fontSize: 9.5,
                      color: context.genesisColors.textSecondary,
                    ),
                    customIconColor: context.genesisColors.textSecondary,
                  ),
                  GenesisInlineMetaLabel(
                    text: 'Owner $owner',
                    onTap: ownerUid.isEmpty || world.ownerDeleted
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            RouteNames.userInfo,
                            arguments: {'uid': ownerUid},
                          ),
                    style: worldHeaderMetaTextStyle.copyWith(
                      fontSize: 9.5,
                      color: context.genesisColors.textSecondary,
                    ),
                    trailingIcon: ownerUid.isEmpty || world.ownerDeleted
                        ? null
                        : Icons.chevron_right,
                    trailingIconColor: context.genesisColors.textSecondary,
                    trailingIconSize: 12,
                    trailingGap: 3,
                  ),
                  GenesisInlineMetaLabel(
                    text: 'Source $sourceOid · V$version',
                    onTap: !canOpenSourceWorldo
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            RouteNames.originWorld,
                            arguments: {
                              'oid': sourceWorldoRouteId,
                              'originId': world.originId,
                            },
                          ),
                    style: worldHeaderMetaTextStyle.copyWith(
                      fontSize: 9.5,
                      color: context.genesisColors.textSecondary,
                    ),
                    trailingIcon: canOpenSourceWorldo
                        ? Icons.chevron_right
                        : null,
                    trailingIconColor: context.genesisColors.textSecondary,
                    trailingIconSize: 12,
                    trailingGap: 3,
                  ),
                  const SizedBox(height: 8),
                  GenesisPrimaryButton(
                    label: 'Invite',
                    onPressed: () => _copyInviteText(context, worldName: title),
                    height: 30,
                    width: 80,
                    backgroundColor: context.genesisColors.danger,
                    disabledBackgroundColor: context.genesisColors.danger
                        .withValues(alpha: 0.62),
                    foregroundColor: context.genesisColors.onDanger,
                    fontSize: 11,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (newUserJoinNotice != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: _WorldNewUserJoinNoticeSwitcher(notice: newUserJoinNotice!),
          ),
        ],
        SizedBox(height: 17),
        WorldDetailSectionTitle(
          icon: MyFlutterApp.eye,
          iconColor: context.genesisColors.danger,
          title: 'World Brief',
        ),
        const SizedBox(height: 9),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 11),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.genesisColors.dividerAction,
                width: 1,
              ),
            ),
          ),
          child: Text(
            brief,
            style: worldDetailBodyTextStyle.copyWith(
              fontSize: 12,
              height: 1.6,
              color: context.genesisColors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 17),
        WorldDetailSectionTitle(
          asset: worldSectionCastIconAsset,
          iconSize: 9,
          iconColor: context.genesisColors.danger,
          title: 'Cast',
        ),
        SizedBox(height: 1),
        if (showCharacters)
          WorldCharactersSection(world: world, currentUid: currentUid),
      ],
    );
  }

  Future<void> _copyInviteText(
    BuildContext context, {
    required String worldName,
  }) async {
    await Clipboard.setData(
      ClipboardData(
        text: worldInviteShareTextForTesting(
          worldName: worldName,
          wid: world.worldId,
        ),
      ),
    );
    if (!context.mounted) return;
    showGenesisToast(context, 'Link copied. Share it with your friends.');
  }
}

class WorldDetailSectionListView extends StatelessWidget {
  const WorldDetailSectionListView({
    required this.storageKey,
    required this.world,
    required this.currentUid,
    this.scrollController,
    this.newUserJoinNotice,
    this.onDeleteWorld,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 32),
  });

  final String storageKey;
  final WorldDetail world;
  final String currentUid;
  final ScrollController? scrollController;
  final WorldNewUserJoinNotice? newUserJoinNotice;
  final EdgeInsetsGeometry padding;
  final Future<void> Function(BuildContext context, WorldDetail world)?
  onDeleteWorld;

  @override
  Widget build(BuildContext context) {
    final sortedCharacters = worldSortedCharacters(
      world.characters,
      currentUid,
    );
    final hasCharacterRole = sortedCharacters.any(worldIsCharacterRole);
    final itemCount = 1 + math.max(sortedCharacters.length, 1).toInt();
    return WorldSectionListView.builder(
      storageKey: storageKey,
      scrollController: scrollController,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return WorldDetailSection(
            world: world,
            currentUid: currentUid,
            newUserJoinNotice: newUserJoinNotice,
            onDeleteWorld: onDeleteWorld,
            showCharacters: false,
          );
        }
        if (sortedCharacters.isEmpty) {
          return const WorldEmptySection(text: 'No characters yet.');
        }
        final characterIndex = index - 1;
        final character = sortedCharacters[characterIndex];
        return Padding(
          padding: EdgeInsets.only(
            top: characterIndex == 0 ? (hasCharacterRole ? 5 : 0) : 22,
          ),
          child: WorldCharacterRow(
            character: character,
            currentUid: currentUid,
            subtitle: worldCharacterDescriptionText(character),
            subtitleColor: context.genesisColors.textMuted,
            showCharacterDetails: true,
          ),
        );
      },
    );
  }
}

String worldInviteShareTextForTesting({
  required String worldName,
  required String wid,
}) {
  final resolvedWid = wid.trim();
  final resolvedWorldName = worldName.trim().isEmpty
      ? resolvedWid
      : worldName.trim();
  return 'Join my world "$resolvedWorldName" on Worldo!\n'
      '$resolvedWid\n'
      'Search this WID on Worldo to find and join.\n'
      'https://worldo.ai/download';
}

class _WorldNewUserJoinNoticeSwitcher extends StatelessWidget {
  const _WorldNewUserJoinNoticeSwitcher({required this.notice});

  final WorldNewUserJoinNotice notice;

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey<String>(_noticeAnimationKey(notice));
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == currentKey;
          final offset = isIncoming
              ? Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation)
              : Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(animation);
          return SlideTransition(position: offset, child: child);
        },
        child: _WorldNewUserJoinNoticeText(key: currentKey, notice: notice),
      ),
    );
  }

  String _noticeAnimationKey(WorldNewUserJoinNotice notice) {
    return [
      notice.characterId,
      notice.playerUid,
      notice.playerUsername,
      notice.characterName,
      notice.ts?.millisecondsSinceEpoch ?? 0,
    ].join('|');
  }
}

class _WorldNewUserJoinNoticeText extends StatelessWidget {
  const _WorldNewUserJoinNoticeText({super.key, required this.notice});

  final WorldNewUserJoinNotice notice;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: context.genesisColors.textMuted,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w400,
    );
    final emphasisStyle = TextStyle(
      color: context.genesisColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.clip,
                text: TextSpan(
                  style: baseStyle,
                  children: [
                    TextSpan(
                      text: notice.displayPlayerUsername,
                      style: emphasisStyle,
                    ),
                    const TextSpan(text: ' launched as '),
                    TextSpan(
                      text: notice.displayCharacterName,
                      style: emphasisStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WorldDetailSectionTitle extends StatelessWidget {
  const WorldDetailSectionTitle({
    this.icon,
    this.asset,
    this.iconSize = 14,
    required this.iconColor,
    required this.title,
  }) : assert(icon != null || asset != null);

  final IconData? icon;
  final String? asset;
  final double iconSize;
  final Color iconColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Transform.rotate(
          angle: -0.18,
          child: SizedBox.square(
            dimension: 9,
            child: ColoredBox(color: iconColor),
          ),
        ),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w800,
              color: context.genesisColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class WorldDetailCoverImage extends StatelessWidget {
  const WorldDetailCoverImage({required this.url, this.width, this.height});

  static const double _maxHeight = 360;
  static const double _aspectRatio = 2 / 3;

  final String url;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final viewerUrl = url.trim();
    final fallback = Container(
      color: context.genesisColors.imagePlaceholder,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: context.genesisColors.imagePlaceholderIcon,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedWidth = width;
        final fixedHeight = height;
        final mediaHeight = MediaQuery.sizeOf(context).height;
        final maxHeight = mediaHeight.isFinite
            ? _maxHeight.clamp(0.0, mediaHeight * 0.35).toDouble()
            : _maxHeight;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxHeight * _aspectRatio;
        final resolvedWidth =
            fixedWidth ??
            maxWidth.clamp(0.0, maxHeight * _aspectRatio).toDouble();
        final resolvedHeight = fixedHeight ?? resolvedWidth / _aspectRatio;

        final preview = Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: resolvedWidth,
            height: resolvedHeight,
            child: ClipRRect(
              borderRadius: fixedWidth == null
                  ? GenesisImageRadii.content
                  : BorderRadius.circular(13),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imageUrl = selectGenesisImageUrl(
                    url,
                    logicalWidth: constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : null,
                    logicalHeight: constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : null,
                    devicePixelRatio:
                        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
                  );
                  return imageUrl.isEmpty
                      ? fallback
                      : imageUrl.startsWith('assets/')
                      ? Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              fallback,
                        )
                      : GenesisStaticNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_) => fallback,
                          errorWidget: (_, _) => fallback,
                        );
                },
              ),
            ),
          ),
        );
        if (viewerUrl.isEmpty) return preview;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final imageUrl = selectGenesisImageUrl(
              url,
              logicalWidth: resolvedWidth,
              logicalHeight: resolvedHeight,
              devicePixelRatio:
                  MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
            );
            showGenesisImageViewer(
              context,
              imageUrls: [viewerUrl],
              previewImageProviders: [
                genesisImageViewerPreviewProvider(
                  context,
                  imageUrl: imageUrl,
                  logicalWidth: resolvedWidth,
                  logicalHeight: resolvedHeight,
                  fit: BoxFit.cover,
                ),
              ],
            );
          },
          child: preview,
        );
      },
    );
  }
}

class WorldSectionListView extends StatelessWidget {
  const WorldSectionListView({
    required this.storageKey,
    required this.child,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 32),
  }) : itemCount = null,
       itemBuilder = null;

  const WorldSectionListView.builder({
    required this.storageKey,
    required this.itemCount,
    required this.itemBuilder,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 32),
  }) : child = null;

  final String storageKey;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;

  @override
  Widget build(BuildContext context) {
    final itemBuilder = this.itemBuilder;
    if (itemBuilder != null) {
      return ListView.builder(
        key: PageStorageKey<String>(storageKey),
        controller: scrollController,
        primary: false,
        physics: const ClampingScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    }
    return ListView(
      key: PageStorageKey<String>(storageKey),
      controller: scrollController,
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: padding,
      children: [child!],
    );
  }
}
