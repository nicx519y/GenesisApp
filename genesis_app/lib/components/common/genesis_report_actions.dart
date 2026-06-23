import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import 'genesis_center_toast.dart';

const TextStyle _genesisActionMenuTextStyle = TextStyle(
  fontSize: 14,
  height: 1.2,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
);
const double _genesisActionMenuWidth = 132;
const double _genesisActionMenuRowHeight = 36;
const double _genesisActionMenuArrowWidth = 14;
const double _genesisActionMenuArrowHeight = 8;
const double _genesisActionMenuScreenPadding = 8;
const double _genesisActionMenuTriggerGap = 12;
const double _genesisActionMenuVerticalLift = 4;
const double _genesisActionMenuShadowPadding = 12;
const double _genesisActionMenuBorderRadius = 8;
const Color _genesisActionMenuBackgroundColor = Colors.white;

class GenesisActionMenuItem {
  const GenesisActionMenuItem({
    required this.label,
    required this.onSelected,
    this.textStyle,
  });

  final String label;
  final VoidCallback onSelected;
  final TextStyle? textStyle;
}

class GenesisMoreActionMenuButton extends StatelessWidget {
  const GenesisMoreActionMenuButton({
    super.key,
    required this.items,
    this.iconSize = 18,
    this.iconColor = Colors.black,
    this.buttonSize = 38,
  });

  final List<GenesisActionMenuItem> items;
  final double iconSize;
  final Color iconColor;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: buttonSize,
          height: buttonSize,
        ),
        icon: Icon(Icons.more_horiz_sharp, size: iconSize, color: iconColor),
        onPressed: () => _showFromButton(context),
      ),
    );
  }

  void _showFromButton(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final buttonCenter = box.localToGlobal(
      Offset(box.size.width / 2, box.size.height / 2),
    );
    showGenesisActionMenuAt(
      context: context,
      globalPosition: buttonCenter,
      items: items,
    );
  }
}

class _GenesisActionMenuPosition {
  const _GenesisActionMenuPosition({
    required this.left,
    required this.top,
    required this.expandsDown,
    required this.arrowCenterX,
  });

  final double left;
  final double top;
  final bool expandsDown;
  final double arrowCenterX;
}

_GenesisActionMenuPosition _genesisActionMenuPosition({
  required Offset globalPosition,
  required Size overlaySize,
  required int itemCount,
}) {
  final menuHeight = itemCount * _genesisActionMenuRowHeight;
  final totalHeight = menuHeight + _genesisActionMenuArrowHeight;
  final minArrowCenterX = _genesisActionMenuArrowWidth / 2;
  final maxArrowCenterX =
      _genesisActionMenuWidth - _genesisActionMenuArrowWidth / 2;
  final desiredLeft = globalPosition.dx - _genesisActionMenuWidth / 2;
  final maxLeft =
      overlaySize.width -
      _genesisActionMenuWidth -
      _genesisActionMenuScreenPadding;
  final maxTop =
      overlaySize.height - totalHeight - _genesisActionMenuScreenPadding;
  final expandsDown = globalPosition.dy <= overlaySize.height / 2;
  final desiredTop = expandsDown
      ? globalPosition.dy +
            _genesisActionMenuTriggerGap -
            _genesisActionMenuVerticalLift
      : globalPosition.dy -
            _genesisActionMenuTriggerGap -
            totalHeight -
            _genesisActionMenuVerticalLift;
  final left = desiredLeft
      .clamp(
        _genesisActionMenuScreenPadding,
        maxLeft < _genesisActionMenuScreenPadding
            ? _genesisActionMenuScreenPadding
            : maxLeft,
      )
      .toDouble();
  final top = desiredTop
      .clamp(
        _genesisActionMenuScreenPadding,
        maxTop < _genesisActionMenuScreenPadding
            ? _genesisActionMenuScreenPadding
            : maxTop,
      )
      .toDouble();
  final arrowCenterX = (globalPosition.dx - left)
      .clamp(minArrowCenterX, maxArrowCenterX)
      .toDouble();

  return _GenesisActionMenuPosition(
    left: left,
    top: top,
    expandsDown: expandsDown,
    arrowCenterX: arrowCenterX,
  );
}

