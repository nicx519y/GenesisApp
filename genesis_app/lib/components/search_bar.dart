import 'package:flutter/material.dart';

import '../icons/custom_icon_assets.dart';
import '../ui/genesis_ui.dart';

const double kSearchBarTopPadding = 8;

class SearchBarPlaceholder extends GenesisSearchField {
  const SearchBarPlaceholder({
    super.key,
    super.hintText,
    super.onTap,
    super.controller,
    super.focusNode,
    super.onChanged,
    super.onClear,
    super.textInputAction,
    super.readOnly,
    super.autofocus,
    super.height = 28,
    super.padding,
    super.backgroundColor = const Color(0xFFFAFAFA),
    super.borderColor = const Color(0xFFEBEBEB),
    super.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.iconColor,
    super.iconSize,
    super.iconAsset = searchIconAsset,
    super.hintStyle,
    super.textStyle,
  });
}
