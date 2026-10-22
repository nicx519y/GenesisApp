part of 'app_launch_transition.dart';

class AppLaunchTransitionHost extends StatefulWidget {
  const AppLaunchTransitionHost({
    super.key,
    required this.controller,
    required this.home,
    required this.page,
    required this.surfaceColor,
    required this.onDismissed,
    this.pageHasTransparentBackground = false,
    this.enableCloseGesture = false,
    this.closeGestureFallbackSourceId,
    this.spec = const AppLaunchTransitionSpec(),
  });

  final AppLaunchTransitionController controller;
  final Widget home;
  final Widget? page;
  final Color surfaceColor;
  final VoidCallback onDismissed;

  /// Keep the single home surface painted behind a transparent page (for
  /// example a Navigator's empty desktop route during an iOS back gesture).
  /// Home input, focus, semantics and tickers remain disabled while open.
  final bool pageHasTransparentBackground;

  /// Opt-in leading-edge drag, using the same geometry as [controller.close].
  final bool enableCloseGesture;
  final Object? closeGestureFallbackSourceId;
  final AppLaunchTransitionSpec spec;

  @override
  State<AppLaunchTransitionHost> createState() =>
      _AppLaunchTransitionHostState();
}

class _AppLaunchTransitionHostState extends State<AppLaunchTransitionHost>
    with SingleTickerProviderStateMixin {
  final _homeKey = GlobalKey();
  final _sources = <Object, _AppLaunchSourceState>{};
  late final AnimationController _animation;
  _LaunchGeometry? _geometry;
  Object? _launchSource;
  bool _reducedMotion = false;
  Size? _size;
  bool _settleScheduled = false;
  bool _interactiveClosing = false;
  double _closeDragDistance = 0;
  AppLaunchTransitionController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    assert(_controller._host == null, 'A controller can attach to one host.');
    _controller._host = this;
    _animation = AnimationController(
      vsync: this,
      value: _controller.hasPage ? 1 : 0,
      duration: widget.spec.openDuration,
      reverseDuration: widget.spec.closeDuration,
    )..addStatusListener(_animationStatus);
  }

  @override
  void didUpdateWidget(AppLaunchTransitionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      oldWidget.controller == widget.controller,
      'Keep the controller stable for the lifetime of the host.',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion && _controller.isAnimating) _scheduleFinish();
  }

  void _scheduleFinish() {
    if (_settleScheduled) return;
    _settleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleScheduled = false;
      if (mounted) _finish();
    });
  }

  /// Measure against the untransformed home plane, not the scaled background.
  /// Reject origins clipped by a pager/scroll view, even when still mounted.
  _LaunchGeometry? _measure(Object? id) {
    final source = _sources[id];
    final home = _homeKey.currentContext?.findRenderObject();
    final box = source?.context.findRenderObject();
    if (source == null ||
        home is! RenderBox ||
        box is! RenderBox ||
        !home.hasSize ||
        !box.hasSize ||
        !box.attached) {
      return null;
    }
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(home),
      Offset.zero & box.size,
    );
    if (rect.isEmpty || !rect.isFinite) return null;
    var visible = Offset.zero & home.size;
    RenderObject child = box;
    while (child != home) {
      final parent = child.parent;
      if (parent == null) return null;
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        visible = visible.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(home), clip),
        );
      }
      child = parent;
    }
    if (!visible.inflate(.5).contains(rect.topLeft) ||
        !visible.inflate(.5).contains(rect.bottomRight)) {
      return null;
    }
    return _LaunchGeometry(
      source.widget.id,
      rect,
      source.widget.borderRadius,
      source.widget.preview,
      source.widget.surfaceColor,
    );
  }

  bool _open(Object? id) {
    if (_controller.hasPage) return false;
    _launchSource = id;
    _geometry = _measure(id);
    _animation.duration = _geometry == null
        ? widget.spec.fadeDuration
        : widget.spec.openDuration;
    _animation.reverseDuration = widget.spec.closeDuration;
    _controller._setStatus(AppLaunchTransitionStatus.opening);
    setState(() {});
    if (_reducedMotion) {
      _finish();
    } else {
      _animation.forward(from: 0);
    }
    return true;
  }

  bool _close(Object? fallback) {
    if (!_controller.hasPage ||
        _controller.status == AppLaunchTransitionStatus.closing) {
      return false;
    }
    // Mid-flight reversal keeps exactly the same path and current progress.
    if (_controller.status != AppLaunchTransitionStatus.opening) {
      _geometry = _launchSource == null
          ? null
          : (_measure(_launchSource) ?? _measure(fallback));
    }
    _animation.reverseDuration = _geometry == null
        ? widget.spec.fadeDuration
        : widget.spec.closeDuration;
    _controller._setStatus(AppLaunchTransitionStatus.closing);
    setState(() {});
    if (_reducedMotion || _animation.value == 0) {
      _finish();
    } else {
      _animation.reverse();
    }
    return true;
  }

  double get _closeDragDirection =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _startCloseDrag(DragStartDetails details) {
    if (_controller.status != AppLaunchTransitionStatus.open ||
        (_size?.width ?? 0) <= 0) {
      return;
    }
    _geometry = _launchSource == null
        ? null
        : (_measure(_launchSource) ??
              _measure(widget.closeGestureFallbackSourceId));
    _animation.reverseDuration = _geometry == null
        ? widget.spec.fadeDuration
        : widget.spec.closeDuration;
    _interactiveClosing = true;
    _closeDragDistance = 0;
    _controller._setStatus(AppLaunchTransitionStatus.closing);
    setState(() {});
  }

  void _updateCloseDrag(DragUpdateDetails details) {
    if (!_interactiveClosing || (_size?.width ?? 0) <= 0) return;
    _closeDragDistance =
        (_closeDragDistance + details.delta.dx * _closeDragDirection).clamp(
          0.0,
          _size!.width,
        );
    // Do not dismiss before the finger is lifted, even at the far edge.
    _animation.value = _reducedMotion
        ? 1
        : (1 - _closeDragDistance / _size!.width).clamp(.001, 1.0);
  }

  void _endCloseDrag(DragEndDetails details) {
    final velocity = (details.primaryVelocity ?? 0) * _closeDragDirection;
    _settleCloseDrag(
      velocity > 700 ||
          (velocity >= -700 && _closeDragDistance >= (_size?.width ?? 0) * .35),
    );
  }

  void _settleCloseDrag(bool dismiss) {
    if (!mounted || !_interactiveClosing) return;
    _interactiveClosing = false;
    _controller._setStatus(
      dismiss
          ? AppLaunchTransitionStatus.closing
          : AppLaunchTransitionStatus.opening,
    );
    if (_reducedMotion) {
      _finish();
    } else if (dismiss) {
      _animation.reverse();
    } else if (_animation.value == 1) {
      _controller._setStatus(AppLaunchTransitionStatus.open);
    } else {
      _animation.forward();
    }
    setState(() {});
  }

  void _animationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _controller.status == AppLaunchTransitionStatus.opening) {
      _controller._setStatus(AppLaunchTransitionStatus.open);
      setState(() {});
    } else if (status == AnimationStatus.dismissed &&
        _controller.status == AppLaunchTransitionStatus.closing) {
      _dismiss();
    }
  }

  void _dismiss() {
    _interactiveClosing = false;
    _geometry = null;
    _launchSource = null;
    _controller._setStatus(AppLaunchTransitionStatus.home);
    setState(() {});
    widget.onDismissed();
  }

  void _finish() {
    if (!_controller.isAnimating) return;
    _interactiveClosing = false;
    final closing = _controller.status == AppLaunchTransitionStatus.closing;
    _animation.stop();
    _animation.value = closing ? 0 : 1;
    // Assigning an already-zero value does not always emit a status change.
    if (closing && _controller.hasPage) _dismiss();
    if (!closing && _controller.status == AppLaunchTransitionStatus.opening) {
      _controller._setStatus(AppLaunchTransitionStatus.open);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _interactiveClosing = false;
    _controller._host = null;
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (_size != null && _size != size && _controller.isAnimating) {
        _scheduleFinish();
      }
      _size = size;
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final animating = _controller.isAnimating;
          final progress = widget.spec.curve.transform(_animation.value);
          final hasPage = _controller.hasPage;
          final geometry = _geometry;
          final fullRect = Offset.zero & size;
          final rect = geometry == null
              ? fullRect
              : Rect.lerp(geometry.rect, fullRect, progress)!;
          final contentOpacity = geometry == null
              ? progress
              : ((progress - .12) / .38).clamp(0.0, 1.0);
          return _AppLaunchScope(
            host: this,
            hiddenSource: animating && geometry?.preview != null
                ? geometry?.id
                : null,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Offstage(
                    offstage:
                        hasPage &&
                        !animating &&
                        !widget.pageHasTransparentBackground,
                    child: TickerMode(
                      enabled: !hasPage,
                      child: ExcludeFocus(
                        excluding: hasPage,
                        child: ExcludeSemantics(
                          excluding: hasPage,
                          child: IgnorePointer(
                            ignoring: hasPage,
                            child: Transform.scale(
                              scale:
                                  _reducedMotion ||
                                      geometry == null ||
                                      (widget.pageHasTransparentBackground &&
                                          !animating)
                                  ? 1
                                  : 1 - (1 - widget.spec.homeScale) * progress,
                              child: RepaintBoundary(
                                key: _homeKey,
                                child: widget.home,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (animating && !_reducedMotion)
                    IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: widget.spec.homeDim * progress,
                        ),
                      ),
                    ),
                  if (hasPage)
                    Positioned.fromRect(
                      key: const ValueKey('app-launch-surface'),
                      rect: rect,
                      child: IgnorePointer(
                        ignoring: animating,
                        child: ExcludeSemantics(
                          excluding: animating,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              (geometry?.radius ?? 0) * (1 - progress),
                            ),
                            child: Opacity(
                              opacity: geometry == null ? progress : 1,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ColoredBox(
                                    color:
                                        widget.pageHasTransparentBackground &&
                                            !animating
                                        ? Colors.transparent
                                        : Color.lerp(
                                            geometry?.color ??
                                                widget.surfaceColor,
                                            widget.surfaceColor,
                                            progress,
                                          )!,
                                  ),
                                  if (geometry?.preview != null &&
                                      progress < .5)
                                    Opacity(
                                      opacity: (1 - progress / .5).clamp(0, 1),
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: SizedBox.fromSize(
                                          size: geometry!.rect.size,
                                          child: geometry.preview,
                                        ),
                                      ),
                                    ),
                                  // Fixed constraints preserve the page's layout
                                  // and State throughout both directions.
                                  OverflowBox(
                                    minWidth: size.width,
                                    maxWidth: size.width,
                                    minHeight: size.height,
                                    maxHeight: size.height,
                                    child: Transform.scale(
                                      scale: math.max(
                                        rect.width / size.width,
                                        rect.height / size.height,
                                      ),
                                      child: Opacity(
                                        opacity: geometry == null
                                            ? 1
                                            : contentOpacity,
                                        child: RepaintBoundary(
                                          child: ExcludeFocus(
                                            excluding: animating,
                                            child:
                                                widget.page ??
                                                const SizedBox.shrink(),
                                          ),
                                        ),
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
                  if (hasPage && widget.enableCloseGesture)
                    PositionedDirectional(
                      key: const ValueKey('app-launch-close-gesture'),
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width:
                          20 +
                          (Directionality.of(context) == TextDirection.rtl
                              ? MediaQuery.paddingOf(context).right
                              : MediaQuery.paddingOf(context).left),
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        // DragGestureRecognizer treats an accepted pointer's
                        // cancellation as an end. Catch it before that callback
                        // so a system interruption cannot commit a dismissal.
                        onPointerCancel: (_) => _settleCloseDrag(false),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          dragStartBehavior: DragStartBehavior.down,
                          onHorizontalDragStart: _startCloseDrag,
                          onHorizontalDragUpdate: _updateCloseDrag,
                          onHorizontalDragEnd: _endCloseDrag,
                          onHorizontalDragCancel: () => _settleCloseDrag(false),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
