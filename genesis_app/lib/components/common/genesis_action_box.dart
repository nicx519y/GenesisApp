import 'package:flutter/material.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import 'genesis_modal_routes.dart';

const Color _genesisActionBoxText = Color(0xFF111111);
const Color _genesisActionBoxDestructive = Color(0xFFFF2344);
const Color _genesisActionBoxDivider = Color(0xFFE8E8EA);

class GenesisActionBoxAction<T> {
  const GenesisActionBoxAction({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final T value;
  final Color? color;
}

Future<T?> showGenesisActionBox<T>({
  required BuildContext context,
  required String title,
  required List<GenesisActionBoxAction<T>> actions,
  Widget? content,
  Widget? titleContent,
  double titleContentSpacing = 8,
  String cancelLabel = 'Cancel',
  bool detachCancel = false,
  double titleHeight = GenesisActionBox.defaultTitleHeight,
  double actionRowHeight = GenesisActionBox.defaultRowHeight,
  double cancelRowHeight = GenesisActionBox.defaultRowHeight,
}) {
  return showGenesisDialog<T>(
    context: context,
    barrierColor: const Color(0x52000000),
    builder: (dialogContext) {
      return GenesisActionBox<T>(
        title: title,
        content: content,
        titleContent: titleContent,
        titleContentSpacing: titleContentSpacing,
        actions: actions,
        cancelLabel: cancelLabel,
        detachCancel: detachCancel,
        titleHeight: titleHeight,
        actionRowHeight: actionRowHeight,
        cancelRowHeight: cancelRowHeight,
        onActionSelected: (value) => Navigator.of(dialogContext).pop(value),
        onCancel: () => Navigator.of(dialogContext).pop(),
      );
    },
  );
}

class GenesisActionBox<T> extends StatelessWidget {
  const GenesisActionBox({
    super.key,
    required this.title,
    required this.actions,
    required this.onActionSelected,
    required this.onCancel,
    this.content,
    this.titleContent,
    this.titleContentSpacing = 8,
    this.cancelLabel = 'Cancel',
    this.detachCancel = false,
    this.titleHeight = defaultTitleHeight,
    this.actionRowHeight = defaultRowHeight,
    this.cancelRowHeight = defaultRowHeight,
  });

  static const double defaultRowHeight = 51;
  static const double defaultTitleHeight = 82;
  static const double _maxWidth = 800;
  static const BorderRadius _borderRadius = BorderRadius.all(
    Radius.circular(18),
  );

  final String title;
  final Widget? content;
  final Widget? titleContent;
  final double titleContentSpacing;
  final List<GenesisActionBoxAction<T>> actions;
  final ValueChanged<T> onActionSelected;
  final VoidCallback onCancel;
  final String cancelLabel;
  final bool detachCancel;
  final double titleHeight;
  final double actionRowHeight;
  final double cancelRowHeight;

  @override
  Widget build(BuildContext context) {
    final useDetachedCancelStyle = detachCancel || actions.length > 1;
    final dialogWidth = (MediaQuery.sizeOf(context).width * 0.7)
        .clamp(0.0, _maxWidth)
        .toDouble();
    return Dialog(
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: dialogWidth),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: dialogWidth,
        child: useDetachedCancelStyle
            ? _buildDetachedCancelStyle()
            : _buildAttachedCancelStyle(),
      ),
    );
  }

  Widget _buildAttachedCancelStyle() {
    return ClipRRect(
      key: const ValueKey('genesis-action-box-attached-cancel'),
      borderRadius: _borderRadius,
      child: Material(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TitleRow(
              title: title,
              height: titleHeight,
              content: titleContent,
              contentSpacing: titleContentSpacing,
            ),
            if (content case final content?) content,
            if (actions.isNotEmpty) ...[
              const _Divider(),
              for (final action in actions) ...[
                _ActionRow<T>(
                  action: action,
                  height: actionRowHeight,
                  isPreferred: true,
                  onSelected: onActionSelected,
                ),
                const _Divider(),
              ],
            ],
            _CancelRow(
              label: cancelLabel,
              height: cancelRowHeight,
              onCancel: onCancel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetachedCancelStyle() {
    return Column(
      key: const ValueKey('genesis-action-box-detached-cancel'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: _borderRadius,
          child: Material(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TitleRow(
                  title: title,
                  height: titleHeight,
                  content: titleContent,
                  contentSpacing: titleContentSpacing,
                ),
                if (content case final content?) content,
                if (actions.isNotEmpty) ...[
                  const _Divider(),
                  for (var index = 0; index < actions.length; index++) ...[
                    _ActionRow<T>(
                      action: actions[index],
                      height: actionRowHeight,
                      isPreferred: index == 0,
                      onSelected: onActionSelected,
                    ),
                    if (index != actions.length - 1) const _Divider(),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: _borderRadius,
          child: Material(
            color: Colors.white,
            child: _CancelRow(
              label: cancelLabel,
              height: cancelRowHeight,
              onCancel: onCancel,
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.height,
    required this.content,
    required this.contentSpacing,
  });

  final String title;
  final double height;
  final Widget? content;
  final double contentSpacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('genesis-action-box-title-row'),
      height: height,
      width: double.infinity,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _genesisActionBoxText,
                  fontSize: 15,
                  height: 1.16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (content case final content?) ...[
                SizedBox(height: contentSpacing),
                content,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.height,
    required this.isPreferred,
    required this.onSelected,
  });

  final GenesisActionBoxAction<T> action;
  final double height;
  final bool isPreferred;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final color =
        action.color ??
        (isPreferred ? _genesisActionBoxDestructive : _genesisActionBoxText);
    return InkWell(
      onTap: () {
        GenesisTelemetry.click(
          actionId: 'action_box.${_actionSlug(action.label)}',
          component: 'GenesisActionBoxAction',
          enabled: true,
          data: <String, Object?>{'label': action.label},
        );
        onSelected(action.value);
      },
      child: SizedBox(
        key: const ValueKey('genesis-action-box-action-row'),
        height: height,
        width: double.infinity,
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelRow extends StatelessWidget {
  const _CancelRow({
    required this.label,
    required this.height,
    required this.onCancel,
  });

  final String label;
  final double height;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        GenesisTelemetry.click(
          actionId: 'action_box.${_actionSlug(label)}',
          component: 'GenesisActionBoxCancel',
          enabled: true,
          data: <String, Object?>{'label': label},
        );
        onCancel();
      },
      child: SizedBox(
        key: const ValueKey('genesis-action-box-cancel-row'),
        height: height,
        width: double.infinity,
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _genesisActionBoxText,
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _actionSlug(String label) {
  final normalized = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'unknown' : normalized;
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: _genesisActionBoxDivider,
    );
  }
}
