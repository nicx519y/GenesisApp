import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_services_scope.dart';
import '../../../components/common/genesis_center_toast.dart';
import '../../../l10n/genesis_localizations.dart';
import '../../../network/api_exception.dart';
import '../../../network/models/music.dart';
import '../../../utils/stat_count_formatter.dart';
import '../shared/mini_phone_ui.dart';
import 'mini_phone_music_service.dart';

/// Shared by the full player and Home; the entire badge is one tap target.
class MiniMusicLikeButton extends StatelessWidget {
  const MiniMusicLikeButton({
    super.key,
    required this.music,
    required this.track,
  });

  final MiniPhoneMusicService music;
  final MusicTrack track;

  Future<void> _toggle(BuildContext context) async {
    final api = AppServicesScope.read(context).api;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final fallback = context.l10n.miniPhoneMusicLikeFailed;
    music.trackLike(track.file, !music.likes.isLiked(track.file));
    try {
      await music.likes.toggle(
        track.file,
        (liked) => liked
            ? api.likeMusic(file: track.file)
            : api.unlikeMusic(file: track.file),
      );
    } catch (error) {
      if (overlay != null && overlay.mounted) {
        showGenesisToastInOverlay(
          overlay,
          error is ApiException ? error.message : fallback,
          brightness: Brightness.dark,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: music.likes,
    builder: (context, _) {
      final liked = music.likes.isLiked(track.file);
      final count = music.likes.likeCount(track.file);
      final color = liked ? miniPink : miniWhite;
      final countLabel = count > 0 ? formatStatCount(count) : '';
      final countStyle = miniStyle(
        11,
        FontWeight.w600,
        color,
      ).copyWith(height: 1);
      double countWidth = 0;
      if (count > 0) {
        final measurement = TextPainter(
          text: TextSpan(text: countLabel, style: countStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final scale = (13 / measurement.height).clamp(0.0, 1.0);
        countWidth = (measurement.width * scale).clamp(8.0, 52.0);
        measurement.dispose();
      }
      final label = liked
          ? context.l10n.miniPhoneUnlikeTrack(title: track.title)
          : context.l10n.miniPhoneLikeTrack(title: track.title);
      return Semantics(
        button: true,
        toggled: liked,
        label: label,
        value: '$count',
        onTap: () => unawaited(_toggle(context)),
        child: ExcludeSemantics(
          child: IconButton(
            tooltip: label,
            onPressed: () => unawaited(_toggle(context)),
            constraints: const BoxConstraints.tightFor(width: 88, height: 48),
            padding: const EdgeInsets.only(right: 16),
            icon: SizedBox(
              width: 72,
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: count > 0 ? 20 + countWidth : 28,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipPath(
                        clipper: count > 0 ? const _HeartCountClipper() : null,
                        child: MiniIcon('heart', size: 28, color: color),
                      ),
                      if (count > 0)
                        Positioned(
                          left: 20,
                          top: 0,
                          width: countWidth,
                          height: 13,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topRight,
                            child: Text(
                              countLabel,
                              key: const ValueKey('mini-music-like-count'),
                              maxLines: 1,
                              style: countStyle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Remove the contour behind the count without painting over the Home glass.
class _HeartCountClipper extends CustomClipper<Path> {
  const _HeartCountClipper();

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()..addRect(Rect.fromLTRB(18, 0, size.width, 14)),
  );

  @override
  bool shouldReclip(_HeartCountClipper oldClipper) => false;
}
