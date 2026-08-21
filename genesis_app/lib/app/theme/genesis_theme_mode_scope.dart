import 'package:flutter/widgets.dart';

import 'genesis_theme_mode_controller.dart';

class GenesisThemeModeScope
    extends InheritedNotifier<GenesisThemeModeController> {
  const GenesisThemeModeScope({
    super.key,
    required GenesisThemeModeController controller,
    required super.child,
  }) : super(notifier: controller);

  static GenesisThemeModeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'No GenesisThemeModeScope found in this context.',
    );
    return controller!;
  }

  static GenesisThemeModeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GenesisThemeModeScope>()
      ?.notifier;
}
