import 'package:flutter/material.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_list_requests.dart';
import '../../../ui/components/genesis_static_network_image.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';
import '../../../components/common/genesis_image_viewer_overlay.dart';
import 'mini_phone_photo_projection.dart';
import 'mini_phone_photo_thumbnail.dart';

class MiniPhonePhotosPage extends StatefulWidget {
  const MiniPhonePhotosPage({
    super.key,
    required this.store,
    required this.header,
  });
  final MiniPhoneStore store;
  final Widget header;
  @override
  State<MiniPhonePhotosPage> createState() => _MiniPhonePhotosPageState();
}

class _MiniPhonePhotosPageState extends State<MiniPhonePhotosPage> {
  late final _lists = MiniPhoneListRequests(
    widget.store.requests,
    isActive: () => _active,
  );
  final _scroll = ScrollController(keepScrollOffset: false);
  bool _fillScheduled = false;
  Size _viewportSize = Size.zero;

  final _projection = MiniPhonePhotoProjection();
  final _confirmedProjection = MiniPhonePhotoProjection();
  List<PhoneAlbumAsset> _photos = const [];
  final _tiles = <int, ({PhoneAlbumAsset asset, Widget widget})>{};
  Object? _listState;
  Object? _pagingState;

  bool get _active =>
      widget.store.phoneVisible &&
      (ModalRoute.isCurrentOf(context) ?? true) &&
      TickerMode.valuesOf(context).enabled;

  bool _sync() {
    final store = widget.store;
    final photos = _projection.resolve(store.album, store.worldCoverImageKeys);
    final pagingState = (
      store.photosController.confirmedAlbum,
      store.pages['album'],
      store.busy.contains('album'),
      photos,
    );
    if (pagingState != _pagingState) {
      _pagingState = pagingState;
      _fillViewport();
    }
    final state = (photos, store.accountGeneration);
    if (state == _listState) return false;
    final assets = {for (final photo in photos) photo.id: photo};
    _tiles.removeWhere((id, tile) => !identical(assets[id], tile.asset));
    _photos = photos;
    _listState = state;
    return true;
  }

  void _fillViewport() {
    if (_fillScheduled) return;
    _fillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillScheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      _loadNextAtBoundary(_scroll.position);
    });
    // A filtered or unchanged page may complete without rebuilding the grid.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _loadNextAtBoundary(ScrollMetrics metrics) {
    if (_viewportSize.width <= 0) return;
    final store = widget.store;
    final confirmed = _confirmedProjection.resolve(
      store.photosController.confirmedAlbum,
      store.worldCoverImageKeys,
    );
    final boundary = ((confirmed.length + 2) ~/ 3) * (_viewportSize.width / 3);
    if (metrics.pixels + metrics.viewportDimension + 160 >= boundary) {
      _lists.loadNext('album', () => store.refreshAlbum(next: true));
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
    widget.store.addListener(_changed);
  }

  void _changed() {
    if (mounted && _sync()) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    return miniPhonePanel(
      widget.header,
      LayoutBuilder(
        builder: (context, bounds) {
          if (_viewportSize != bounds.biggest) {
            _viewportSize = bounds.biggest;
            _fillViewport();
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth == 0 &&
                  notification.metrics.axis == Axis.vertical &&
                  ((notification is ScrollUpdateNotification &&
                          (notification.scrollDelta ?? 0) > 0) ||
                      (notification is OverscrollNotification &&
                          notification.overscroll > 0))) {
                _loadNextAtBoundary(notification.metrics);
              }
              return false;
            },
            child: GenesisRefreshIndicator(
              onRefresh: () =>
                  _lists.refresh('album', widget.store.refreshAlbum),
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final asset = photos[index];
                        return (_tiles[asset.id] ??= (
                          asset: asset,
                          widget: _livePhotoTile(asset),
                        )).widget;
                      },
                      childCount: photos.length,
                      findChildIndexCallback: (key) {
                        if (key is! ValueKey<int>) return null;
                        final index = photos.indexWhere(
                          (a) => a.id == key.value,
                        );
                        return index < 0 ? null : index;
                      },
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _livePhotoTile(PhoneAlbumAsset asset) => LayoutBuilder(
    key: ValueKey(asset.id),
    builder: (context, bounds) {
      final thumbnail = asset.image.trim().isEmpty
          ? asset.thumbnail
          : asset.image;
      final preview = miniPhonePhotoThumbnailProvider(
        thumbnail,
        width: bounds.maxWidth,
        height: bounds.maxHeight,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        fit: BoxFit.cover,
      );
      final image = GenesisStaticNetworkImage(
        imageUrl: preview.imageUrl,
        fit: BoxFit.cover,
        placeholder: (_) => const ColoredBox(color: Color(0x1FFFFFFF)),
        errorWidget: (_, _) => const ColoredBox(color: Color(0x1FFFFFFF)),
      );
      if (asset.image.trim().isEmpty) return image;
      return GenesisImageViewerSourceAnchor(
        key: ValueKey('mini-phone-album-${asset.id}'),
        previewImageProvider: preview,
        fit: BoxFit.cover,
        onTap: (source) {
          final photos = _photos
              .where((a) => a.image.trim().isNotEmpty)
              .toList();
          final initialIndex = photos.indexWhere((a) => a.id == asset.id);
          if (initialIndex < 0) return;
          showGenesisImageViewer(
            context,
            imageUrls: [for (final photo in photos) photo.image],
            previewImageProviders: [
              for (final photo in photos)
                miniPhonePhotoThumbnailProvider(
                  photo.image,
                  width: bounds.maxWidth,
                  height: bounds.maxHeight,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  fit: BoxFit.cover,
                ),
            ],
            initialIndex: initialIndex,
            onImageViewed: widget.store.analytics.photoViewer(),
            source: source,
          );
        },
        child: image,
      );
    },
  );
}
