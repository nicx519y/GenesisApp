import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../ui/components/genesis_modal_border.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import 'genesis_content_submission_dialog.dart';

const TextStyle _genesisActionMenuTextStyle = TextStyle(
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);
const String genesisReportIconAsset =
    'assets/custom-icons/svg/report-svgrepo-com.svg';
const String genesisDeleteIconAsset = 'assets/custom-icons/svg/delete-icon.svg';
const double _genesisActionMenuMinWidth = 96;
const double _genesisActionMenuHorizontalPadding = 14;
const double _genesisActionMenuIconSize = 15;
const double _genesisActionMenuIconGap = 8;
const double _genesisActionMenuRowHeight = 36;
const double _genesisActionMenuArrowWidth = 14;
const double _genesisActionMenuArrowHeight = 8;
const double _genesisActionMenuScreenPadding = 8;
const double _genesisActionMenuTriggerGap = 12;
const double _genesisActionMenuVerticalLift = 4;
const double _genesisActionMenuDownwardScreenRatio = 0.2;
const double _genesisActionMenuShadowPadding = 12;
const double _genesisActionMenuBorderRadius = 8;

enum GenesisActionMenuAppearance { standard, message }

class GenesisActionMenuItem {
  const GenesisActionMenuItem({
    required this.label,
    required this.onSelected,
    this.textStyle,
    this.iconAsset,
    this.iconData,
  });

  final String label;
  final VoidCallback onSelected;
  final TextStyle? textStyle;
  final String? iconAsset;
  final IconData? iconData;
}

class GenesisMoreActionMenuButton extends StatefulWidget {
  const GenesisMoreActionMenuButton({
    super.key,
    required this.items,
    this.iconSize = 18,
    this.iconColor,
    this.buttonSize = 38,
    this.menuRightInset,
    this.menuVerticalOffset = 0,
    this.visualRightInset,
  });

  final List<GenesisActionMenuItem> items;
  final double iconSize;
  final Color? iconColor;
  final double buttonSize;
  final double? menuRightInset;
  final double menuVerticalOffset;
  final double? visualRightInset;

  @override
  State<GenesisMoreActionMenuButton> createState() =>
      _GenesisMoreActionMenuButtonState();
}

class _GenesisMoreActionMenuButtonState
    extends State<GenesisMoreActionMenuButton> {
  _GenesisActionMenuHandle? _menuHandle;

  @override
  void dispose() {
    _menuHandle?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: widget.buttonSize,
      height: widget.buttonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: widget.buttonSize,
          height: widget.buttonSize,
        ),
        icon: Icon(
          Icons.more_horiz_sharp,
          size: widget.iconSize,
          color: widget.iconColor ?? context.genesisColors.foregroundStrong,
        ),
        onPressed: () => _showFromButton(context),
      ),
    );
    final visualRightInset = widget.visualRightInset;
    if (visualRightInset == null) return button;
    final centeredIconTrailingSpace = (widget.buttonSize - widget.iconSize) / 2;
    final trailingPadding = visualRightInset > centeredIconTrailingSpace
        ? visualRightInset - centeredIconTrailingSpace
        : 0.0;
    return SizedBox(
      width: widget.buttonSize + trailingPadding,
      height: widget.buttonSize,
      child: Align(alignment: Alignment.centerLeft, child: button),
    );
  }

  void _showFromButton(BuildContext context) {
    _menuHandle?.close();
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final route = ModalRoute.of(context);
    final topLeft = box.localToGlobal(Offset.zero);
    final buttonCenter = box.localToGlobal(
      Offset(box.size.width / 2, box.size.height / 2),
    );
    _menuHandle = _showGenesisActionMenuAtInternal(
      context: context,
      globalPosition: buttonCenter,
      triggerRect: topLeft & box.size,
      items: widget.items,
      placement: _GenesisActionMenuPlacement.leftOfTrigger,
      appearance: GenesisActionMenuAppearance.standard,
      rightInset: widget.menuRightInset,
      verticalOffset: widget.menuVerticalOffset,
    );
    final handle = _menuHandle;
    if (handle != null) {
      unawaited(handle.closed.whenComplete(() => _menuHandle = null));
      if (route != null) {
        unawaited(route.popped.whenComplete(handle.close));
      }
    }
  }
}

enum _GenesisActionMenuPlacement { anchoredBubble, leftOfTrigger }

