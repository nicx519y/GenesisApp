import 'package:flutter/widgets.dart';

@immutable
class GenesisUiInteraction {
  const GenesisUiInteraction({
    required this.actionId,
    required this.component,
    required this.enabled,
    this.data = const <String, Object?>{},
  });

  final String actionId;
  final String component;
  final bool enabled;
  final Map<String, Object?> data;
}

typedef GenesisButtonInteraction = GenesisUiInteraction;
typedef GenesisButtonInteractionObserver =
    void Function(GenesisUiInteraction interaction);

/// Bridges UI-only components to application concerns such as telemetry.
class GenesisUiInteractionScope extends InheritedWidget {
  const GenesisUiInteractionScope({
    super.key,
    required this.onButtonInteraction,
    required super.child,
  });

  final GenesisButtonInteractionObserver onButtonInteraction;

  static void notifyButton(
    BuildContext context,
    GenesisUiInteraction interaction,
  ) {
    context
        .getInheritedWidgetOfExactType<GenesisUiInteractionScope>()
        ?.onButtonInteraction(interaction);
  }

  static void notify(BuildContext context, GenesisUiInteraction interaction) =>
      notifyButton(context, interaction);

  @override
  bool updateShouldNotify(covariant GenesisUiInteractionScope oldWidget) {
    return onButtonInteraction != oldWidget.onButtonInteraction;
  }
}
