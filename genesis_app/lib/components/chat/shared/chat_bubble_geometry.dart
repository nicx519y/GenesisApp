import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks the decorated message body, inside its external margin. Geometry is
/// read after layout, in the same frame as the viewport and scroll offset.
class ChatBubbleGeometry extends SingleChildRenderObjectWidget {
  const ChatBubbleGeometry({super.key, required super.child});

  /// Reads only transforms, safe from the parent sliver's layout correction.
  /// No descendant size is inspected during another render object's layout.
  static double? topWithin(RenderObject? root) {
    double? top;
    void visit(RenderObject node) {
      if (!node.attached) return;
      if (node is _RenderBubbleGeometry) {
        final y = MatrixUtils.transformPoint(
          node.getTransformTo(root),
          Offset.zero,
        ).dy;
        if (top == null || y < top!) top = y;
        return;
      }
      node.visitChildren(visit);
    }

    if (root != null) visit(root);
    return top;
  }

  static Rect? globalBoundsOf(RenderObject? root) {
    Rect? bounds;
    void visit(RenderObject node) {
      if (!node.attached) return;
      if (node is RenderBox && node.hasSize && node.size.isEmpty) return;
      if (node is _RenderBubbleGeometry) {
        if (!node.hasSize || node.size.isEmpty) return;
        final rect = MatrixUtils.transformRect(
          node.getTransformTo(null),
          Offset.zero & node.size,
        );
        bounds = bounds?.expandToInclude(rect) ?? rect;
        return;
      }
      node.visitChildren(visit);
    }

    if (root != null) visit(root);
    return bounds;
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBubbleGeometry();
}

class _RenderBubbleGeometry extends RenderProxyBox {}
