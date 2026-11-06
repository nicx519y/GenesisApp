import 'package:flutter/material.dart';

import '../../../components/common/genesis_image_viewer_overlay.dart';
import '../../../l10n/genesis_localizations.dart';
import '../shared/mini_phone_ui.dart';
import '../../../ui/components/genesis_primary_button.dart';
import '../../../ui/tokens/genesis_typography.dart';
import 'mini_phone_camera_preview_jobs.dart';

/// Separate local preview section; never merged into the server asset list.
class CameraPreviewAlbumSliver extends StatelessWidget {
  const CameraPreviewAlbumSliver({
    super.key,
    required this.jobs,
    this.onUseInPost,
  });
  final MiniPhoneCameraPreviewJobs jobs;
  final ValueChanged<String>? onUseInPost;

  @override
  Widget build(BuildContext context) {
    if (jobs.tasks.isEmpty) return const SliverToBoxAdapter();
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.miniPhoneCameraPreviewNotice,
              style: miniStyle(12, FontWeight.w400, miniSecondary),
            ),
          ),
        ),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final task = jobs.tasks[index];
            return _TaskTile(
              key: ValueKey('camera-preview-task-${task.id}'),
              task: task,
              jobs: jobs,
              onUseInPost: onUseInPost,
            );
          }, childCount: jobs.tasks.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    super.key,
    required this.task,
    required this.jobs,
    this.onUseInPost,
  });
  final CameraPreviewTask task;
  final MiniPhoneCameraPreviewJobs jobs;
  final ValueChanged<String>? onUseInPost;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final success = task.state == CameraPreviewTaskState.succeeded;
    final failed = task.state == CameraPreviewTaskState.failed;
    final label = success
        ? l10n.miniPhoneCameraOpenPhoto
        : failed
        ? l10n.miniPhoneCameraFailureRefund
        : l10n.miniPhoneCameraCreatingPhoto;
    return Semantics(
      label: '$label. ${task.request.prompt}',
      button: success,
      child: Material(
        color: miniRaised,
        child: success
            ? GenesisImageViewerSourceAnchor(
                previewImageProvider: AssetImage(task.sampleAsset),
                fit: BoxFit.cover,
                onTap: (source) async {
                  final complete = jobs.tasks
                      .where((t) => t.state == CameraPreviewTaskState.succeeded)
                      .toList();
                  final index = complete.indexOf(task);
                  jobs.markViewed(task.id);
                  String? postAsset;
                  await showGenesisImageViewer(
                    context,
                    source: source,
                    imageUrls: complete.map((t) => t.sampleAsset).toList(),
                    initialIndex: index,
                    onImageViewed: (index) =>
                        jobs.markViewed(complete[index].id),
                    bottomBuilder: (viewerContext, index) => Center(
                      heightFactor: 1,
                      child: GenesisPrimaryButton(
                        key: const ValueKey('camera-photo-use-in-post'),
                        label: viewerContext.l10n.miniPhoneCameraUseInPost,
                        onPressed: onUseInPost == null
                            ? null
                            : () {
                                postAsset = complete[index].sampleAsset;
                                Navigator.of(viewerContext).pop();
                              },
                        fullWidth: false,
                        height: 40,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        backgroundColor: miniRaised,
                        foregroundColor: miniSecondary,
                        side: const BorderSide(color: miniLine),
                      ),
                    ),
                  );
                  if (context.mounted && postAsset != null) {
                    onUseInPost?.call(postAsset!);
                  }
                },
                child: _tileContent(context, success, failed),
              )
            : _tileContent(context, success, failed),
      ),
    );
  }

  Widget _tileContent(BuildContext context, bool success, bool failed) {
    final l10n = context.l10n;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (success) Image.asset(task.sampleAsset, fit: BoxFit.cover),
        if (failed)
          DecoratedBox(
            key: const ValueKey('camera-preview-failed-card'),
            decoration: BoxDecoration(
              color: miniRaised,
              border: Border.all(color: miniRed.withValues(alpha: .25)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    size: 20,
                    color: miniRed,
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      l10n.miniPhoneCameraFailureRefund,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GenesisTypography.supporting.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: miniSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!success && !failed)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: miniWhite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      l10n.miniPhoneCameraCreatingPhoto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (success && !task.viewed)
          const Positioned(
            top: 7,
            right: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(color: miniRed, shape: BoxShape.circle),
              child: SizedBox.square(dimension: 7),
            ),
          ),
      ],
    );
  }
}

class CameraPreviewAlbumThumbnail extends StatelessWidget {
  const CameraPreviewAlbumThumbnail({
    super.key,
    required this.jobs,
    required this.fallback,
  });
  final MiniPhoneCameraPreviewJobs jobs;
  final Widget fallback;
  @override
  Widget build(BuildContext context) {
    final result = jobs.latestResult;
    return Stack(
      fit: StackFit.expand,
      children: [
        result == null
            ? fallback
            : Image.asset(result.sampleAsset, fit: BoxFit.cover),
        if (jobs.pendingCount > 0)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: miniWhite,
                  ),
                ),
              ),
            ),
          ),
        if (jobs.unreadCount > 0)
          const Positioned(
            top: 4,
            right: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(color: miniRed, shape: BoxShape.circle),
              child: SizedBox.square(dimension: 7),
            ),
          ),
      ],
    );
  }
}