class _GenesisActionMenuLayout {
  _GenesisActionMenuLayout({
    required this.appearance,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final GenesisActionMenuAppearance appearance;
  final Color backgroundColor;
  final Color foregroundColor;

  bool get isHorizontal => appearance == GenesisActionMenuAppearance.message;

  TextStyle get defaultTextStyle => GenesisTypography.withFallback(
    appearance == GenesisActionMenuAppearance.message
        ? TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: foregroundColor,
          )
        : _genesisActionMenuTextStyle.copyWith(color: foregroundColor),
  );

  TextStyle itemTextStyle(GenesisActionMenuItem item) =>
      GenesisTypography.withFallback(item.textStyle ?? defaultTextStyle);

  ColorFilter get iconColorFilter =>
      ColorFilter.mode(foregroundColor, BlendMode.srcIn);
}

class _GenesisActionMenuHandle {
  _GenesisActionMenuHandle({
    required OverlayEntry entry,
    required Completer<void> completer,
    required GlobalKey menuKey,
  }) : _entry = entry,
       _completer = completer,
       _menuKey = menuKey {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  static _GenesisActionMenuHandle? _active;

  final OverlayEntry _entry;
  final Completer<void> _completer;
  final GlobalKey _menuKey;

  Future<void> get closed => _completer.future;

  void activate() {
    if (_active == this) return;
    _active?.close();
    _active = this;
  }

  void close() {
    if (_completer.isCompleted) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _handlePointerEvent,
    );
    if (_active == this) _active = null;
    _entry.remove();
    _completer.complete();
  }

  void _handlePointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    final context = _menuKey.currentContext;
    final box = context?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      if (bounds
          .inflate(_genesisActionMenuShadowPadding)
          .contains(event.position)) {
        return;
      }
    }
    close();
  }
}

Future<void> showGenesisActionMenuAt({
  required BuildContext context,
  required Offset globalPosition,
  required List<GenesisActionMenuItem> items,
  GenesisActionMenuAppearance appearance = GenesisActionMenuAppearance.standard,
}) async {
  final handle = _showGenesisActionMenuAtInternal(
    context: context,
    globalPosition: globalPosition,
    items: items,
    placement: _GenesisActionMenuPlacement.anchoredBubble,
    appearance: appearance,
  );
  if (handle == null) return;
  return handle.closed;
}

_GenesisActionMenuHandle? _showGenesisActionMenuAtInternal({
  required BuildContext context,
  required Offset globalPosition,
  required List<GenesisActionMenuItem> items,
  required _GenesisActionMenuPlacement placement,
  required GenesisActionMenuAppearance appearance,
  Rect? triggerRect,
  double? rightInset,
  double verticalOffset = 0,
}) {
  if (items.isEmpty) return null;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  final overlayBox = overlay.context.findRenderObject();
  if (overlayBox is! RenderBox) return null;
  final completer = Completer<void>();
  late OverlayEntry entry;
  void close() {
    if (completer.isCompleted) return;
    entry.remove();
    completer.complete();
  }

  final colors = context.genesisColors;
  final backgroundColor = appearance == GenesisActionMenuAppearance.standard
      ? Color.alphaBlend(colors.textMuted, colors.pageBackground)
      : colors.textMuted;
  final layout = _GenesisActionMenuLayout(
    appearance: appearance,
    backgroundColor: backgroundColor,
    foregroundColor: colors.textInverse,
  );
  final menuKey = GlobalKey();
  entry = OverlayEntry(
    builder: (context) {
      return _GenesisActionMenuOverlay(
        items: items,
        layout: layout,
        menuKey: menuKey,
        globalPosition: globalPosition,
        placement: placement,
        triggerRect: triggerRect,
        rightInset: rightInset,
        verticalOffset: verticalOffset,
        onDismiss: close,
      );
    },
  );
  overlay.insert(entry);
  final handle = _GenesisActionMenuHandle(
    entry: entry,
    completer: completer,
    menuKey: menuKey,
  );
  handle.activate();
  return handle;
}

enum _GenesisActionMenuChild { body, arrow }

class _GenesisActionMenuOverlay extends StatelessWidget {
  const _GenesisActionMenuOverlay({
    required this.items,
    required this.layout,
    required this.menuKey,
    required this.globalPosition,
    required this.placement,
    required this.triggerRect,
    required this.rightInset,
    required this.verticalOffset,
    required this.onDismiss,
  });

