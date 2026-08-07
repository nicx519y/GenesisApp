import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../world_map_contract.dart';
import 'tilemap_location_avatars.dart';

const Duration tilemapMessageBubbleDisplayDuration = Duration(seconds: 4);
const Duration tilemapMessageBubbleGapDuration = Duration(milliseconds: 500);

typedef TilemapMessageBubbleBuilder =
    Widget Function(BuildContext context, WorldMapMessageBubble? activeBubble);

class TilemapMessageBubblePlayback extends StatefulWidget {
  const TilemapMessageBubblePlayback({
    super.key,
    required this.messageBubbles,
    required this.visibleCharacterIds,
    required this.paused,
    this.frozen = false,
    required this.builder,
  });

  final List<WorldMapMessageBubble> messageBubbles;
  final Set<String> visibleCharacterIds;
  final bool paused;
  final bool frozen;
  final TilemapMessageBubbleBuilder builder;

  @override
  State<TilemapMessageBubblePlayback> createState() =>
      _TilemapMessageBubblePlaybackState();
}

class _TilemapMessageBubblePlaybackState
    extends State<TilemapMessageBubblePlayback> {
  Timer? _timer;
  List<WorldMapMessageBubble> _visibleBubbles = const <WorldMapMessageBubble>[];
  String _signature = '';
  int _bubbleIndex = 0;
  int _pageIndex = 0;
  bool _bubbleVisible = true;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant TilemapMessageBubblePlayback oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayback();
  }

  @override
  void deactivate() {
    _active = false;
    _stopTimer();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
    _syncPlayback();
  }

  @override
  void dispose() {
    _active = false;
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _activeBubble);
  }

  WorldMapMessageBubble? get _activeBubble {
    if (widget.paused || !_bubbleVisible || _visibleBubbles.isEmpty) {
      return null;
    }
    final bubble = _visibleBubbles[_bubbleIndex % _visibleBubbles.length];
    final pages = _messageBubblePages(bubble.content);
    if (pages.isEmpty) return null;
    return WorldMapMessageBubble(
      characterId: bubble.characterId,
      content: pages[_pageIndex % pages.length],
      preservePageWidth: _pageIndex > 0,
    );
  }

  void _syncPlayback() {
    final visibleIds = widget.visibleCharacterIds;
    final visibleBubbles = widget.messageBubbles
        .where(
          (bubble) =>
              visibleIds.contains(bubble.characterId.trim()) &&
              bubble.content.trim().isNotEmpty,
        )
        .toList(growable: false);
    final signature = _playbackSignature(visibleBubbles);

    _visibleBubbles = visibleBubbles;
    if (signature != _signature) {
      _signature = signature;
      _bubbleIndex = 0;
      _pageIndex = 0;
      _bubbleVisible = signature.isNotEmpty;
      _stopTimer();
    } else if (_bubbleIndex >= visibleBubbles.length) {
      _bubbleIndex = 0;
      _pageIndex = 0;
    }

    if (!_active || widget.paused || widget.frozen || signature.isEmpty) {
      _stopTimer();
      return;
    }
    _ensureTimer();
  }

  void _ensureTimer() {
    if (_timer != null ||
        !_active ||
        widget.paused ||
        widget.frozen ||
        _signature.isEmpty) {
      return;
    }
    _timer = Timer(
      _bubbleVisible
          ? tilemapMessageBubbleDisplayDuration
          : tilemapMessageBubbleGapDuration,
      () {
        _timer = null;
        if (!mounted ||
            !_active ||
            widget.paused ||
            widget.frozen ||
            _visibleBubbles.isEmpty) {
          return;
        }
        setState(() {
          if (_bubbleVisible) {
            final activeBubble =
                _visibleBubbles[_bubbleIndex % _visibleBubbles.length];
            final pageCount = _messageBubblePages(activeBubble.content).length;
            if (_pageIndex + 1 < pageCount) {
              _pageIndex += 1;
            } else {
              _bubbleVisible = false;
            }
          } else {
            _bubbleIndex = (_bubbleIndex + 1) % _visibleBubbles.length;
            _pageIndex = 0;
            _bubbleVisible = true;
          }
        });
        _ensureTimer();
      },
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  List<String> _messageBubblePages(String content) {
    return resolveWorldMapMessageBubblePages(context, content);
  }

  String _playbackSignature(List<WorldMapMessageBubble> bubbles) {
    return bubbles
        .map((bubble) => '${bubble.characterId.trim()}\u{1f}${bubble.content}')
        .join('\u{1e}');
  }
}

@visibleForTesting
List<String> tilemapMessageBubblePages(
  String content, {
  TextDirection textDirection = TextDirection.ltr,
  TextScaler? textScaler,
  TextStyle? textStyle,
}) {
  return splitWorldMapMessageBubblePages(
    content,
    textDirection: textDirection,
    textScaler: textScaler,
    textStyle: textStyle,
  );
}

Offset tilemapMessageBubbleAvatarTopLeft({
  required Offset locationBubbleAnchor,
  required int avatarIndex,
  required int avatarCount,
  double locationLabelVerticalOverflow = 0,
}) {
  return Offset(
    locationBubbleAnchor.dx -
        tilemapLocationAvatarGroupWidth / 2 +
        tilemapLocationAvatarLeft(avatarIndex, avatarCount),
    locationBubbleAnchor.dy +
        locationLabelVerticalOverflow +
        tilemapLocationLabelToAvatarSpacing +
        tilemapLocationAvatarTop(avatarIndex),
  );
}

class TilemapCharacterMessageBubble extends StatelessWidget {
  const TilemapCharacterMessageBubble({
    super.key,
    required this.text,
    required this.avatarTopLeft,
    required this.viewportWidth,
    required this.onTap,
    this.preservePageWidth = false,
  });

  static const double _bubbleGap = 8;
  static const double _pointerWidth = worldMapMessageBubblePointerWidth;
  static const double _pointerHeight = 10;
  static const double _viewportPadding = 8;

  final String text;
  final Offset avatarTopLeft;
  final double viewportWidth;
  final VoidCallback? onTap;
  final bool preservePageWidth;

  @override
  Widget build(BuildContext context) {
    final bubbleWidth = resolveWorldMapMessageBubbleWidth(
      context,
      text,
      preservePageWidth: preservePageWidth,
    );
    final avatarCenterX = avatarTopLeft.dx + tilemapLocationAvatarSize / 2;
    final maximumLeft = math.max(
      _viewportPadding,
      viewportWidth - bubbleWidth - _viewportPadding,
    );
    final viewportConstrainedLeft = (avatarCenterX - bubbleWidth / 2)
        .clamp(_viewportPadding, maximumLeft)
        .toDouble();
    final pointerLeft = (avatarCenterX - viewportConstrainedLeft)
        .clamp(bubbleWidth / 4, bubbleWidth * 3 / 4)
        .toDouble();
    final left = avatarCenterX - pointerLeft;

    return Positioned(
      left: left,
      top:
          avatarTopLeft.dy +
          tilemapLocationAvatarSize +
          _bubbleGap -
          _pointerHeight,
      width: bubbleWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              key: const ValueKey<String>(
                'tilemap-character-message-bubble-pointer',
              ),
              left: pointerLeft - _pointerWidth / 2,
              top: 0,
              width: _pointerWidth,
              height: _pointerHeight,
              child: CustomPaint(
                painter: const _TilemapMessageBubblePointerPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: _pointerHeight),
              child: SizedBox(
                key: const ValueKey<String>(
                  'tilemap-character-message-bubble-body',
                ),
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: worldMapMessageBubbleHorizontalPadding,
                      vertical: 9,
                    ),
                    child: Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.clip,
                      style: worldMapMessageBubbleTextStyle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TilemapMessageBubblePointerPainter extends CustomPainter {
  const _TilemapMessageBubblePointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_TilemapMessageBubblePointerPainter oldDelegate) => false;
}
