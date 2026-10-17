import 'package:flutter/material.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_list_requests.dart';
import '../../../ui/components/genesis_static_network_image.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';
import '../../../components/common/genesis_image_viewer_overlay.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => miniPhonePanel(
    widget.header,
    _lists.build(
      'album',
      () => widget.store.refreshAlbum(next: true),
      GenesisRefreshIndicator(
        onRefresh: () => _lists.refresh('album', widget.store.refreshAlbum),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _livePhotoTile(widget.store.album[index]),
                childCount: widget.store.album.length,
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
  Widget _livePhotoTile(PhoneAlbumAsset asset) => LayoutBuilder(
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
          final photos = widget.store.album
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
