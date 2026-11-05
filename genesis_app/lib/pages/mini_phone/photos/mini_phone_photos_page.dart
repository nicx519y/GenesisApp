import 'dart:async';
import '../../../l10n/genesis_localizations.dart';
import '../../../network/mini_phone/mini_phone_camera_models.dart';
import '../../../network/models/photo_task.dart';
import '../../../ui/components/genesis_primary_button.dart';
import '../shared/mini_phone_toast.dart';
import '../camera/mini_phone_camera_tasks.dart';
import '../camera/mini_phone_camera_tasks_album.dart';
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
import '../camera/mini_phone_camera_preview_jobs.dart';
import '../camera/mini_phone_camera_preview_album.dart';

class MiniPhonePhotosPage extends StatefulWidget {
  const MiniPhonePhotosPage({
    super.key,
    required this.store,
    required this.header,
    this.previewJobs,
    this.tasks,
    this.target,
    this.onTargetHandled,
    this.active = true,
    this.onUsePhotoInPost,
  });
  final MiniPhoneStore store;
  final bool active;
  final MiniPhoneCameraTasks? tasks;
  final PhoneCameraTarget? target;
  final VoidCallback? onTargetHandled;
  final Widget header;
  final MiniPhoneCameraPreviewJobs? previewJobs;
  final void Function(
    String imageUrl,
    ImageProvider<Object> previewImageProvider,
  )?
  onUsePhotoInPost;
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
  double _previewExtent = 0;

  final _projection = MiniPhonePhotoProjection();
  final _confirmedProjection = MiniPhonePhotoProjection();
  List<PhoneAlbumAsset> _photos = const [];
  List<PhoneWrite> _taskRecords = const [];
  int _confirmedPhotoCount = 0;
  final _tiles = <int, ({PhoneAlbumAsset asset, Widget widget})>{};
  Object? _listState;
  Object? _pagingState;
  final _successAssets = <String, ({PhotoTask photo, PhoneAlbumAsset asset})>{};
  final _anchors = <int, GlobalKey<GenesisImageViewerSourceAnchorState>>{};
  PhoneCameraTarget? _target;
  int? _targetGeneration;
  bool _targetScheduled = false, _targetLoading = false, _targetLocated = false;
  List<PhoneAlbumAsset> _mergedAlbum = const [];
  Object? _mergedKey;

  List<PhoneAlbumAsset> _album() {
    final completed =
        widget.tasks?.records
            .where((w) => !w.cameraInAlbum)
            .map((w) => w.cameraPhoto)
            .whereType<PhotoTask>()
            .where((p) => p.status == PhotoTaskStatus.succeeded)
            .toList() ??
        [];
    final key = (
      widget.store.album,
      Object.hashAll(completed),
      widget.store.accountGeneration,
    );
    if (key == _mergedKey) return _mergedAlbum;
    _mergedKey = key;
    final known = widget.store.album.map((a) => a.id).toSet();
    _mergedAlbum = [
      for (final photo in completed)
        if (!known.contains(photo.assetId))
          (_successAssets[photo.taskId]?.photo == photo
                  ? _successAssets[photo.taskId]!
                  : _successAssets[photo.taskId] = (
                      photo: photo,
                      asset: PhoneAlbumAsset.fromJson({
                        'asset_id': photo.assetId,
                        'world_id': widget.store.worldId,
                        'image_url': photo.imageUrl,
                        'desc': photo.description,
                      }),
                    ))
              .asset,
      ...widget.store.album,
    ];
    return _mergedAlbum;
  }

  void _cancelTarget() {
    if (_target != null) widget.onTargetHandled?.call();
    _target = null;
  }

  int _targetIndex() {
    final id = _projection.aliases[_target?.assetId] ?? _target?.assetId;
    return _photos.indexWhere((p) => p.id == id);
  }

  bool get _targetCurrent =>
      mounted &&
      widget.active &&
      _target != null &&
      _targetGeneration == widget.store.accountGeneration;

  Future<void> _loadTarget() async {
    if (_targetLoading || !_targetCurrent) return;
    _targetLoading = true;
    try {
      if (_targetIndex() < 0) {
        if (!await widget.store.refreshAlbum()) {
          _targetFailed();
          return;
        }
        while (_targetCurrent &&
            _targetIndex() < 0 &&
            widget.store.hasMore['album'] == true) {
          if (!await widget.store.refreshAlbum(next: true)) {
            _targetFailed();
            return;
          }
        }
      }
      if (!_targetCurrent) return;
      if (_targetIndex() < 0) {
        _targetFailed();
        return;
      }
      _targetLocated = true;
      _scheduleTarget();
    } finally {
      _targetLoading = false;
    }
  }

