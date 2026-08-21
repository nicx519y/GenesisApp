import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_control_metrics.dart';
import '../tokens/genesis_motion.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_control_icons.dart';
import 'genesis_form_primitives.dart';

class GenesisTextField extends StatefulWidget {
  const GenesisTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.supportText,
    this.errorText,
    this.requiredIndicator = false,
    this.focusNode,
    this.leading,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.inputFormatters = const <TextInputFormatter>[],
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.minHeight = GenesisControlMetrics.inputHeight,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: GenesisSpacing.xl,
      vertical: GenesisSpacing.lg,
    ),
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? supportText;
  final String? errorText;
  final bool requiredIndicator;
  final FocusNode? focusNode;
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final List<TextInputFormatter> inputFormatters;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final int? maxLength;
  final int minLines;
  final int? maxLines;
  final double minHeight;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<GenesisTextField> createState() => _GenesisTextFieldState();
}

class _GenesisTextFieldState extends State<GenesisTextField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant GenesisTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocusNode)?.removeListener(
        _handleFocusChange,
      );
      _ownedFocusNode?.dispose();
      _ownedFocusNode = null;
      _focusNode.addListener(_handleFocusChange);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _ownedFocusNode?.dispose();
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});
  void _handleTextChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final hasError = widget.errorText?.trim().isNotEmpty ?? false;
    final focused = _focusNode.hasFocus;
    final counter = widget.maxLength == null
        ? null
        : '${widget.controller.text.characters.length}/${widget.maxLength}';
    final support = hasError ? widget.errorText : widget.supportText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label case final label? when label.isNotEmpty) ...[
          GenesisFieldLabel(
            text: label,
            requiredIndicator: widget.requiredIndicator,
          ),
          const SizedBox(height: GenesisSpacing.md),
        ],
        AnimatedContainer(
          duration: GenesisMotion.fast,
          curve: GenesisMotion.standardCurve,
          constraints: BoxConstraints(minHeight: widget.minHeight),
          padding: widget.contentPadding,
          decoration: BoxDecoration(
            color: widget.enabled
                ? colors.inputBackground
                : colors.surfaceDisabled,
            borderRadius: GenesisRadii.input,
            border: Border.all(
              color: hasError
                  ? colors.danger
                  : focused
                  ? colors.primary
                  : colors.inputBorder,
              width: focused || hasError ? 1.2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines == 1
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: GenesisSpacing.md),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  onEditingComplete: widget.onEditingComplete,
                  inputFormatters: widget.inputFormatters,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  autofocus: widget.autofocus,
                  obscureText: widget.obscureText,
                  maxLength: widget.maxLength,
                  minLines: widget.obscureText ? 1 : widget.minLines,
                  maxLines: widget.obscureText ? 1 : widget.maxLines,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: GenesisTypography.body.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: GenesisTypography.body.copyWith(
                      color: colors.inputHint,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    counterText: '',
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: GenesisSpacing.md),
                widget.trailing!,
              ],
            ],
          ),
        ),
        if (support != null || counter != null) ...[
          const SizedBox(height: GenesisSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (support != null)
                Expanded(
                  child: Text(
                    support,
                    style: GenesisTypography.supporting.copyWith(
                      color: hasError ? colors.danger : colors.textSupporting,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (counter != null) ...[
                const SizedBox(width: GenesisSpacing.md),
                Text(
                  counter,
                  style: GenesisTypography.supporting.copyWith(
                    color: colors.textSupporting,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class GenesisTextArea extends StatelessWidget {
  const GenesisTextArea({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.supportText,
    this.errorText,
    this.requiredIndicator = false,
    this.focusNode,
    this.onChanged,
    this.maxLength,
    this.minLines = 4,
    this.maxLines = 6,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? supportText;
  final String? errorText;
  final bool requiredIndicator;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return GenesisTextField(
      controller: controller,
      label: label,
      hintText: hintText,
      supportText: supportText,
      errorText: errorText,
      requiredIndicator: requiredIndicator,
      focusNode: focusNode,
      onChanged: onChanged,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
    );
  }
}

class GenesisSelectField extends StatelessWidget {
  const GenesisSelectField({
    super.key,
    this.label,
    this.valueText,
    this.hintText,
    this.supportText,
    this.errorText,
    this.requiredIndicator = false,
    this.leading,
    this.trailing,
    required this.onTap,
    this.enabled = true,
  });

  final String? label;
  final String? valueText;
  final String? hintText;
  final String? supportText;
  final String? errorText;
  final bool requiredIndicator;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final hasError = errorText?.trim().isNotEmpty ?? false;
    final value = valueText?.trim() ?? '';
    final support = hasError ? errorText : supportText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label case final label? when label.isNotEmpty) ...[
          GenesisFieldLabel(text: label, requiredIndicator: requiredIndicator),
          const SizedBox(height: GenesisSpacing.md),
        ],
        Semantics(
          button: true,
          enabled: enabled && onTap != null,
          child: Material(
            color: enabled ? colors.inputBackground : colors.surfaceDisabled,
            shape: RoundedRectangleBorder(
              borderRadius: GenesisRadii.input,
              side: BorderSide(
                color: hasError ? colors.danger : colors.inputBorder,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: GenesisControlMetrics.inputHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GenesisSpacing.xl,
                  ),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: GenesisSpacing.md),
                      ],
                      Expanded(
                        child: Text(
                          value.isEmpty ? (hintText ?? '') : value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GenesisTypography.body.copyWith(
                            color: value.isEmpty
                                ? colors.inputHint
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: GenesisSpacing.md),
                      trailing ??
                          GenesisChevronDownIcon(
                            color: colors.iconMuted,
                            width: 16,
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (support != null) ...[
          const SizedBox(height: GenesisSpacing.sm),
          Text(
            support,
            style: GenesisTypography.supporting.copyWith(
              color: hasError ? colors.danger : colors.textSupporting,
            ),
          ),
        ],
      ],
    );
  }
}
