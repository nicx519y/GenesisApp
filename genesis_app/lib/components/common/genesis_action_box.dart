import 'package:flutter/material.dart';

const Color _genesisActionBoxText = Color(0xFF111111);
const Color _genesisActionBoxDestructive = Color(0xFFE8413A);
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
  String cancelLabel = 'Cancel',
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (dialogContext) {
      return GenesisActionBox<T>(
        title: title,
        actions: actions,
        cancelLabel: cancelLabel,
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
    this.cancelLabel = 'Cancel',
  });

  static const double _rowHeight = 62;
  static const double _titleHeight = 74;
  static const double _maxWidth = 318;
  static const BorderRadius _borderRadius = BorderRadius.all(
    Radius.circular(18),
  );

  final String title;
  final List<GenesisActionBoxAction<T>> actions;
  final ValueChanged<T> onActionSelected;
  final VoidCallback onCancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final hasMultipleActions = actions.length > 1;
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.transparent,
      child: FractionallySizedBox(
        widthFactor: 0.72,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: hasMultipleActions
              ? _buildDetachedCancelStyle()
              : _buildAttachedCancelStyle(),
        ),
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
            _TitleRow(title: title),
            const _Divider(),
            for (final action in actions) ...[
              _ActionRow<T>(
                action: action,
                isPreferred: true,
                onSelected: onActionSelected,
              ),
              const _Divider(),
            ],
            _CancelRow(label: cancelLabel, onCancel: onCancel),
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
                _TitleRow(title: title),
                const _Divider(),
                for (var index = 0; index < actions.length; index++) ...[
                  _ActionRow<T>(
                    action: actions[index],
                    isPreferred: index == 0,
                    onSelected: onActionSelected,
                  ),
                  if (index != actions.length - 1) const _Divider(),
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
            child: _CancelRow(label: cancelLabel, onCancel: onCancel),
          ),
        ),
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: GenesisActionBox._titleHeight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _genesisActionBoxText,
              fontSize: 14,
              height: 1.16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.isPreferred,
    required this.onSelected,
  });

  final GenesisActionBoxAction<T> action;
  final bool isPreferred;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final color =
        action.color ??
        (isPreferred ? _genesisActionBoxDestructive : _genesisActionBoxText);
    return InkWell(
      onTap: () => onSelected(action.value),
      child: SizedBox(
        height: GenesisActionBox._rowHeight,
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelRow extends StatelessWidget {
  const _CancelRow({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCancel,
      child: SizedBox(
        height: GenesisActionBox._rowHeight,
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _genesisActionBoxText,
                fontSize: 14,
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