  void _targetFailed() {
    if (!_targetCurrent) return;
    _cancelTarget();
    showMiniPhoneToast(context, context.l10n.chatPhotoUnavailable);
    _fillViewport();
  }

  void _targetImageFailed(int assetId) {
    if (!_targetCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_targetCurrent) return;
      final index = _targetIndex();
      if (index >= 0 && _photos[index].id == assetId) _targetFailed();
    });
  }

  void _scheduleTarget() {
    if (!_targetCurrent || !_targetLocated || _targetScheduled) return;
    _targetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _targetScheduled = false;
      if (!_targetCurrent ||
          !_active ||
          !_scroll.hasClients ||
          _viewportSize.width <= 0) {
        return;
      }
      final index = _targetIndex();
      if (index < 0) {
        _targetFailed();
        return;
      }
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      final desired =
          (_previewExtent +
                  ((index + _taskRecords.length) ~/ 3) *
                      _viewportSize.width /
                      3)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
      if ((position.pixels - desired).abs() > .5) {
        _scroll.jumpTo(desired);
        _scheduleTarget();
        return;
      }
      final anchor = _anchors[_photos[index].id]?.currentState;
      if (anchor == null) {
        _scheduleTarget();
        return;
      }
      // The thumbnail may still be loading. Its loaded callback schedules
      // another attempt; _openPhoto consumes the target only after capture.
      anchor.open();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleTarget();
  }

  bool get _active =>
      widget.active &&
      widget.store.phoneVisible &&
      (ModalRoute.isCurrentOf(context) ?? true) &&
      TickerMode.valuesOf(context).enabled;

  bool _sync() {
    final store = widget.store;
    final photos = _projection.resolve(_album(), store.worldCoverImageKeys);
    final taskRecords =
        widget.tasks?.visibleRecords
            .where((w) => w.cameraPhoto?.status != PhotoTaskStatus.succeeded)
            .toList() ??
        <PhoneWrite>[];
    final taskState = Object.hashAll(
      widget.tasks?.visibleRecords.map(
            (w) => (w.id, w.cameraPhoto, w.uncertain),
          ) ??
          const [],
    );
    final pagingState = (
      store.photosController.confirmedAlbum,
      store.pages['album'],
      store.busy.contains('album'),
      photos,
      taskState,
    );
    if (pagingState != _pagingState) {
      _pagingState = pagingState;
      final confirmed = _confirmedProjection.resolve(
        store.photosController.confirmedAlbum,
        store.worldCoverImageKeys,
      );
      final confirmedIds = {
        for (final photo in confirmed)
          _projection.aliases[photo.id] ?? photo.id,
      };
      final formalIds = store.album.map((photo) => photo.id).toSet();
      _confirmedPhotoCount = photos
          .where(
            (photo) =>
                confirmedIds.contains(photo.id) ||
                !formalIds.contains(photo.id),
          )
          .length;
      _fillViewport();
    }
    final state = (photos, store.accountGeneration, taskState);
    if (state == _listState) return false;
    final assets = {for (final photo in photos) photo.id: photo};
    _tiles.removeWhere((id, tile) => !identical(assets[id], tile.asset));
    _photos = photos;
    _taskRecords = taskRecords;
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
    if (_target != null || _viewportSize.width <= 0) return;
    final store = widget.store;
    final boundary =
        _previewExtent +
        ((_taskRecords.length + _confirmedPhotoCount + 2) ~/ 3) *
            (_viewportSize.width / 3);
    if (metrics.pixels + metrics.viewportDimension + 160 >= boundary) {
      _lists.loadNext('album', () => store.refreshAlbum(next: true));
    }
  }

  @override
  void initState() {
    super.initState();
    widget.tasks?.beginAlbumVisit();
    _target = widget.target;
    _targetGeneration = widget.store.accountGeneration;
    widget.previewJobs?.beginAlbumVisit();
    _sync();
    widget.store.addListener(_changed);
    widget.previewJobs?.addListener(_previewChanged);
    widget.tasks?.addListener(_changed);
    if (_target != null) unawaited(_loadTarget());
  }

  void _previewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MiniPhonePhotosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        widget.tasks?.beginAlbumVisit();
        _sync();
      } else {
        _cancelTarget();
        widget.tasks?.endAlbumVisit();
      }
    }
    if (oldWidget.previewJobs != widget.previewJobs) {
      oldWidget.previewJobs?.endAlbumVisit();
      widget.previewJobs?.beginAlbumVisit();
      oldWidget.previewJobs?.removeListener(_previewChanged);
      widget.previewJobs?.addListener(_previewChanged);
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_targetGeneration != widget.store.accountGeneration) {
      _cancelTarget();
      _anchors.clear();
      _successAssets.clear();
    }
    if (_sync()) setState(() {});
    _scheduleTarget();
  }

  @override
  void dispose() {
    _cancelTarget();
    widget.tasks?.endAlbumVisit();
    widget.tasks?.removeListener(_changed);
    widget.previewJobs?.endAlbumVisit();
    widget.store.removeListener(_changed);
    widget.previewJobs?.removeListener(_previewChanged);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    _scheduleTarget();
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
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _cancelTarget();
              }
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
                  if (widget.previewJobs != null)
                    CameraPreviewAlbumSliver(
                      jobs: widget.previewJobs!,
                      onUseInPost: widget.onUsePhotoInPost == null
                          ? null
                          : (asset) => widget.onUsePhotoInPost!(
                              asset,
                              AssetImage(asset),
                            ),
                    ),
                  SliverLayoutBuilder(
                    builder: (context, constraints) {
                      _previewExtent = constraints.precedingScrollExtent;
                      return SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < _taskRecords.length) {
                              final write = _taskRecords[index];
                              return CameraTaskAlbumTile(
                                key: ValueKey('camera-task-${write.id}'),
                                write: write,
                              );
                            }
                            final asset = photos[index - _taskRecords.length];
                            return (_tiles[asset.id] ??= (
                              asset: asset,
                              widget: _livePhotoTile(asset),
                            )).widget;
                          },
                          childCount: _taskRecords.length + photos.length,
                          findChildIndexCallback: (key) {
                            if (key is ValueKey<String>) {
                              final index = _taskRecords.indexWhere(
                                (w) => 'camera-task-${w.id}' == key.value,
                              );
                              return index < 0 ? null : index;
                            }
                            if (key is! ValueKey<int>) return null;
                            final index = photos.indexWhere(
                              (a) => a.id == key.value,
                            );
                            return index < 0
                                ? null
                                : index + _taskRecords.length;
                          },
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                            ),
                      );
                    },
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
        onImageLoaded: _scheduleTarget,
        placeholder: (_) => const ColoredBox(color: Color(0x1FFFFFFF)),
        errorWidget: (_, _) {
          _targetImageFailed(asset.id);
          return const ColoredBox(color: Color(0x1FFFFFFF));
        },
      );
      if (asset.image.trim().isEmpty) return image;
      return KeyedSubtree(
        key: ValueKey('mini-phone-album-${asset.id}'),
        child: GenesisImageViewerSourceAnchor(
          key: _anchors.putIfAbsent(
            asset.id,
            () => GlobalKey<GenesisImageViewerSourceAnchorState>(
              debugLabel: 'mini-phone-album-${asset.id}',
            ),
          ),
          previewImageProvider: preview,
          fit: BoxFit.cover,
          onTap: (source) => _openPhoto(asset, bounds.maxWidth, source),
          child: image,
        ),
      );
    },
  );
  Future<void> _openPhoto(
    PhoneAlbumAsset asset,
    double width,
    GenesisImageViewerSource source,
  ) async {
    _cancelTarget();
    final generation = widget.store.accountGeneration;
    final photos = _photos.where((p) => p.image.trim().isNotEmpty).toList();
    final index = photos.indexWhere((p) => p.id == asset.id);
    if (index < 0) {
      source.previewImage.dispose();
      return;
    }
    final previews = <ImageProvider<Object>>[
      for (final p in photos)
        miniPhonePhotoThumbnailProvider(
          p.image,
          width: width,
          height: width,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          fit: BoxFit.cover,
        ),
    ];
    previews[index] = source.previewImageProvider;
    int? postIndex;
    await showGenesisImageViewer(
      context,
      imageUrls: photos.map((p) => p.image).toList(),
      initialIndex: index,
      previewImageProviders: previews,
      onImageViewed: widget.store.analytics.photoViewer(),
      source: source,
      bottomBuilder: widget.onUsePhotoInPost == null
          ? null
          : (viewerContext, index) => Center(
              heightFactor: 1,
              child: GenesisPrimaryButton(
                label: viewerContext.l10n.miniPhoneCameraUseInPost,
                fullWidth: false,
                height: 40,
                fontSize: 14,
                onPressed: () {
                  if (postIndex != null ||
                      !(ModalRoute.isCurrentOf(viewerContext) ?? false)) {
                    return;
                  }
                  postIndex = index;
                  Navigator.pop(viewerContext);
                },
              ),
            ),
    );
    if (mounted &&
        generation == widget.store.accountGeneration &&
        postIndex != null) {
      widget.onUsePhotoInPost?.call(
        photos[postIndex!].image,
        previews[postIndex!],
      );
    }
  }
}
