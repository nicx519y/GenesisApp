import 'reply_action_state.dart';

typedef LocationChatReplyActionFlags = ({
  bool regenerate,
  bool goOn,
  bool edit,
  bool inspiration,
  bool camera,
});

/// Immutable decisions for one toolbar evaluation.
typedef LocationChatReplyControlsSnapshot = ({
  bool hidden,
  LocationChatReplyActionState regenerate,
  LocationChatReplyActionState goOn,
  LocationChatReplyActionState edit,
  LocationChatReplyActionState inspiration,
  LocationChatReplyActionState camera,
  bool canExplainRegenerateLimit,
});

typedef LocationChatRenderedReplyControls = ({
  LocationChatReplyControlsSnapshot actions,
  bool visible,
});

/// Holds the last pending toolbar until terminal data AND its presentation have
/// settled. Network completion remains independent of this UI-only barrier.
class LocationChatReplyControlsRenderGate {
  LocationChatRenderedReplyControls? _previous;

  void reset() => _previous = null;

  LocationChatRenderedReplyControls resolve(
    LocationChatRenderedReplyControls next, {
    required bool backendPending,
    required bool presentationSettled,
    bool discardPending = false,
  }) {
    final operationPending = [
      next.actions.regenerate,
      next.actions.goOn,
      next.actions.edit,
      next.actions.inspiration,
      next.actions.camera,
    ].contains(LocationChatReplyActionState.busy);
    // An explicit submission owns its busy state even if a card refresh has
    // just started a presentation transition. Only terminal controls are held.
    if (backendPending ||
        operationPending ||
        presentationSettled ||
        discardPending) {
      return _previous = next;
    }
    final retained = _previous;
    final actions = retained?.actions ?? next.actions;
    // A terminal-only arrival may have no preceding busy frame. Never retain
    // clickable actions from the previous round in that case.
    LocationChatReplyActionState hold(LocationChatReplyActionState state) =>
        state == LocationChatReplyActionState.idle
        ? LocationChatReplyActionState.disabled
        : state;
    return (
      visible: retained?.visible ?? false,
      actions: (
        hidden: actions.hidden,
        regenerate: hold(actions.regenerate),
        goOn: hold(actions.goOn),
        edit: hold(actions.edit),
        inspiration: hold(actions.inspiration),
        camera: hold(actions.camera),
        canExplainRegenerateLimit: false,
      ),
    );
  }
}

LocationChatReplyControlsSnapshot resolveLocationChatReplyControls({
  required bool hidden,
  required bool blocked,
  required LocationChatReplyActionFlags showWhenUnavailable,
  required LocationChatReplyActionFlags supported,
  required LocationChatReplyActionFlags canInvoke,
  required LocationChatReplyActionFlags busy,
  required LocationChatReplyActionFlags active,
  required bool regenerationContentRendering,
  required bool regenerateLimitReached,
}) {
  final limitReached = !busy.regenerate && regenerateLimitReached;
  final otherThanRegenerate =
      active.goOn || active.edit || active.inspiration || active.camera;
  LocationChatReplyActionState resolve({
    required bool busy,
    required bool supported,
    required bool otherActive,
    required bool canInvoke,
    required bool retainUnavailable,
  }) => hidden
      ? LocationChatReplyActionState.none
      : resolveLocationChatReplyActionState(
          showWhenUnavailable: retainUnavailable,
          busy: busy,
          supported: supported,
          otherReplyOperationActive: otherActive,
          canInvoke: !blocked && canInvoke,
        );
  return (
    hidden: hidden,
    regenerate: !hidden && (regenerationContentRendering || limitReached)
        ? LocationChatReplyActionState.disabled
        : resolve(
            busy: busy.regenerate,
            supported: supported.regenerate,
            otherActive: otherThanRegenerate,
            canInvoke: canInvoke.regenerate,
            retainUnavailable: showWhenUnavailable.regenerate,
          ),
    goOn: resolve(
      busy: busy.goOn,
      supported: supported.goOn,
      otherActive:
          active.regenerate ||
          active.edit ||
          active.inspiration ||
          active.camera,
      canInvoke: canInvoke.goOn,
      retainUnavailable: showWhenUnavailable.goOn,
    ),
    edit: resolve(
      busy: busy.edit,
      supported: supported.edit,
      otherActive:
          active.regenerate ||
          active.goOn ||
          active.inspiration ||
          active.camera,
      canInvoke: canInvoke.edit,
      retainUnavailable: showWhenUnavailable.edit,
    ),
    inspiration: resolve(
      busy: busy.inspiration,
      supported: supported.inspiration,
      otherActive:
          active.regenerate || active.goOn || active.edit || active.camera,
      canInvoke: canInvoke.inspiration,
      retainUnavailable: showWhenUnavailable.inspiration,
    ),
    camera: resolve(
      busy: busy.camera,
      supported: supported.camera,
      otherActive:
          active.regenerate || active.goOn || active.edit || active.inspiration,
      canInvoke: canInvoke.camera,
      retainUnavailable: showWhenUnavailable.camera,
    ),
    canExplainRegenerateLimit:
        !hidden && limitReached && !blocked && !otherThanRegenerate,
  );
}
