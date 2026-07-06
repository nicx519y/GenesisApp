import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_edge_swipe_back.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../utils/genesis_image_resource.dart';

class GenesisGenerationWaitAvatar {
  const GenesisGenerationWaitAvatar({required this.name, required this.url});

  final String name;
  final String url;
}

class GenesisGenerationWaitOverlay extends StatefulWidget {
  const GenesisGenerationWaitOverlay({
    super.key,
    this.title = 'AI is generating',
    this.message =
        'Generating a live and customized world for you.\n'
        'Please wait for a moment.',
    this.illustration,
    this.characterAvatars = const <GenesisGenerationWaitAvatar>[],
    this.perspectiveLines,
    this.animateTitleDots = true,
    this.onBackPressed,
    this.onBarrierTap,
  });

  static const double perspectiveContentHeight = 236;

  final String title;
  final String message;
  final Widget? illustration;
  final List<GenesisGenerationWaitAvatar> characterAvatars;
  final List<String>? perspectiveLines;
  final bool animateTitleDots;
  final VoidCallback? onBackPressed;
  final VoidCallback? onBarrierTap;

  @override
  State<GenesisGenerationWaitOverlay> createState() =>
      _GenesisGenerationWaitOverlayState();
}

class _GenesisGenerationWaitOverlayState
    extends State<GenesisGenerationWaitOverlay> {
  static const Duration _dotsInterval = Duration(milliseconds: 400);

  Timer? _dotsTimer;
  int _dotCount = 1;
  bool _allowRoutePop = false;

  @override
  void initState() {
    super.initState();
    _dotsTimer = Timer.periodic(_dotsInterval, (_) {
      if (!mounted) return;
      setState(() => _dotCount = _dotCount == 6 ? 1 : _dotCount + 1);
    });
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPerspectiveText = widget.perspectiveLines != null;
    final title = widget.animateTitleDots
        ? '${widget.title}${List.filled(_dotCount, '.').join()}'
        : widget.title;
    final Widget waitBody;
    if (widget.perspectiveLines case final lines?) {
      waitBody = _PerspectiveWaitText(
        key: const ValueKey('create-worldo-wait-perspective-text'),
        illustration: widget.illustration,
        lines: lines,
      );
    } else {
      final bodyChildren = <Widget>[];
      if (widget.characterAvatars.isNotEmpty) {
        bodyChildren.add(
          Center(
            child: GenerationAvatarCarousel(avatars: widget.characterAvatars),
          ),
        );
        bodyChildren.add(const SizedBox(height: 18));
      }
      if (widget.illustration != null) {
        bodyChildren.add(
          Center(
            child: SizedBox(
              width: 152,
              height: 112,
              child: widget.illustration,
            ),
          ),
        );
        bodyChildren.add(const SizedBox(height: 14));
      }
      bodyChildren.add(
        Text(
          widget.message,
          textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
      );
      waitBody = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: bodyChildren,
      );
    }

    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackRequest();
      },
      child: GenesisEdgeSwipeBack(
        onBack: _handleBackRequest,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onBarrierTap,
          child: ColoredBox(
            color: const Color(0x8A000000),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned(
                      top: constraints.maxHeight * 0.25,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {},
                          child: AlertDialog(
                            key: const ValueKey('world-tick1-wait-dialog'),
                            backgroundColor: const Color(0xFFFFFFFF),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            titlePadding: EdgeInsets.zero,
                            contentPadding: EdgeInsets.fromLTRB(
                              10,
                              16,
                              10,
                              hasPerspectiveText ? 0 : 16,
                            ),
                            content: SizedBox(
                              width: 292,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    title,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  waitBody,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackRequest() {
    final onBackPressed = widget.onBackPressed;
    if (onBackPressed == null) return;
    if (!_allowRoutePop && mounted) {
      setState(() => _allowRoutePop = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        onBackPressed();
      });
    });
  }
}

class GenerationAvatarCarousel extends StatefulWidget {
  const GenerationAvatarCarousel({
    super.key,
    required this.avatars,
    this.size = 88,
  });

  final List<GenesisGenerationWaitAvatar> avatars;
  final double size;

  @override
  State<GenerationAvatarCarousel> createState() =>
      _GenerationAvatarCarouselState();
}

class _GenerationAvatarCarouselState extends State<GenerationAvatarCarousel> {
  static const Duration _interval = Duration(milliseconds: 1800);
  static const Duration _switchDuration = Duration(milliseconds: 420);

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant GenerationAvatarCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatars.length != widget.avatars.length) {
      _index = _normalizedIndex(_index);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.avatars.length < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.avatars.length);
    });
  }

  int _normalizedIndex(int value) {
    if (widget.avatars.isEmpty) return 0;
    return value.clamp(0, widget.avatars.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.avatars.isEmpty) return const SizedBox.shrink();
    final avatar = widget.avatars[_normalizedIndex(_index)];
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedSwitcher(
        duration: _switchDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(0.42, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: _LaunchWaitAvatar(
          key: ValueKey<String>(
            'launch-wait-avatar-${avatar.name}|${avatar.url}',
          ),
          avatar: avatar,
          size: widget.size,
        ),
      ),
    );
  }
}

class _LaunchWaitAvatar extends StatelessWidget {
  const _LaunchWaitAvatar({
    super.key,
    required this.avatar,
    required this.size,
  });

  final GenesisGenerationWaitAvatar avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = selectGenesisImageUrl(
      avatar.url,
      logicalWidth: size,
      logicalHeight: size,
      devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    ).trim();
    final fallback = GenesisAvatarFallback(
      name: avatar.name,
      width: size,
      height: size,
      borderRadius: GenesisAvatarRadii.character,
    );

    final Widget image;
    if (resolvedUrl.isEmpty) {
      image = fallback;
    } else if (resolvedUrl.startsWith('assets/')) {
      image = Image.asset(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else {
      image = Image.network(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(GenesisAvatarRadii.character),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

class _PerspectiveWaitText extends StatefulWidget {
  const _PerspectiveWaitText({
    super.key,
    this.illustration,
    required this.lines,
  });

  final Widget? illustration;
  final List<String> lines;

  @override
  State<_PerspectiveWaitText> createState() => _PerspectiveWaitTextState();
}

class _PerspectiveWaitTextState extends State<_PerspectiveWaitText>
    with SingleTickerProviderStateMixin {
  static const double _height =
      GenesisGenerationWaitOverlay.perspectiveContentHeight;
  static const double _filmHeight = 900;
  static const double _scrollDistance = 960;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 37000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines.where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const SizedBox.shrink();

    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.black,
          ],
          stops: [0.0, 0.06, 0.94, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SizedBox(
        height: _height,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final y = _height - (_controller.value * _scrollDistance);
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0050)
                ..rotateX(-0.34);
              return Transform(
                alignment: Alignment.bottomCenter,
                transform: transform,
                child: SizedBox(
                  height: _height,
                  child: Transform.translate(
                    offset: Offset(0, y),
                    child: OverflowBox(
                      minHeight: 0,
                      maxHeight: _filmHeight,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 292,
                        height: _filmHeight,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.illustration != null) ...[
                                Center(
                                  child: SizedBox(
                                    width: 152,
                                    height: 88,
                                    child: widget.illustration,
                                  ),
                                ),
                                const SizedBox(height: 22),
                              ],
                              for (
                                var index = 0;
                                index < lines.length;
                                index++
                              ) ...[
                                Text(
                                  lines[index],
                                  softWrap: true,
                                  textAlign: TextAlign.justify,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.32,
                                    color: Color(0xFF2A2F33),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (index != lines.length - 1)
                                  const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
