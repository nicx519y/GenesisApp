import '../../../l10n/genesis_l10n.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../ui/tokens/genesis_colors.dart';
import 'reply_action_state.dart';
import 'reply_touch_target.dart';

class LocationChatReplyActionButton {
  const LocationChatReplyActionButton({
    required this.id,
    required this.label,
    required this.iconAsset,
    this.onTap,
    this.onBeforeInvoke,
    this.onDisabledTap,
    this.expanded,
  });

  final LocationChatReplyActionId id;
  final String label;
  final String iconAsset;
  final VoidCallback? onTap, onBeforeInvoke, onDisabledTap;
  final bool? expanded;
}

/// Visible left actions pack in order; the camera remains right-aligned.
class LocationChatReplyActionButtons extends StatefulWidget {
  const LocationChatReplyActionButtons({
    super.key,
    required this.state,
    required this.buttons,
    this.visibilityContext,
  });

  static const centerSpacing = 50.0;
  final LocationChatReplyToolbarState state;
  final List<LocationChatReplyActionButton> buttons;

  /// Changes only when newly displayed content needs different visibility rules.
  final Object? visibilityContext;

  @override
  State<LocationChatReplyActionButtons> createState() =>
      _ReplyActionButtonsState();
}

class _ReplyActionButtonsState extends State<LocationChatReplyActionButtons> {
  final _presentation = LocationChatReplyToolbarPresentation();

  @override
  Widget build(BuildContext context) {
    final state = _presentation.resolve(
      widget.state,
      visibilityContext: widget.visibilityContext,
    );
    final leftActions = LocationChatReplyActionId.values
        .where(
          (id) =>
              id != LocationChatReplyActionId.camera &&
              state[id] != LocationChatReplyActionState.none &&
              widget.buttons.any((button) => button.id == id),
        )
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        const slotSize = LocationChatReplyFeatureButton.layoutSize;
        const preferredGap =
            LocationChatReplyActionButtons.centerSpacing - slotSize;
        // Keep the camera aligned on narrow viewports without overflowing the
        // row; normal widths retain the existing left-action spacing.
        final gap = leftActions.length < 2
            ? 0.0
            : math.min(
                preferredGap,
                math.max(
                  0.0,
                  (constraints.maxWidth - (leftActions.length + 1) * slotSize) /
                      (leftActions.length - 1),
                ),
              );
        return Row(
          key: const ValueKey('location-chat-reply-actions-four-icons'),
          children: [
            for (final (index, id) in leftActions.indexed) ...[
              if (index > 0) SizedBox(width: gap),
              _slot(id, state),
            ],
            const Spacer(),
            _slot(LocationChatReplyActionId.camera, state),
          ],
        );
      },
    );
  }

  Widget _slot(
    LocationChatReplyActionId id,
    LocationChatReplyToolbarState state,
  ) {
    final button = widget.buttons
        .where((button) => button.id == id)
        .firstOrNull;
    if (button == null) {
      return const SizedBox.square(
        dimension: LocationChatReplyFeatureButton.layoutSize,
      );
    }
    final key = switch (id) {
      LocationChatReplyActionId.regenerate => 'location-chat-regenerate',
      LocationChatReplyActionId.goOn => 'location-chat-go-on',
      LocationChatReplyActionId.edit => 'location-chat-edit',
      LocationChatReplyActionId.inspiration => 'location-chat-inspiration',
      LocationChatReplyActionId.camera => 'location-chat-take-photo',
    };
    return LocationChatReplyFeatureButton(
      key: ValueKey(key),
      label: button.label,
      iconAsset: button.iconAsset,
      state: state[id],
      onTap: state[id] == LocationChatReplyActionState.idle
          ? button.onTap
          : null,
      onBeforeInvoke: button.onBeforeInvoke,
      onDisabledTap: state.isBusy ? null : button.onDisabledTap,
      expanded: button.expanded,
    );
  }
}

/// Shared visual primitive. Feature directories own the semantic label, icon,
/// availability, and invocation policy.
class LocationChatReplyFeatureButton extends StatelessWidget {
  const LocationChatReplyFeatureButton({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.onTap,
    this.onBeforeInvoke,
    this.onDisabledTap,
    this.expanded,
    required this.state,
  });

  static const double size = 48;
  static const double layoutSize = 32;
  static const double iconSize = 17;

  final String label;
  final String iconAsset;
  final VoidCallback? onTap;
  final VoidCallback? onBeforeInvoke;
  final VoidCallback? onDisabledTap;
  final bool? expanded;
  final LocationChatReplyActionState state;

  @override
  Widget build(BuildContext context) {
    if (state == LocationChatReplyActionState.none) {
      return const SizedBox.square(dimension: layoutSize);
    }
    final loading = state == LocationChatReplyActionState.busy;
    final enabled = state == LocationChatReplyActionState.idle && onTap != null;
    final disabledTap = state == LocationChatReplyActionState.disabled
        ? onDisabledTap
        : null;
    final invoke = enabled
        ? () {
            onBeforeInvoke?.call();
            onTap!();
          }
        : disabledTap;
    return LocationChatReplyTouchTarget(
      onTap: invoke,
      touchSize: size,
      child: Semantics(
        container: true,
        label: label,
        enabled: enabled || disabledTap != null,
        button: true,
        expanded: expanded,
        liveRegion: loading,
        value: loading ? GenesisL10n.current.chatLoading : null,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: invoke,
            child: SizedBox.square(
              dimension: layoutSize,
              child: Center(
                child: loading
                    ? const SizedBox.square(
                        key: ValueKey('location-chat-reply-feature-loading'),
                        dimension: iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          strokeCap: StrokeCap.round,
                          color: GenesisColors.darkTextPrimary,
                        ),
                      )
                    : SvgPicture.asset(
                        iconAsset,
                        width: iconSize,
                        height: iconSize,
                        colorFilter: ColorFilter.mode(
                          state == LocationChatReplyActionState.disabled
                              ? GenesisColors.darkTextTertiary
                              : GenesisColors.darkTextPrimary,
                          BlendMode.srcIn,
                        ),
                        excludeFromSemantics: true,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
