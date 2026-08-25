part of 'user_profile_library.dart';

class _OriginProfileCollectionList extends StatelessWidget {
  const _OriginProfileCollectionList({
    required this.items,
    required this.isLoading,
    required this.listenable,
    required this.onRefresh,
    required this.canEdit,
    this.redesigned = false,
  });

  final List<UserProfileOriginItem> items;
  final bool isLoading;
  final ValueListenable<UserProfileCollectionState<UserProfileOriginItem>>?
  listenable;
  final Future<void> Function()? onRefresh;
  final bool canEdit;
  final bool redesigned;

  @override
  Widget build(BuildContext context) {
    final listenable = this.listenable;
    if (listenable == null) {
      return _buildOriginList(context, items, isLoading);
    }
    return ValueListenableBuilder<
      UserProfileCollectionState<UserProfileOriginItem>
    >(
      valueListenable: listenable,
      builder: (context, state, _) {
        return _buildOriginList(context, state.items, state.isLoading);
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    UserProfileOriginItem item,
  ) async {
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'me_origin_edit_click',
      object1: item.oid,
    );
    await Navigator.of(
      context,
    ).pushNamed(RouteNames.edit, arguments: {'origin_id': item.oid});
    if (!context.mounted) return;
    onRefresh?.call();
  }

  Widget _buildOriginList(
    BuildContext context,
    List<UserProfileOriginItem> items,
    bool isLoading,
  ) {
    return ProfileCollectionList(
      items: items
          .map(
            (item) => GenesisProfileCollectionItemData(
              imageUrl: item.imageUrl,
              title: redesigned ? item.title : originDisplayName(item.title),
              subtitle: item.subtitle,
              titleTrailing: canEdit && !item.deleted
                  ? const _OriginEditIcon()
                  : null,
              onTitleTrailingTap: canEdit && !item.deleted
                  ? () => _openEditor(context, item)
                  : null,
              titleTrailingSemanticsLabel: 'Edit Worldo',
              showPressedBackground: false,
              useRedesignedLayout: redesigned,
              stats: [
                GenesisProfileCollectionStat(
                  iconAsset: redesigned
                      ? originFeedPlayIconAsset
                      : copyStatIconAsset,
                  value: item.copyCount,
                ),
                GenesisProfileCollectionStat(
                  iconAsset: redesigned
                      ? originFeedCommentIconAsset
                      : connectStatIconAsset,
                  value: item.interactCount,
                ),
                GenesisProfileCollectionStat(
                  iconAsset: redesigned
                      ? originFeedRoleIconAsset
                      : characterStatIconAsset,
                  preserveIconAssetColor: true,
                  value: item.characterCount,
                ),
              ],
              onTap: item.deleted
                  ? null
                  : () {
                      GenesisTelemetry.collectLog(
                        actionType: 'event',
                        action: 'me_click',
                        object1: item.oid,
                      );
                      Navigator.of(context)
                          .pushNamed(
                            RouteNames.originWorld,
                            arguments: {
                              'originId': item.originId,
                              'oid': item.oid,
                            },
                          )
                          .then((_) {
                            if (!context.mounted) return;
                            onRefresh?.call();
                          });
                    },
            ),
          )
          .toList(growable: false),
      emptyText: 'No Worldo you created yet.',
      isLoading: isLoading,
      loadingKey: const ValueKey('profile-origin-list-loading'),
      onRefresh: onRefresh,
      refreshKey: const ValueKey('profile-origin-list-refresh'),
      redesigned: redesigned,
    );
  }
}

/// Edit affordance on your own Worldo rows, sitting right after the title.
/// Edit affordance on your own Worldo rows: a 12 glyph riding the title's
/// bottom edge at the far right. It carries no gesture of its own - the list
/// item stacks a 44 square over this corner and owns the tap, so the touch
/// target is full size without the glyph having to be.
class _OriginEditIcon extends StatelessWidget {
  const _OriginEditIcon();

  /// One step under the 14 title.
  static const double iconSize = 12;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      editPencilLineIconAsset,
      key: const ValueKey<String>('profile-origin-edit-entry'),
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(
        // The 45% tier; textMetadata is the semantic that carries it.
        context.genesisColors.textMetadata,
        BlendMode.srcIn,
      ),
      excludeFromSemantics: true,
    );
  }
}
