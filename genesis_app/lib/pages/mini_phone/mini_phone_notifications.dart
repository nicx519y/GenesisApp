part of 'mini_phone_page.dart';

/// Measures actual card heights and interpolates every card from its stack slot.
class _MiniNoticeLayout extends MultiChildRenderObjectWidget {
  const _MiniNoticeLayout({required this.progress, required super.children});
  final double progress;
  @override
  _MiniNoticeRenderBox createRenderObject(BuildContext context) =>
      _MiniNoticeRenderBox(progress);
  @override
  void updateRenderObject(
    BuildContext context,
    _MiniNoticeRenderBox renderObject,
  ) {
    renderObject.progress = progress;
  }
}

class _MiniNoticeParentData extends ContainerBoxParentData<RenderBox> {}

class _MiniNoticeRenderBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MiniNoticeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MiniNoticeParentData> {
  _MiniNoticeRenderBox(this._progress);
  double _progress;
  set progress(double value) {
    if (value == _progress) return;
    _progress = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MiniNoticeParentData) {
      child.parentData = _MiniNoticeParentData();
    }
  }

  double _inset(int index) =>
      (index > 2 ? 12.0 : index * 6.0) * (1 - _progress);
  double _stackTop(int index) => index > 2 ? 14.0 : index * 7.0;

  double _height(double width, {required bool dry}) {
    double full = 0, collapsed = 0;
    var index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final childWidth = (width - 2 * _inset(index)).clamp(
        0.0,
        double.infinity,
      );
      final box = BoxConstraints.tightFor(width: childWidth);
      final childSize = dry ? child.getDryLayout(box) : child.size;
      final requiredHeight =
          childSize.height + _stackTop(childCount - index - 1);
      if (requiredHeight > collapsed) {
        collapsed = requiredHeight;
      }
      full += childSize.height + (index == 0 ? 0 : 7);
      child = (child.parentData! as _MiniNoticeParentData).nextSibling;
      index++;
    }
    return collapsed * (1 - _progress) + full * _progress;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    Size(constraints.maxWidth, _height(constraints.maxWidth, dry: true)),
  );

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    var index = 0;
    double fullHeight = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final inset = _inset(index);
      child.layout(
        BoxConstraints.tightFor(
          width: (width - inset * 2).clamp(0.0, double.infinity),
        ),
        parentUsesSize: true,
      );
      fullHeight += child.size.height + (index == 0 ? 0 : 7);
      child = (child.parentData! as _MiniNoticeParentData).nextSibling;
      index++;
    }
    size = constraints.constrain(Size(width, _height(width, dry: false)));
    double expandedTop = 0;
    index = 0;
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as _MiniNoticeParentData;
      final expandedDistance = fullHeight - expandedTop - child.size.height;
      // Keep source order: the last card stays anchored, earlier cards unfold above it.
      data.offset = Offset(
        _inset(index),
        size.height -
            child.size.height -
            (_stackTop(childCount - index - 1) * (1 - _progress) +
                expandedDistance * _progress),
      );
      expandedTop += child.size.height + 7;
      child = data.nextSibling;
      index++;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // The front card stays above the remaining cards throughout the transition.
    RenderBox? child = lastChild;
    while (child != null) {
      final data = child.parentData! as _MiniNoticeParentData;
      if (child != firstChild && _progress < 1) {
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(
            (offset + data.offset) & child.size,
            const Radius.circular(21),
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: .28 * (1 - _progress)),
        );
      }
      context.paintChild(child, offset + data.offset);
      child = data.previousSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = firstChild;
    while (child != null) {
      final current = child;
      final data = current.parentData! as _MiniNoticeParentData;
      if (result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, local) => current.hitTest(result, position: local),
      )) {
        return true;
      }
      child = data.nextSibling;
    }
    return false;
  }
}