Future<void> showGenesisActionMenuAt({
  required BuildContext context,
  required Offset globalPosition,
  required List<GenesisActionMenuItem> items,
}) async {
  if (items.isEmpty) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final overlayBox = overlay.context.findRenderObject();
  if (overlayBox is! RenderBox) return;
  final completer = Completer<void>();
  late OverlayEntry entry;
  void close() {
    if (completer.isCompleted) return;
    entry.remove();
    completer.complete();
  }

  final position = _genesisActionMenuPosition(
    globalPosition: globalPosition,
    overlaySize: overlayBox.size,
    itemCount: items.length,
  );
  entry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: close,
            ),
          ),
          Positioned(
            left: position.left - _genesisActionMenuShadowPadding,
            top: position.top - _genesisActionMenuShadowPadding,
            width:
                _genesisActionMenuWidth + _genesisActionMenuShadowPadding * 2,
            child: Padding(
              padding: const EdgeInsets.all(_genesisActionMenuShadowPadding),
              child: _GenesisActionBubble(
                items: items,
                expandsDown: position.expandsDown,
                arrowCenterX: position.arrowCenterX,
                onDismiss: close,
              ),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  return completer.future;
}

class _GenesisActionBubble extends StatelessWidget {
  const _GenesisActionBubble({
    required this.items,
    required this.expandsDown,
    required this.arrowCenterX,
    required this.onDismiss,
  });

  final List<GenesisActionMenuItem> items;
  final bool expandsDown;
  final double arrowCenterX;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final arrow = _GenesisActionBubbleArrow(
      pointsUp: expandsDown,
      centerX: arrowCenterX,
    );
    final body = _GenesisActionBubbleBody(items: items, onDismiss: onDismiss);
    return Material(
      color: Colors.transparent,
      child: CustomPaint(
        painter: _GenesisActionBubbleShadowPainter(
          itemCount: items.length,
          expandsDown: expandsDown,
          arrowCenterX: arrowCenterX,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: expandsDown ? [arrow, body] : [body, arrow],
        ),
      ),
    );
  }
}

class _GenesisActionBubbleShadowPainter extends CustomPainter {
  const _GenesisActionBubbleShadowPainter({
    required this.itemCount,
    required this.expandsDown,
    required this.arrowCenterX,
  });

  final int itemCount;
  final bool expandsDown;
  final double arrowCenterX;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _genesisActionBubblePath(
      itemCount: itemCount,
      expandsDown: expandsDown,
      arrowCenterX: arrowCenterX,
    );
    final shadow = const BoxShadow(
      color: Color(0x24000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    );
    canvas.save();
    canvas.translate(shadow.offset.dx, shadow.offset.dy);
    canvas.drawPath(path, shadow.toPaint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GenesisActionBubbleShadowPainter oldDelegate) {
    return oldDelegate.itemCount != itemCount ||
        oldDelegate.expandsDown != expandsDown ||
        oldDelegate.arrowCenterX != arrowCenterX;
  }
}

Path _genesisActionBubblePath({
  required int itemCount,
  required bool expandsDown,
  required double arrowCenterX,
}) {
  final bodyHeight = itemCount * _genesisActionMenuRowHeight;
  final bodyTop = expandsDown ? _genesisActionMenuArrowHeight : 0.0;
  final bodyRect = Rect.fromLTWH(
    0,
    bodyTop,
    _genesisActionMenuWidth,
    bodyHeight,
  );
  final path = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        bodyRect,
        const Radius.circular(_genesisActionMenuBorderRadius),
      ),
    );
  if (expandsDown) {
    path
      ..moveTo(arrowCenterX, 0)
      ..lineTo(
        arrowCenterX + _genesisActionMenuArrowWidth / 2,
        _genesisActionMenuArrowHeight,
      )
      ..lineTo(
        arrowCenterX - _genesisActionMenuArrowWidth / 2,
        _genesisActionMenuArrowHeight,
      )
      ..close();
  } else {
    final arrowTop = bodyHeight;
    path
      ..moveTo(arrowCenterX - _genesisActionMenuArrowWidth / 2, arrowTop)
      ..lineTo(arrowCenterX + _genesisActionMenuArrowWidth / 2, arrowTop)
      ..lineTo(arrowCenterX, arrowTop + _genesisActionMenuArrowHeight)
      ..close();
  }
  return path;
}

