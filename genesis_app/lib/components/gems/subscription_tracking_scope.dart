import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../../app/membership/subscription_analytics.dart';
import '../../platform/billing/billing_models.dart';

/// Owned by the page/sheet, so rebuilding a tab keeps the same exposure ID.
class SubscriptionPageTracking {
  SubscriptionPageTracking({
    String? pageId,
    this.surface = SubscriptionSurface.sheet,
    this.source = SubscriptionSource.unknown,
    SubscriptionAnalytics? analytics,
  }) : pageId = pageId ?? newBillingTrackPageId(),
       analytics = analytics ?? SubscriptionAnalytics();

  final String pageId;
  final SubscriptionSurface surface;
  final SubscriptionSource source;
  final SubscriptionAnalytics analytics;

  void show() => analytics.pageShow(pageId, surface, source);
  SubscriptionTracking click({required bool isYearly}) {
    show();
    return analytics.click(pageId, surface, source, isYearly: isYearly);
  }
}

class SubscriptionTrackingScope extends InheritedWidget {
  const SubscriptionTrackingScope({
    super.key,
    required this.page,
    required super.child,
  });
  final SubscriptionPageTracking page;

  static SubscriptionPageTracking? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SubscriptionTrackingScope>()
      ?.page;

  @override
  bool updateShouldNotify(SubscriptionTrackingScope oldWidget) =>
      oldWidget.page != page;
}

/// One-shot exposure after a frame actually paints inside its ancestors' clips.
/// Offstage tabs never paint; adjacent PageView pages are clipped out. No timer
/// or catalog/network result is needed to count the initial loading surface.
class SubscriptionExposure extends SingleChildRenderObjectWidget {
  const SubscriptionExposure({
    super.key,
    required this.onVisible,
    required super.child,
  });
  final bool Function() onVisible;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSubscriptionExposure(onVisible);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSubscriptionExposure renderObject,
  ) {
    renderObject.onVisible = onVisible;
  }
}

class RenderSubscriptionExposure extends RenderProxyBox {
  RenderSubscriptionExposure(this.onVisible);
  bool Function() onVisible;
  bool _reported = false;
  bool _scheduled = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_reported || _scheduled || size.isEmpty) return;
    var visible = MatrixUtils.transformRect(getTransformTo(null), paintBounds);
    RenderObject descendant = this;
    for (var ancestor = parent; ancestor != null; ancestor = ancestor.parent) {
      final clip = ancestor.describeApproximatePaintClip(descendant);
      if (clip != null) {
        visible = visible.intersect(
          MatrixUtils.transformRect(ancestor.getTransformTo(null), clip),
        );
      }
      if (ancestor is RenderView) {
        visible = visible.intersect(ancestor.paintBounds);
      }
      if (visible.isEmpty) return;
      descendant = ancestor;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (attached && !_reported) _reported = onVisible();
    });
  }
}