  final List<GenesisActionMenuItem> items;
  final _GenesisActionMenuLayout layout;
  final GlobalKey menuKey;
  final Offset globalPosition;
  final _GenesisActionMenuPlacement placement;
  final Rect? triggerRect;
  final double? rightInset;
  final double verticalOffset;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final showArrow = placement == _GenesisActionMenuPlacement.anchoredBubble;
    final expandsDown =
        showArrow &&
        globalPosition.dy <=
            MediaQuery.sizeOf(context).height *
                _genesisActionMenuDownwardScreenRatio;
    return CustomMultiChildLayout(
      delegate: _GenesisActionMenuOverlayDelegate(
        globalPosition: globalPosition,
        placement: placement,
        triggerRect: triggerRect,
        rightInset: rightInset,
        verticalOffset: verticalOffset,
        showArrow: showArrow,
        expandsDown: expandsDown,
      ),
      children: [
        LayoutId(
          id: _GenesisActionMenuChild.body,
          child: Material(
            key: menuKey,
            color: Colors.transparent,
            child: _GenesisActionBubbleBody(
              items: items,
              layout: layout,
              shadowColor: context.genesisColors.shadow.withValues(alpha: 0.14),
              onDismiss: onDismiss,
            ),
          ),
        ),
        if (showArrow)
          LayoutId(
            id: _GenesisActionMenuChild.arrow,
            child: _GenesisActionBubbleArrow(
              pointsUp: expandsDown,
              color: layout.backgroundColor,
              borderColor: genesisModalBorderColor(context),
            ),
          ),
      ],
    );
  }
}

class _GenesisActionMenuOverlayDelegate extends MultiChildLayoutDelegate {
  _GenesisActionMenuOverlayDelegate({
    required this.globalPosition,
    required this.placement,
    required this.triggerRect,
    required this.rightInset,
    required this.verticalOffset,
    required this.showArrow,
    required this.expandsDown,
  });

  final Offset globalPosition;
  final _GenesisActionMenuPlacement placement;
  final Rect? triggerRect;
  final double? rightInset;
  final double verticalOffset;
  final bool showArrow;
  final bool expandsDown;

  @override
  void performLayout(Size size) {
    final maxMenuWidth = math.max(
      0.0,
      size.width - _genesisActionMenuScreenPadding * 2,
    );
    final maxMenuHeight = math.max(
      0.0,
      size.height -
          _genesisActionMenuScreenPadding * 2 -
          (showArrow ? _genesisActionMenuArrowHeight : 0),
    );
    final bodySize = layoutChild(
      _GenesisActionMenuChild.body,
      BoxConstraints(maxWidth: maxMenuWidth, maxHeight: maxMenuHeight),
    );
    final arrowSize = showArrow
        ? layoutChild(
            _GenesisActionMenuChild.arrow,
            const BoxConstraints.tightFor(
              width: _genesisActionMenuArrowWidth,
              height: _genesisActionMenuArrowHeight,
            ),
          )
        : Size.zero;

    final totalHeight = bodySize.height + arrowSize.height;
    final maxLeft = math.max(
      _genesisActionMenuScreenPadding,
      size.width - bodySize.width - _genesisActionMenuScreenPadding,
    );
    final maxTop = math.max(
      _genesisActionMenuScreenPadding,
      size.height - totalHeight - _genesisActionMenuScreenPadding,
    );

    final left = _desiredLeft(
      size,
      bodySize.width,
    ).clamp(_genesisActionMenuScreenPadding, maxLeft).toDouble();
    final top = _desiredTop(
      totalHeight,
    ).clamp(_genesisActionMenuScreenPadding, maxTop).toDouble();
    final bodyTop = top + (showArrow && expandsDown ? arrowSize.height : 0);
    positionChild(_GenesisActionMenuChild.body, Offset(left, bodyTop));

    if (showArrow) {
      final arrowCenterX = globalPosition.dx
          .clamp(
            left + arrowSize.width / 2,
            left + bodySize.width - arrowSize.width / 2,
          )
          .toDouble();
      final arrowTop = expandsDown ? top : top + bodySize.height;
      positionChild(
        _GenesisActionMenuChild.arrow,
        Offset(arrowCenterX - arrowSize.width / 2, arrowTop),
      );
    }
  }

  double _desiredLeft(Size overlaySize, double menuWidth) {
    if (placement == _GenesisActionMenuPlacement.leftOfTrigger &&
        triggerRect != null) {
      return rightInset == null
          ? triggerRect!.left - menuWidth
          : overlaySize.width - rightInset! - menuWidth;
    }
    return globalPosition.dx - menuWidth / 2;
  }

  double _desiredTop(double totalHeight) {
    if (placement == _GenesisActionMenuPlacement.leftOfTrigger &&
        triggerRect != null) {
      return triggerRect!.center.dy -
          _genesisActionMenuRowHeight / 2 +
          verticalOffset;
    }
    return expandsDown
        ? globalPosition.dy +
              _genesisActionMenuTriggerGap -
              _genesisActionMenuVerticalLift
        : globalPosition.dy -
              _genesisActionMenuTriggerGap -
              totalHeight -
              _genesisActionMenuVerticalLift;
  }

