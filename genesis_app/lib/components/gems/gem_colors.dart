import 'package:flutter/material.dart';

import '../../ui/theme/genesis_color_token.dart';
import '../../ui/theme/genesis_semantic_colors.dart';

Color gemAccentColor(GenesisSemanticColors colors) =>
    colors.color(GenesisColorToken.gemAccent);
Color gemSoldOutBorderColor(GenesisSemanticColors colors) =>
    colors.color(GenesisColorToken.gemSoldOutBorder);
Color gemSoldOutForegroundColor(GenesisSemanticColors colors) =>
    colors.color(GenesisColorToken.gemSoldOutForeground);
Color gemTaskActionColor(GenesisSemanticColors colors) =>
    colors.color(GenesisColorToken.gemTaskAction);
Color gemTaskClaimedForegroundColor(GenesisSemanticColors colors) =>
    colors.color(GenesisColorToken.gemSoldOutForeground);
Color gemTaskProgressForegroundColor(GenesisSemanticColors colors) =>
    colors.color(GenesisColorToken.success);
