import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../app/debug/debug_screen_translation_service.dart';
import '../app/debug/screen_translation_debug_settings.dart';
import '../app/debug_floating_button_visibility.dart';
import '../pages/me/developer_page.dart';
import '../pages/origin_editor/origin_debug_tools.dart';
import '../ui/components/genesis_safe_area.dart';
import 'common/genesis_center_toast.dart';
import 'common/genesis_modal_routes.dart';

class DeveloperDebugFloatingButton extends StatefulWidget {
  const DeveloperDebugFloatingButton({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.translateCurrentScreenOverride,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @visibleForTesting
  final Future<List<DebugScreenTranslationLine>> Function()?
  translateCurrentScreenOverride;

  @override
  State<DeveloperDebugFloatingButton> createState() =>
      _DeveloperDebugFloatingButtonState();
}

class _DeveloperDebugFloatingButtonState
    extends State<DeveloperDebugFloatingButton> {
  static const double _buttonSize = 42;
  static const double _edgePadding = 8;
  static const double _translationButtonGap = 8;

  final GlobalKey _captureBoundaryKey = GlobalKey();
  Offset? _position;
  bool _dragging = false;
  bool _movedDuringGesture = false;
  bool _sheetOpen = false;
  bool _translationHeld = false;
  bool _translationLoading = false;
  int _translationRequestId = 0;
  List<DebugScreenTranslationLine> _translationLines =
      const <DebugScreenTranslationLine>[];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: screenTranslationDebugSettings.listenable,
      builder: (context, translationEnabled, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: genesisDebugFloatingButtonVisible,
          builder: (context, debugButtonVisible, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final bottomPadding = GenesisSafeAreaInsets.bottom(context);
                final defaultPosition = _clampPosition(
                  Offset(
                    size.width - _buttonSize - _edgePadding,
                    size.height - _buttonSize - bottomPadding - 86,
                  ),
                  size,
                );
                final position = _clampPosition(
                  _position ?? defaultPosition,
                  size,
                );
                final translationPosition = _translationButtonPosition(
                  position,
                  size,
                );

                return Stack(
                  children: [
                    RepaintBoundary(
                      key: _captureBoundaryKey,
                      child: widget.child,
                    ),
                    if (translationEnabled &&
                        _translationHeld &&
                        !_translationLoading)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _ScreenTranslationOverlay(
                            lines: _translationLines,
                          ),
                        ),
                      ),
                    if (translationEnabled &&
                        _translationHeld &&
                        _translationLoading)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: _ScreenTranslationLoadingIndicator(),
                        ),
                      ),
                    if (translationEnabled && !_sheetOpen)
                      Positioned(
                        left: translationPosition.dx,
                        top: translationPosition.dy,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) {
                            unawaited(_beginScreenTranslation());
                          },
                          onPointerUp: (_) => _endScreenTranslation(),
                          onPointerCancel: (_) => _endScreenTranslation(),
                          child: _TranslationButton(
                            size: _buttonSize,
                            loading: _translationLoading,
                            held: _translationHeld,
                          ),
                        ),
                      ),
                    if (debugButtonVisible && !_sheetOpen)
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
      },
    );
  }

  Offset _translationButtonPosition(Offset debugPosition, Size size) {
    final aboveY = debugPosition.dy - _buttonSize - _translationButtonGap;
    final y = aboveY >= _edgePadding
        ? aboveY
        : debugPosition.dy + _buttonSize + _translationButtonGap;
    return _clampPosition(Offset(debugPosition.dx, y), size);
  }

  Future<void> _beginScreenTranslation() async {
    if (_translationHeld || !screenTranslationDebugSettings.enabled) return;
    final requestId = ++_translationRequestId;
    setState(() {
      _translationHeld = true;
      _translationLoading = true;
      _translationLines = const <DebugScreenTranslationLine>[];
    });

    try {
      final override = widget.translateCurrentScreenOverride;
      if (override != null) {
        final lines = await override();
        if (!_isTranslationRequestActive(requestId)) return;
        setState(() {
          _translationLoading = false;
          _translationLines = lines;
        });
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!_isTranslationRequestActive(requestId)) return;
      final boundary = _captureBoundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('The current screen is not ready to capture.');
      }
      final image = await boundary.toImage(pixelRatio: 1);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Could not encode the current screen.');
      }
      final lines = await debugScreenTranslationService.translateScreen(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      if (!_isTranslationRequestActive(requestId)) return;
      setState(() {
        _translationLoading = false;
        _translationLines = lines;
      });
    } catch (error) {
      if (!_isTranslationRequestActive(requestId)) return;
      setState(() {
        _translationLoading = false;
        _translationLines = const <DebugScreenTranslationLine>[];
      });
      final overlay = widget.navigatorKey.currentState?.overlay;
      if (overlay != null) {
        showGenesisToastInOverlay(
          overlay,
          'Translation unavailable: ${_translationErrorMessage(error)}',
          brightness: Brightness.dark,
        );
      }
    }
  }

  bool _isTranslationRequestActive(int requestId) {
    return mounted &&
        _translationHeld &&
        requestId == _translationRequestId &&
        screenTranslationDebugSettings.enabled;
  }

  void _endScreenTranslation() {
    if (!_translationHeld) return;
    _translationRequestId += 1;
    setState(() {
      _translationHeld = false;
      _translationLoading = false;
      _translationLines = const <DebugScreenTranslationLine>[];
    });
  }

  String _translationErrorMessage(Object error) {
    if (error is PlatformException &&
        error.message?.trim().isNotEmpty == true) {
      return error.message!.trim();
    }
    return error.toString();
  }

  Offset _clampPosition(Offset position, Size size) {
    return Offset(
      _clampAxis(position.dx, size.width),
      _clampAxis(position.dy, size.height),
    );
  }

  double _clampAxis(double value, double extent) {
    if (!value.isFinite || !extent.isFinite) return 0;
    final max = extent - _buttonSize;
    if (max <= 0) return 0;
    return value.clamp(0.0, max).toDouble();
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
    final randomAction = captureOriginDebugRandomAction();
    setState(() => _sheetOpen = true);
    try {
      await showGenesisModalBottomSheet<void>(
        context: navigatorContext,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 1,
          minChildSize: 0.25,
          maxChildSize: 1,
          snap: true,
          expand: false,
          builder: (_, scrollController) => DeveloperPageSheet(
            sheetScrollController: scrollController,
            randomAction: randomAction,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }
}

class _TranslationButton extends StatelessWidget {
  const _TranslationButton({
    required this.size,
    required this.loading,
    required this.held,
  });

  final double size;
  final bool loading;
  final bool held;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hold to translate the current screen into Chinese',
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: held ? const Color(0xFFFFC62A) : const Color(0xFF2D2D31),
          shape: const CircleBorder(
            side: BorderSide(color: Color(0xFFFFC62A), width: 1.5),
          ),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    '中/EN',
                    style: TextStyle(
                      color: held ? Colors.black : Colors.white,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScreenTranslationLoadingIndicator extends StatelessWidget {
  const _ScreenTranslationLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.72),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xED1A1A1D),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFFC62A)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFFC62A),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '正在识别并翻译当前屏幕…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenTranslationOverlay extends StatelessWidget {
  const _ScreenTranslationOverlay({required this.lines});

  final List<DebugScreenTranslationLine> lines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (lines.isEmpty) {
          return const Align(
            alignment: Alignment(0, -0.72),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xED1A1A1D),
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Text(
                  '当前屏幕未识别到英文',
                  style: TextStyle(
                    inherit: false,
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          );
        }
        return Stack(
          children: lines
              .map((line) {
                final left = line.left.clamp(0.0, size.width).toDouble();
                final top = line.top.clamp(0.0, size.height).toDouble();
                final right = line.right.clamp(left, size.width).toDouble();
                final bottom = line.bottom.clamp(top, size.height).toDouble();
                final height = (bottom - top).clamp(18.0, 52.0).toDouble();
                final availableWidth = (size.width - left).clamp(
                  0.0,
                  size.width,
                );
                final minimumWidth = availableWidth.clamp(0.0, 28.0);
                final width = (right - left)
                    .clamp(minimumWidth, availableWidth)
                    .toDouble();
                final fontSize = (height * 0.58).clamp(10.0, 21.0).toDouble();
                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xF21B1B1E),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0x99FFC62A),
                        width: 0.7,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          line.text,
                          maxLines: 1,
                          style: TextStyle(
                            inherit: false,
                            color: Colors.white,
                            fontSize: fontSize,
                            height: 1,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
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
          color: const Color(0xFFFF2442),
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
