import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/genesis_color_token.dart';
import '../theme/genesis_semantic_colors.dart';

class GenesisSvgAsset extends StatelessWidget {
  const GenesisSvgAsset.asset(
    this.assetName, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.colorFilter,
    this.excludeFromSemantics = false,
  });

  final String assetName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ColorFilter? colorFilter;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final colors = GenesisSemanticColors.of(context);
    return SvgPicture.asset(
      assetName,
      width: width,
      height: height,
      fit: fit,
      colorFilter: colorFilter,
      excludeFromSemantics: excludeFromSemantics,
      colorMapper: GenesisSvgColorMapper(assetName: assetName, colors: colors),
    );
  }
}

@immutable
class GenesisSvgColorMapper extends ColorMapper {
  const GenesisSvgColorMapper({required this.assetName, required this.colors});

  final String assetName;
  final GenesisSemanticColors colors;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final token = GenesisSvgAssetRegistry.tokenFor(
      assetName,
      color,
      id: id,
      elementName: elementName,
      attributeName: attributeName,
    );
    if (token == null) return color;
    final replacement = colors.color(token);
    if (color.a >= 1) return replacement;
    return replacement.withValues(alpha: replacement.a * color.a);
  }

  @override
  bool operator ==(Object other) {
    return other is GenesisSvgColorMapper &&
        other.assetName == assetName &&
        other.colors.revision == colors.revision &&
        identical(other.colors.config, colors.config);
  }

  @override
  int get hashCode => Object.hash(assetName, colors.revision, colors.config);
}

abstract final class GenesisSvgAssetRegistry {
  static const Map<String, Map<int, GenesisColorToken>> _pathColorTokens =
      <String, Map<int, GenesisColorToken>>{
        'assets/custom-icons/svg/location_chat_ai_char_icon.svg':
            <int, GenesisColorToken>{
              0xFFFFFFFF: GenesisColorToken.assetOverlayLight,
            },
        'assets/custom-icons/svg/bottom_nav_create.svg':
            <int, GenesisColorToken>{
              0xFFFF2442: GenesisColorToken.bottomNavigationProminent,
            },
        'assets/svg/position.svg': <int, GenesisColorToken>{
          0xFFFFFFFF: GenesisColorToken.assetOverlayLight,
        },
      };

  static const Set<String> assetPaths = <String>{
    'assets/custom-icons/svg/add2.svg',
    'assets/custom-icons/svg/ai_char_icon.svg',
    'assets/custom-icons/svg/arrow-change-svgrepo-com.svg',
    'assets/custom-icons/svg/bottom_nav_create.svg',
    'assets/custom-icons/svg/bottom_nav_home.svg',
    'assets/custom-icons/svg/bottom_nav_home_press.svg',
    'assets/custom-icons/svg/bottom_nav_me.svg',
    'assets/custom-icons/svg/bottom_nav_me_press.svg',
    'assets/custom-icons/svg/bottom_nav_messages.svg',
    'assets/custom-icons/svg/bottom_nav_messages_press.svg',
    'assets/custom-icons/svg/bottom_nav_origin.svg',
    'assets/custom-icons/svg/bottom_nav_origin_press.svg',
    'assets/custom-icons/svg/comment.svg',
    'assets/custom-icons/svg/connect-icon.svg',
    'assets/custom-icons/svg/connect.svg',
    'assets/custom-icons/svg/connect_icon.svg',
    'assets/custom-icons/svg/copy.svg',
    'assets/custom-icons/svg/copy_icon.svg',
    'assets/custom-icons/svg/create_origin_basics.svg',
    'assets/custom-icons/svg/create_origin_characters.svg',
    'assets/custom-icons/svg/create_origin_locations.svg',
    'assets/custom-icons/svg/create_origin_story_events.svg',
    'assets/custom-icons/svg/delete-icon.svg',
    'assets/custom-icons/svg/discord-svgrepo-com.svg',
    'assets/custom-icons/svg/discuss_like_filled.svg',
    'assets/custom-icons/svg/discuss_like_outline.svg',
    'assets/custom-icons/svg/discuss_reply.svg',
    'assets/custom-icons/svg/following.svg',
    'assets/custom-icons/svg/icon_gem.svg',
    'assets/custom-icons/svg/icon_gems_stack.svg',
    'assets/custom-icons/svg/info.svg',
    'assets/custom-icons/svg/last_progress.svg',
    'assets/custom-icons/svg/launch_icon.svg',
    'assets/custom-icons/svg/location_chat_ai_char_icon.svg',
    'assets/custom-icons/svg/login_apple.svg',
    'assets/custom-icons/svg/login_google.svg',
    'assets/custom-icons/svg/map_zoom_in.svg',
    'assets/custom-icons/svg/map_zoom_out.svg',
    'assets/custom-icons/svg/notification.svg',
    'assets/custom-icons/svg/origin_top_location.svg',
    'assets/custom-icons/svg/paragraph_icon.svg',
    'assets/custom-icons/svg/play-icon.svg',
    'assets/custom-icons/svg/redstar_char_icon.svg',
    'assets/custom-icons/svg/refresh_2.svg',
    'assets/custom-icons/svg/report-svgrepo-com.svg',
    'assets/custom-icons/svg/ruby.svg',
    'assets/custom-icons/svg/sticker.svg',
    'assets/custom-icons/svg/tick_icon.svg',
    'assets/custom-icons/svg/user_icon.svg',
    'assets/custom-icons/svg/voice.svg',
    'assets/custom-icons/svg/world_tab_cast.svg',
    'assets/custom-icons/svg/world_tab_events.svg',
    'assets/custom-icons/svg/world_tab_status.svg',
    'assets/custom-icons/svg/worlddetail-icon.svg',
    'assets/svg/copy.svg',
    'assets/svg/create-small.svg',
    'assets/svg/create.svg',
    'assets/svg/discuss.svg',
    'assets/svg/eye.svg',
    'assets/svg/gas.svg',
    'assets/svg/home.svg',
    'assets/svg/map-fill.svg',
    'assets/svg/me.svg',
    'assets/svg/messages.svg',
    'assets/svg/origin.svg',
    'assets/svg/position.svg',
    'assets/svg/pregress.svg',
    'assets/svg/save.svg',
    'assets/svg/shared.svg',
    'assets/svg/user-star.svg',
    'assets/svg/user.svg',
    'assets/svg/worldo-logo.svg',
  };

  static GenesisColorToken? tokenFor(
    String assetPath,
    Color source, {
    String? id,
    String? elementName,
    String? attributeName,
  }) {
    if (!assetPaths.contains(assetPath)) return null;
    final argb = source.toARGB32();
    return _pathColorTokens[assetPath]?[argb] ??
        GenesisColorToken.assetSourceByArgb[argb];
  }
}
