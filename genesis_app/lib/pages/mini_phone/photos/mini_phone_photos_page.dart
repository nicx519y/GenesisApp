import 'package:flutter/material.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_list_requests.dart';
import '../../../ui/components/genesis_static_network_image.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';
import '../../../components/common/genesis_image_viewer_overlay.dart';
import '../../../utils/genesis_image_resource.dart';
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
  late final _lists = MiniPhoneListRequests(widget.store);
  final _scroll = ScrollController();
  bool _fillScheduled = false;

  // One resource may be registered under several locations/assets. Keep the
  // server records intact, but show that image once in the grid and viewer.
  List<PhoneAlbumAsset> get _visiblePhotos {
    final seen = <String>{};
    return widget.store.album
        .where((asset) {
          final image = asset.image.trim();
          final resource = image.isEmpty ? asset.thumbnail.trim() : image;
          final imageResource = GenesisImageResourceRegistry.resolve(resource);
          final resolved = imageResource.displayUrl;
          if (imageResource.keys.any(
            widget.store.worldCoverImageKeys.contains,
          )) {
            return false;
          }
          // Default map artwork is a UI fallback, not a photo of this World.
          if (resolved.isEmpty ||
              resolved.startsWith('assets/images/map_default/') ||
              localDefaultMapImageAssetForBackendImageUrl(resolved) != null) {
            return false;
          }
          return seen.add(resource);
        })
        .toList(growable: false);
  }

  void _fillViewport() {
    if (_fillScheduled) return;
    _fillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillScheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      final store = widget.store;
      if (store.hasMore['album'] == true &&
          !store.busy.contains('album') &&
          !store.errors.containsKey('album') &&
          _scroll.position.extentAfter < 160) {
        store.refreshAlbum(next: true);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _visiblePhotos;
    _fillViewport();
    return miniPhonePanel(
      widget.header,
      _lists.build(
        'album',
        () => widget.store.refreshAlbum(next: true),
        GenesisRefreshIndicator(
          onRefresh: () => _lists.refresh('album', widget.store.refreshAlbum),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _livePhotoTile(photos[index], photos),
                  childCount: photos.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _livePhotoTile(
    PhoneAlbumAsset asset,
    List<PhoneAlbumAsset> visiblePhotos,
  ) => LayoutBuilder(
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
          final photos = visiblePhotos
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
            source: source,
          );
        },
        child: image,
      );
    },
  );
}
