part of 'create_form_library.dart';

class CreateKeyboardDismissArea extends StatelessWidget {
  const CreateKeyboardDismissArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}

class CreateFormDeleteButton extends StatelessWidget {
  const CreateFormDeleteButton({
    super.key,
    required this.onPressed,
    this.buttonKey,
    this.decorationKey,
    this.size = 24,
    this.iconSize = 14,
    this.enabled = true,
    this.onDisabledPressed,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.iconColor,
  });

  final VoidCallback onPressed;
  final Key? buttonKey;
  final Key? decorationKey;
  final double size;
  final double iconSize;
  final bool enabled;
  final VoidCallback? onDisabledPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? null : onDisabledPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                key: decorationKey,
                decoration: BoxDecoration(
                  color:
                      backgroundColor ??
                      context.genesisCreateColors.fieldOverlay,
                  border: Border.all(
                    color:
                        borderColor ?? context.genesisCreateColors.inputBorder,
                  ),
                  borderRadius: BorderRadius.circular(borderRadius ?? size / 4),
                ),
              ),
              IconButton(
                key: buttonKey,
                onPressed: enabled ? onPressed : null,
                padding: EdgeInsets.all((size - iconSize) / 2),
                constraints: BoxConstraints.tightFor(width: size, height: size),
                icon: SvgPicture.asset(
                  createFormDeleteIconAsset,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(
                    iconColor ?? context.genesisCreateColors.muted,
                    BlendMode.srcIn,
                  ),
                ),
                splashRadius: size / 2,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateFormCard extends StatelessWidget {
  const CreateFormCard({
    super.key,
    required this.title,
    required this.onDelete,
    required this.child,
    this.deleteEnabled = true,
    this.onDeleteDisabled,
    this.showBorder = true,
    this.titleFontSize = 15,
    this.titleSuffix,
    this.padding,
    this.backgroundColor,
    this.titleFontWeight = FontWeight.w600,
    this.titleColor,
    this.headerBottomSpacing = 0,
    this.deleteButtonSize = 24,
    this.deleteIconSize = 14,
    this.deleteBackgroundColor,
    this.deleteBorderColor,
    this.deleteBorderRadius,
    this.deleteIconColor,
  });

  final String title;
  final VoidCallback onDelete;
  final Widget child;
  final bool deleteEnabled;
  final VoidCallback? onDeleteDisabled;
  final bool showBorder;
  final double titleFontSize;
  final String? titleSuffix;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final FontWeight titleFontWeight;
  final Color? titleColor;
  final double headerBottomSpacing;
  final double deleteButtonSize;
  final double deleteIconSize;
  final Color? deleteBackgroundColor;
  final Color? deleteBorderColor;
  final double? deleteBorderRadius;
  final Color? deleteIconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          padding ??
          (showBorder
              ? const EdgeInsets.fromLTRB(18, 6, 18, 22)
              : const EdgeInsets.symmetric(vertical: 8)),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.genesisColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: showBorder
            ? Border.all(color: context.genesisCreateColors.border, width: 1.2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      if (titleSuffix?.trim().isNotEmpty == true)
                        TextSpan(
                          text: ' ${titleSuffix!.trim()}',
                          style: TextStyle(
                            color: context.genesisCreateColors.hint,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    color: titleColor ?? context.genesisCreateColors.text,
                    fontSize: titleFontSize,
                    fontWeight: titleFontWeight,
                    height: 1.1,
                  ),
                ),
              ),
              CreateFormDeleteButton(
                onPressed: onDelete,
                enabled: deleteEnabled,
                onDisabledPressed: onDeleteDisabled,
                size: deleteButtonSize,
                iconSize: deleteIconSize,
                backgroundColor: deleteBackgroundColor,
                borderColor: deleteBorderColor,
                borderRadius: deleteBorderRadius,
                iconColor: deleteIconColor,
              ),
            ],
          ),
          if (headerBottomSpacing > 0) SizedBox(height: headerBottomSpacing),
          child,
        ],
      ),
    );
  }
}

Future<bool> confirmCreateFormDelete(
  BuildContext context, {
  required String itemLabel,
}) async {
  final confirmed = await showGenesisActionBox<bool>(
    context: context,
    title: 'Delete $itemLabel?',
    titleContent: const Text('This item has content. Delete it anyway?'),
    titleHeight: 104,
    actions: const <GenesisActionBoxAction<bool>>[
      GenesisActionBoxAction<bool>(label: 'Delete', value: true),
    ],
    cancelLabel: 'Cancel',
  );
  return confirmed == true;
}
