part of 'app_launch_transition.dart';

/// Registers a visual launch origin without changing its gestures or semantics.
/// [preview] must be a presentation-only widget (e.g. an icon), not a second
/// instance of an interactive page, media player, or network-loading card.
class AppLaunchSource extends StatefulWidget {
  const AppLaunchSource({
    super.key,
    required this.id,
    required this.child,
    required this.borderRadius,
    this.preview,
    this.surfaceColor,
  });

  final Object id;
  final Widget child;
  final double borderRadius;
  final Widget? preview;
  final Color? surfaceColor;

  @override
  State<AppLaunchSource> createState() => _AppLaunchSourceState();
}

class _AppLaunchSourceState extends State<AppLaunchSource> {
  _AppLaunchTransitionHostState? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = _AppLaunchScope.of(context).host;
    if (_host == host) return;
    _unregister();
    _host = host;
    host._sources[widget.id] = this;
  }

  @override
  void didUpdateWidget(AppLaunchSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id == widget.id) return;
    if (_host?._sources[oldWidget.id] == this) {
      _host?._sources.remove(oldWidget.id);
    }
    _host?._sources[widget.id] = this;
  }

  void _unregister() {
    if (_host?._sources[widget.id] == this) {
      _host?._sources.remove(widget.id);
    }
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _AppLaunchScope.of(context).hiddenSource == widget.id;
    return Opacity(opacity: hidden ? 0 : 1, child: widget.child);
  }
}

class _AppLaunchScope extends InheritedWidget {
  const _AppLaunchScope({
    required this.host,
    required this.hiddenSource,
    required super.child,
  });

  final _AppLaunchTransitionHostState host;
  final Object? hiddenSource;

  static _AppLaunchScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppLaunchScope>()!;

  @override
  bool updateShouldNotify(_AppLaunchScope oldWidget) =>
      host != oldWidget.host || hiddenSource != oldWidget.hiddenSource;
}

class _LaunchGeometry {
  const _LaunchGeometry(
    this.id,
    this.rect,
    this.radius,
    this.preview,
    this.color,
  );
  final Object id;
  final Rect rect;
  final double radius;
  final Widget? preview;
  final Color? color;
}
