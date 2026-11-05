import 'package:flutter/foundation.dart';

/// Presentation state of one reply action for the current conversation round.
enum LocationChatReplyActionState { none, disabled, busy, idle }

enum LocationChatReplyActionId { regenerate, goOn, edit, inspiration, camera }

/// The toolbar's public state interface. Business callers change states;
/// the shared renderer owns visibility, geometry, and interaction.
class LocationChatReplyToolbarState {
  LocationChatReplyToolbarState(
    Map<LocationChatReplyActionId, LocationChatReplyActionState> states,
  ) : _states = Map.unmodifiable(states),
      _busyAction = states.entries
          .where((entry) => entry.value == LocationChatReplyActionState.busy)
          .firstOrNull
          ?.key;

  final Map<LocationChatReplyActionId, LocationChatReplyActionState> _states;
  final LocationChatReplyActionId? _busyAction;

  bool get isBusy => _busyAction != null;

  LocationChatReplyActionState operator [](LocationChatReplyActionId id) {
    final state = _states[id] ?? LocationChatReplyActionState.none;
    if (state == LocationChatReplyActionState.none) return state;
    return isBusy && id != _busyAction
        ? LocationChatReplyActionState.disabled
        : state;
  }

  LocationChatReplyToolbarState withState(
    LocationChatReplyActionId id,
    LocationChatReplyActionState state,
  ) => LocationChatReplyToolbarState({
    for (final entry in _states.entries)
      entry.key:
          state == LocationChatReplyActionState.busy &&
              entry.value == LocationChatReplyActionState.busy
          ? LocationChatReplyActionState.idle
          : entry.value,
    id: state,
  });

  LocationChatReplyToolbarState withHidden(
    Set<LocationChatReplyActionId> ids,
  ) => LocationChatReplyToolbarState({
    ..._states,
    for (final id in ids) id: LocationChatReplyActionState.none,
  });

  LocationChatReplyToolbarState withBusy(LocationChatReplyActionId busyId) =>
      withState(busyId, LocationChatReplyActionState.busy);
}

/// Keep the submitted action set while busy. New content either retires busy
/// through the feature contract or changes its visibility context (e.g. image).
/// Capability updates for the existing bubble must not change that context.
class LocationChatReplyToolbarPresentation {
  LocationChatReplyToolbarState? _previous;
  Object? _visibilityContext;

  LocationChatReplyToolbarState resolve(
    LocationChatReplyToolbarState next, {
    Object? visibilityContext,
  }) {
    final previous = _previous;
    final sameContext = visibilityContext == _visibilityContext;
    final displayed = previous != null && next.isBusy && sameContext
        ? LocationChatReplyToolbarState({
            for (final id in LocationChatReplyActionId.values)
              id: id == next._busyAction
                  ? LocationChatReplyActionState.busy
                  : previous[id] == LocationChatReplyActionState.none
                  ? LocationChatReplyActionState.none
                  : LocationChatReplyActionState.disabled,
          })
        : next;
    _visibilityContext = visibilityContext;
    return _previous = displayed;
  }
}

/// Common invocation contract; feature-specific data stays on each feature.
class LocationChatReplyAction {
  const LocationChatReplyAction({required this.onInvoke, required this.state});
  const LocationChatReplyAction.disabled()
    : onInvoke = null,
      state = LocationChatReplyActionState.none;

  final VoidCallback? onInvoke;
  final LocationChatReplyActionState state;
  bool get enabled => state == LocationChatReplyActionState.idle;
  bool get busy => state == LocationChatReplyActionState.busy;
  VoidCallback? get invocation => enabled ? onInvoke : null;
}

LocationChatReplyActionState resolveLocationChatReplyActionState({
  required bool busy,
  required bool supported,
  required bool otherReplyOperationActive,
  required bool canInvoke,
  bool showWhenUnavailable = false,
}) {
  if (busy) return LocationChatReplyActionState.busy;
  if (!supported) return LocationChatReplyActionState.none;
  if (otherReplyOperationActive) {
    return LocationChatReplyActionState.disabled;
  }
  return canInvoke
      ? LocationChatReplyActionState.idle
      : showWhenUnavailable
      ? LocationChatReplyActionState.disabled
      : LocationChatReplyActionState.none;
}