  @override
  bool shouldRelayout(covariant _GenesisActionMenuOverlayDelegate oldDelegate) {
    return oldDelegate.globalPosition != globalPosition ||
        oldDelegate.placement != placement ||
        oldDelegate.triggerRect != triggerRect ||
        oldDelegate.rightInset != rightInset ||
        oldDelegate.verticalOffset != verticalOffset ||
        oldDelegate.showArrow != showArrow ||
        oldDelegate.expandsDown != expandsDown;
  }
}

class _GenesisActionBubbleBody extends StatelessWidget {
  const _GenesisActionBubbleBody({
    required this.items,
    required this.layout,
    required this.shadowColor,
    required this.onDismiss,
  });

  final List<GenesisActionMenuItem> items;
  final _GenesisActionMenuLayout layout;
  final Color shadowColor;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final content = layout.isHorizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                _GenesisActionBubbleRow(
                  item: item,
                  layout: layout,
                  onTap: () {
                    onDismiss();
                    item.onSelected();
                  },
                ),
            ],
          )
        : IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _GenesisActionBubbleRow(
                    item: items[index],
                    layout: layout,
                    onTap: () {
                      onDismiss();
                      items[index].onSelected();
                    },
                  ),
                  if (index != items.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.genesisColors.textInverse.withValues(
                        alpha: 0.2,
                      ),
                    ),
                ],
              ],
            ),
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: layout.backgroundColor,
        borderRadius: BorderRadius.circular(_genesisActionMenuBorderRadius),
        border: genesisModalBorder(context),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_genesisActionMenuBorderRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _genesisActionMenuMinWidth,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _GenesisActionBubbleRow extends StatelessWidget {
  const _GenesisActionBubbleRow({
    required this.item,
    required this.layout,
    required this.onTap,
  });

  final GenesisActionMenuItem item;
  final _GenesisActionMenuLayout layout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemColor = item.textStyle?.color ?? layout.foregroundColor;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _genesisActionMenuRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _genesisActionMenuHorizontalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.iconAsset case final iconAsset?) ...[
                SvgPicture.asset(
                  iconAsset,
                  width: _genesisActionMenuIconSize,
                  height: _genesisActionMenuIconSize,
                  colorFilter: ColorFilter.mode(itemColor, BlendMode.srcIn),
                ),
                const SizedBox(width: _genesisActionMenuIconGap),
              ] else if (item.iconData case final iconData?) ...[
                Icon(
                  iconData,
                  size: _genesisActionMenuIconSize,
                  color: itemColor,
                ),
                const SizedBox(width: _genesisActionMenuIconGap),
              ],
              Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                style: layout.itemTextStyle(item),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenesisActionBubbleArrow extends StatelessWidget {
  const _GenesisActionBubbleArrow({
    required this.pointsUp,
    required this.color,
    required this.borderColor,
  });

  final bool pointsUp;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(
        _genesisActionMenuArrowWidth,
        _genesisActionMenuArrowHeight,
      ),
      painter: _GenesisActionBubbleArrowPainter(
        pointsUp: pointsUp,
        color: color,
        borderColor: borderColor,
      ),
    );
  }
}

class _GenesisActionBubbleArrowPainter extends CustomPainter {
  const _GenesisActionBubbleArrowPainter({
    required this.pointsUp,
    required this.color,
    required this.borderColor,
  });

  final bool pointsUp;
  final Color color;
  final Color borderColor;

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
    canvas.drawPath(path, Paint()..color = color);
    final outline = Path();
    if (pointsUp) {
      outline
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      outline
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = genesisModalBorderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _GenesisActionBubbleArrowPainter oldDelegate) {
    return oldDelegate.pointsUp != pointsUp ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor;
  }
}

GenesisActionMenuItem genesisReportMenuItem({
  required BuildContext context,
  required String targetType,
  required String targetId,
}) {
  return GenesisActionMenuItem(
    label: 'Report',
    iconAsset: genesisReportIconAsset,
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
  if (!context.mounted) return false;
  final api = AppServicesScope.read(context).api;
  return showGenesisContentSubmissionDialog(
    context: context,
    title: 'Report',
    contentInputKey: const ValueKey<String>('genesis-report-content-input'),
    successMessage: 'Report submitted',
    failureMessage: 'Report failed',
    onSubmit: (content) {
      return api.v1.report.create(
        targetType: targetType,
        targetId: targetId,
        content: content,
      );
    },
  );
}
