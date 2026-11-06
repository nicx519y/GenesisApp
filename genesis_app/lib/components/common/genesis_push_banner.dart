import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_blur.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../chat/shared/chat_scene_plate_tokens.dart';

const genesisPushBannerDisplayDuration = Duration(seconds: 5);
const genesisPushBannerTransitionDuration = Duration(milliseconds: 220);

/// Shared surface for World updates and photo generation results.
class GenesisPushBanner extends StatelessWidget {
  const GenesisPushBanner({
    super.key,
    required this.title,
    required this.detail,
    required this.semanticsLabel,
    this.leading,
    this.onTap,
  });

  final String title;
  final Widget detail;
  final String semanticsLabel;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: semanticsLabel,
    child: DecoratedBox(
      key: const ValueKey<String>('genesis-push-shadow'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          key: const ValueKey<String>('genesis-push-backdrop-blur'),
          filterConfig: const ImageFilterConfig.blur(
            sigmaX: GenesisBlur.strong,
            sigmaY: GenesisBlur.strong,
            bounded: false,
          ),
          child: Material(
            key: const ValueKey<String>('genesis-push-banner'),
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey<String>('genesis-push-tap-target'),
              canRequestFocus: false,
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  leading == null ? 16 : 8,
                  8,
                  12,
                  8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GenesisTypography.supporting.copyWith(
                                color: GenesisColors.darkTextSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            DefaultTextStyle(
                              style: GenesisTypography.bodyStrong.copyWith(
                                color: GenesisColors.darkTextPrimary,
                                height: 1.25,
                              ),
                              child: detail,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class GenesisPushBannerTransition extends StatelessWidget {
  const GenesisPushBannerTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1.2),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

/// Lets the owning session remove its banner when it ends or goes background.
class GenesisPushBannerHandle {
  GenesisPushBannerHandle._();

  final _closed = Completer<void>();
  OverlayEntry? _entry;
  Future<void> get closed => _closed.future;

  void dismiss() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
    entry.dispose();
    _closed.complete();
  }
}

/// Displays above nested routes, without a modal barrier or navigation changes.
GenesisPushBannerHandle showGenesisPushBanner({
  required BuildContext context,
  required String title,
  required String message,
  Duration displayDuration = genesisPushBannerDisplayDuration,
  Duration transitionDuration = genesisPushBannerTransitionDuration,
}) {
  final handle = GenesisPushBannerHandle._();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: kLocationChatOuterPadding,
      right: kLocationChatOuterPadding,
      top: MediaQuery.paddingOf(context).top + 8,
      child: _GenesisPushBannerOverlay(
        title: title,
        message: message,
        displayDuration: displayDuration,
        transitionDuration: transitionDuration,
        onDismissed: handle.dismiss,
      ),
    ),
  );
  handle._entry = entry;
  Overlay.of(context, rootOverlay: true).insert(entry);
  return handle;
}

class _GenesisPushBannerOverlay extends StatefulWidget {
  const _GenesisPushBannerOverlay({
    required this.title,
    required this.message,
    required this.displayDuration,
    required this.transitionDuration,
    required this.onDismissed,
  });

  final String title, message;
  final Duration displayDuration, transitionDuration;
  final VoidCallback onDismissed;

  @override
  State<_GenesisPushBannerOverlay> createState() =>
      _GenesisPushBannerOverlayState();
}

class _GenesisPushBannerOverlayState extends State<_GenesisPushBannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
    _timer = Timer(widget.displayDuration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GenesisPushBannerTransition(
    animation: _animation,
    child: GenesisPushBanner(
      title: widget.title,
      detail: Text(widget.message),
      semanticsLabel: '${widget.title}: ${widget.message}',
      onTap: _dismiss,
    ),
  );
}
