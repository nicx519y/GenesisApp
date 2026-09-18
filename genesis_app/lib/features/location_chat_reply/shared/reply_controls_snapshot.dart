import 'reply_action_state.dart';

typedef LocationChatReplyActionFlags = ({
  bool regenerate,
  bool goOn,
  bool edit,
  bool inspiration,
});

/// Immutable decisions for one toolbar evaluation.
typedef LocationChatReplyControlsSnapshot = ({
  bool hidden,
  LocationChatReplyActionState regenerate,
  LocationChatReplyActionState goOn,
  LocationChatReplyActionState edit,
  LocationChatReplyActionState inspiration,
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
    if (backendPending || presentationSettled || discardPending) {
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
        canExplainRegenerateLimit: false,
      ),
    );
  }
}

LocationChatReplyControlsSnapshot resolveLocationChatReplyControls({
  required bool hidden,
  required bool blocked,
  required bool showWhenUnavailable,
  required LocationChatReplyActionFlags supported,
  required LocationChatReplyActionFlags canInvoke,
  required LocationChatReplyActionFlags busy,
  required LocationChatReplyActionFlags active,
  required bool regenerationContentRendering,
  required bool regenerateLimitReached,
}) {
  final limitReached = !busy.regenerate && regenerateLimitReached;
  final otherThanRegenerate = active.goOn || active.edit || active.inspiration;
  LocationChatReplyActionState resolve({
    required bool busy,
    required bool supported,
    required bool otherActive,
    required bool canInvoke,
  }) => hidden
      ? LocationChatReplyActionState.none
      : resolveLocationChatReplyActionState(
          showWhenUnavailable: showWhenUnavailable,
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
          ),
    goOn: resolve(
      busy: busy.goOn,
      supported: supported.goOn,
      otherActive: active.regenerate || active.edit || active.inspiration,
      canInvoke: canInvoke.goOn,
    ),
    edit: resolve(
      busy: busy.edit,
      supported: supported.edit,
      otherActive: active.regenerate || active.goOn || active.inspiration,
      canInvoke: canInvoke.edit,
    ),
    inspiration: resolve(
      busy: busy.inspiration,
      supported: supported.inspiration,
      otherActive: active.regenerate || active.goOn || active.edit,
      canInvoke: canInvoke.inspiration,
    ),
    canExplainRegenerateLimit:
        !hidden && limitReached && !blocked && !otherThanRegenerate,
  );
}