class _GenesisActionBubbleBody extends StatelessWidget {
  const _GenesisActionBubbleBody({
    required this.items,
    required this.onDismiss,
  });

  final List<GenesisActionMenuItem> items;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _genesisActionMenuBackgroundColor,
        borderRadius: BorderRadius.circular(_genesisActionMenuBorderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_genesisActionMenuBorderRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _GenesisActionBubbleRow(
                item: items[index],
                onTap: () {
                  onDismiss();
                  items[index].onSelected();
                },
              ),
              if (index != items.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE8E8EA),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GenesisActionBubbleRow extends StatelessWidget {
  const _GenesisActionBubbleRow({required this.item, required this.onTap});

  final GenesisActionMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _genesisActionMenuRowHeight,
        width: _genesisActionMenuWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.label,
              style: item.textStyle ?? _genesisActionMenuTextStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _GenesisActionBubbleArrow extends StatelessWidget {
  const _GenesisActionBubbleArrow({
    required this.pointsUp,
    required this.centerX,
  });

  final bool pointsUp;
  final double centerX;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _genesisActionMenuArrowHeight,
      width: _genesisActionMenuWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: centerX - _genesisActionMenuArrowWidth / 2,
            top: 0,
            child: CustomPaint(
              size: const Size(
                _genesisActionMenuArrowWidth,
                _genesisActionMenuArrowHeight,
              ),
              painter: _GenesisActionBubbleArrowPainter(pointsUp: pointsUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenesisActionBubbleArrowPainter extends CustomPainter {
  const _GenesisActionBubbleArrowPainter({required this.pointsUp});

  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = _genesisActionMenuBackgroundColor);
  }

  @override
  bool shouldRepaint(covariant _GenesisActionBubbleArrowPainter oldDelegate) {
    return oldDelegate.pointsUp != pointsUp;
  }
}

GenesisActionMenuItem genesisReportMenuItem({
  required BuildContext context,
  required String targetType,
  required String targetId,
}) {
  return GenesisActionMenuItem(
    label: 'Report',
    onSelected: () {
      showGenesisReportDialog(
        context: context,
        targetType: targetType,
        targetId: targetId,
      );
    },
  );
}

Future<bool> showGenesisReportDialog({
  required BuildContext context,
  required String targetType,
  required String targetId,
}) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return _GenesisReportDialog(targetType: targetType, targetId: targetId);
    },
  );
  return submitted == true;
}

class _GenesisReportDialog extends StatefulWidget {
  const _GenesisReportDialog({
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  State<_GenesisReportDialog> createState() => _GenesisReportDialogState();
}

class _GenesisReportDialogState extends State<_GenesisReportDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await AppServicesScope.read(context).api.v1.report.create(
        targetType: widget.targetType,
        targetId: widget.targetId,
        content: content,
      );
      if (!mounted) return;
      showGenesisToast(context, 'Report submitted');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showGenesisToast(context, 'Report failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportEnabled = _controller.text.trim().isNotEmpty && !_submitting;
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Describe the issue',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD8D8DE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4B6192)),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: reportEnabled ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
