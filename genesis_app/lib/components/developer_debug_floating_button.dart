import 'package:flutter/material.dart';

import '../app/debug_floating_button_visibility.dart';
import '../pages/me/developer_page.dart';
import 'common/genesis_modal_routes.dart';

class DeveloperDebugFloatingButton extends StatefulWidget {
  const DeveloperDebugFloatingButton({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<DeveloperDebugFloatingButton> createState() =>
      _DeveloperDebugFloatingButtonState();
}

class _DeveloperDebugFloatingButtonState
    extends State<DeveloperDebugFloatingButton> {
  static const double _buttonSize = 42;
  static const double _edgePadding = 8;

  Offset? _position;
  bool _dragging = false;
  bool _movedDuringGesture = false;
  bool _sheetOpen = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: genesisDebugFloatingButtonVisible,
      builder: (context, visible, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final bottomPadding = MediaQuery.paddingOf(context).bottom;
            final defaultPosition = Offset(
              (size.width - _buttonSize - _edgePadding).clamp(0.0, size.width),
              (size.height - _buttonSize - bottomPadding - 86).clamp(
                0.0,
                size.height,
              ),
            );
            final position = _clampPosition(_position ?? defaultPosition, size);

            return Stack(
              children: [
                widget.child,
                if (visible && !_sheetOpen)
                  Positioned(
                    left: position.dx,
                    top: position.dy,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_movedDuringGesture) return;
                        _showDeveloperSheet();
                      },
                      onPanDown: (_) {
                        setState(() {
                          _dragging = true;
                          _movedDuringGesture = false;
                          _position = position;
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _movedDuringGesture = true;
                          _position = _clampPosition(
                            (_position ?? position) + details.delta,
                            size,
                          );
                        });
                      },
                      onPanEnd: (_) => _snapToHorizontalEdge(size),
                      onPanCancel: () => _snapToHorizontalEdge(size),
                      child: _DebugButton(
                        size: _buttonSize,
                        opacity: _dragging ? 1 : 0.65,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Offset _clampPosition(Offset position, Size size) {
    return Offset(
      position.dx.clamp(0.0, size.width - _buttonSize).toDouble(),
      position.dy.clamp(0.0, size.height - _buttonSize).toDouble(),
    );
  }

  void _snapToHorizontalEdge(Size size) {
    final current = _clampPosition(_position ?? Offset.zero, size);
    final targetX = current.dx + _buttonSize / 2 < size.width / 2
        ? _edgePadding
        : size.width - _buttonSize - _edgePadding;
    setState(() {
      _dragging = false;
      _position = _clampPosition(Offset(targetX, current.dy), size);
    });
  }

  Future<void> _showDeveloperSheet() async {
    final navigatorContext =
        widget.navigatorKey.currentState?.overlay?.context ??
        widget.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    setState(() => _sheetOpen = true);
    try {
      await showGenesisModalBottomSheet<void>(
        context: navigatorContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.72,
          child: DeveloperPageSheet(),
        ),
      );
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }
}

class _DebugButton extends StatelessWidget {
  const _DebugButton({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: const Color(0xFFFF2344),
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          child: const Center(
            child: Text(
              'debug',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
