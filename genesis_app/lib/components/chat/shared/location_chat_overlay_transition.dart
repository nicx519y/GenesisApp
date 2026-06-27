import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LocationChatOverlayTransition extends StatefulWidget {
  const LocationChatOverlayTransition({
    super.key,
    required this.active,
    required this.child,
    this.maintainChildOnDismiss = false,
    this.onDismissed,
  });

  final bool active;
  final Widget? child;
  final bool maintainChildOnDismiss;
  final VoidCallback? onDismissed;

  @override
  State<LocationChatOverlayTransition> createState() =>
      _LocationChatOverlayTransitionState();
}

class _LocationChatOverlayTransitionState
    extends State<LocationChatOverlayTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _cupertinoFadeAnimation;
  late final PageRoute<void> _route;
  Widget? _displayChild;

  @override
  void initState() {
    super.initState();
    _route = _LocationChatOverlayPageRoute();
    _displayChild = widget.child;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
      value: widget.active ? 1 : 0,
    );
    _cupertinoFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final builder = _pageTransitionsBuilderFor(context);
    _controller.duration = builder.transitionDuration;
    _controller.reverseDuration = builder.reverseTransitionDuration;
  }

  @override
  void didUpdateWidget(LocationChatOverlayTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null && widget.child != _displayChild) {
      _displayChild = widget.child;
    }
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _controller.forward();
      return;
    }
    _controller.reverse().then((_) {
      if (!mounted || widget.active || !_controller.isDismissed) return;
      if (!widget.maintainChildOnDismiss) {
        setState(() => _displayChild = null);
      }
      widget.onDismissed?.call();
    });
  }

  @override
  void dispose() {
    _cupertinoFadeAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _displayChild;
    if (child == null && !widget.active && _controller.value <= 0) {
      return const SizedBox.shrink();
    }
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final transition = isCupertino
        ? FadeTransition(
            opacity: _cupertinoFadeAnimation,
            child: CupertinoPageTransition(
              primaryRouteAnimation: _controller,
              secondaryRouteAnimation: const AlwaysStoppedAnimation<double>(0),
              linearTransition: false,
              child: child ?? const SizedBox.shrink(),
            ),
          )
        : Theme.of(context).pageTransitionsTheme.buildTransitions<void>(
            _route,
            context,
            _controller,
            const AlwaysStoppedAnimation<double>(0),
            child ?? const SizedBox.shrink(),
          );
    return IgnorePointer(
      ignoring: !widget.active,
      child: ExcludeSemantics(excluding: !widget.active, child: transition),
    );
  }
}

class _LocationChatOverlayPageRoute extends PageRoute<void> {
  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  bool get popGestureEnabled => false;

  @override
  bool get popGestureInProgress => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return const SizedBox.shrink();
  }
}

PageTransitionsBuilder _pageTransitionsBuilderFor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.pageTransitionsTheme.builders[theme.platform] ??
      const ZoomPageTransitionsBuilder();
}
