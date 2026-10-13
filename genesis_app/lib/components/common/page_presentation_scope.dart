import 'package:flutter/widgets.dart';

/// Pauses presentation work while another full-screen feature covers a page.
/// It deliberately does not change the page's business/session lifecycle.
class PagePresentationController extends ChangeNotifier {
  int _covers = 0;
  bool _disposed = false;

  bool get paused => _covers > 0;

  VoidCallback cover() {
    if (_disposed) return () {};
    _covers++;
    if (_covers == 1) notifyListeners();
    var released = false;
    return () {
      if (released || _disposed) return;
      released = true;
      _covers--;
      if (_covers == 0) notifyListeners();
    };
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class PagePresentationScope extends InheritedWidget {
  const PagePresentationScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final PagePresentationController controller;

  static PagePresentationController? maybeRead(BuildContext context) => context
      .getInheritedWidgetOfExactType<PagePresentationScope>()
      ?.controller;

  static Future<void> runCovered(
    BuildContext context,
    Future<void> Function() openPage,
  ) async {
    final controller = maybeRead(context);
    if (controller?.paused ?? false) return;
    final resume = controller?.cover();
    try {
      await openPage();
    } finally {
      resume?.call();
    }
  }

  @override
  bool updateShouldNotify(PagePresentationScope oldWidget) =>
      controller != oldWidget.controller;
}
