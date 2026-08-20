part of 'user_profile_library.dart';

class _OriginProfileCollectionList extends StatelessWidget {
  const _OriginProfileCollectionList({
    required this.items,
    required this.isLoading,
    required this.listenable,
    required this.onRefresh,
    this.redesigned = false,
  });

  final List<UserProfileOriginItem> items;
  final bool isLoading;
  final ValueListenable<UserProfileCollectionState<UserProfileOriginItem>>?
  listenable;
  final Future<void> Function()? onRefresh;
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
