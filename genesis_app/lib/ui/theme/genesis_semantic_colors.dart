import 'package:flutter/material.dart';

import 'genesis_color_token.dart';

@immutable
class GenesisSemanticColorConfig {
  const GenesisSemanticColorConfig(this.values);

  final Map<GenesisColorToken, Color> values;

  Color color(GenesisColorToken token) {
    final value = values[token];
    assert(value != null, 'Missing semantic color token: ${token.id}');
    return value ?? const Color(0xFFFF00FF);
  }

  GenesisSemanticColorConfig copyWithOverrides(
    Map<GenesisColorToken, Color> overrides,
  ) {
    return GenesisSemanticColorConfig(<GenesisColorToken, Color>{
      ...values,
      ...overrides,
    });
  }
}

abstract final class GenesisColorDefaults {
  static const Map<int, int> _darkAssetArgb = <int, int>{
    0xFF000000: 0xFFF2F2F2,
    0xFF0F0F0F: 0xFFF2F2F2,
    0xFF111111: 0xFFF2F2F2,
    0xFF171717: 0xFFECECEC,
    0xFF176F6A: 0xFF56B8B1,
    0xFF292929: 0xFFE0E0E0,
    0xFF2D5F9A: 0xFF9FC1FF,
    0xFF333333: 0xFFD8D8D8,
    0xFF338960: 0xFF00C27A,
    0xFF34A853: 0xFF34A853,
    0xFF4285F4: 0xFF91B3FF,
    0xFF444444: 0xFFC8C8C8,
    0xFF4D4D4D: 0xFFC0C0C0,
    0xFF5865F2: 0xFF7B85FF,
    0xFF666666: 0xFFA3A7AE,
    0xFF6E6E72: 0xFFA9ABB0,
    0xFF888888: 0xFFB8BBC0,
    0xFF8A8478: 0xFFB8B2A7,
    0xFF9B6B18: 0xFFD6A84C,
    0xFFA90035: 0xFFA90035,
    0xFFB90034: 0xFFB90034,
    0xFFBD0035: 0xFFBD0035,
    0xFFC40038: 0xFFC40038,
    0xFFC51F3A: 0xFFC51F3A,
    0xFFC7003C: 0xFFC7003C,
    0xFFD40037: 0xFFD40037,
    0xFFD8003B: 0xFFD8003B,
    0xFFD82B49: 0xFFD82B49,
    0xFFD90037: 0xFFD90037,
    0xFFE93650: 0xFFE93650,
    0xFFEA4335: 0xFFEA4335,
    0xFFEB3D56: 0xFFEB3D56,
    0xFFF14B62: 0xFFF14B62,
    0xFFF42C47: 0xFFF42C47,
    0xFFFBBC05: 0xFFF5C37B,
    0xFFFF2442: 0xFFA78BFA,
    0xFFFF7F92: 0xFFFF7F92,
    0xFFFF8CA0: 0xFFFF8CA0,
    0xFFFFD4DC: 0xFFFFD4DC,
    0xFFFFFFFF: 0xFF121212,
  };

  static final GenesisSemanticColorConfig light =
      GenesisSemanticColorConfig(<GenesisColorToken, Color>{
        GenesisColorToken.surface: const Color(0xFFFFFFFF),
        GenesisColorToken.surfaceMuted: const Color(0xFFF9F9F9),
        GenesisColorToken.surfaceInput: const Color(0xFFF2F2F2),
        GenesisColorToken.surfacePanel: const Color(0xFFF5F5F7),
        GenesisColorToken.surfaceElevated: const Color(0xFFFFFFFF),
        GenesisColorToken.surfaceOverlay: const Color(0x8A000000),
        GenesisColorToken.surfaceOverlaySubtle: const Color(0x61000000),
        GenesisColorToken.detailSheetBarrier: const Color(0x2E000000),
        GenesisColorToken.bottomNavigationBackground: const Color(0xFFFFFFFF),
        GenesisColorToken.listItemSurface: const Color(0xFFFFFFFF),
        GenesisColorToken.neutralControlSurface: const Color(0xFFE5E5E5),
        GenesisColorToken.contentPanelSurface: const Color(0xFFF4F4F8),
        GenesisColorToken.subtleButtonSurface: const Color(0xFFE1E1E3),
        GenesisColorToken.accountCardSurface: const Color(0xFFF4F4F5),
        GenesisColorToken.notificationMenuSurface: const Color(0xFFDDF2EF),
        GenesisColorToken.followerMenuSurface: const Color(0xFFFFF0D8),
        GenesisColorToken.commentMenuSurface: const Color(0xFFE9F0FF),
        GenesisColorToken.detailMutedSurface: const Color(0xFFE9EDF2),
        GenesisColorToken.detailPanelSurface: const Color(0xFFF4F5F8),
        GenesisColorToken.detailPlaceholderSurface: const Color(0xFFEFF1F4),
        GenesisColorToken.detailPillSurface: const Color(0xFFE1E4EA),
        GenesisColorToken.detailCloseSurface: const Color(0xFFF3F3F5),
        GenesisColorToken.worldTagSurface: const Color(0xFFEBEFF2),
        GenesisColorToken.originCharacterTagSurface: const Color(0xFFF1F3F6),
        GenesisColorToken.originListTagSurface: const Color(0xFFF1F3F6),
        GenesisColorToken.roleSelectorSurface: const Color(0xFFEDEDEF),
        GenesisColorToken.roleSelectorSelectedSurface: const Color(0xFFFFFFFF),
        GenesisColorToken.worldGlobalEventSurface: const Color(0xFFF0F8F4),
        GenesisColorToken.actionMenuSurface: const Color(0xFF666666),
        GenesisColorToken.searchCompactSurface: const Color(0xFFFAFAFA),
        GenesisColorToken.searchHistorySurface: const Color(0xFFF1F3F6),
        GenesisColorToken.gemProductSurface: const Color(0xFFFFFFFF),
        GenesisColorToken.gemLoadingSurface: const Color(0xFFF7F7F7),
        GenesisColorToken.gemEmptySurface: const Color(0xFFF8F8F8),
        GenesisColorToken.discussQuoteSurface: const Color(0xFFF6F7F9),
        GenesisColorToken.discussRepliesSurface: const Color(0xFFF5F6F7),
        GenesisColorToken.discussComposerSurface: const Color(0xFFF2F2F2),
        GenesisColorToken.mediaErrorOverlay: const Color(0x7A000000),
        GenesisColorToken.mediaRemoveSurface: const Color(0xFF4F4F4F),
        GenesisColorToken.mediaControlShadow: const Color(0x24000000),
        GenesisColorToken.skeletonBase: const Color(0xFFE8EBF0),
        GenesisColorToken.skeletonHighlight: const Color(0xFFF6F7F9),
        GenesisColorToken.profileGemSurface: const Color(0xFFFFF4F6),
        GenesisColorToken.mediaControlOverlay: const Color(0x66000000),
        GenesisColorToken.textPrimary: const Color(0xFF111111),
        GenesisColorToken.textSecondary: const Color(0xFF6F6F6F),
        GenesisColorToken.textTertiary: const Color(0xFF8D8D8D),
        GenesisColorToken.textDisabled: const Color(0xFF9E9E9E),
        GenesisColorToken.textInverse: const Color(0xFFFFFFFF),
        GenesisColorToken.textLink: const Color(0xFF4B6192),
        GenesisColorToken.textEmailLink: const Color(0xFF3E5B8A),
        GenesisColorToken.iconPrimary: const Color(0xFF111111),
        GenesisColorToken.iconSecondary: const Color(0xFF666666),
        GenesisColorToken.detailPlaceholderIcon: const Color(0xFF9A9A9A),
        GenesisColorToken.navigationChevron: const Color(0xFFB5B5B5),
        GenesisColorToken.textStrong: const Color(0xFF333333),
        GenesisColorToken.textSecondaryStrong: const Color(0xFF666666),
        GenesisColorToken.textMetadata: const Color(0xFF888888),
        GenesisColorToken.textRole: const Color(0xFF8F8F8F),
        GenesisColorToken.textTimestamp: const Color(0xFF8B8B8B),
        GenesisColorToken.textMuted: const Color(0xFF999999),
        GenesisColorToken.textSectionTitle: const Color(0xFF1D1D1D),
        GenesisColorToken.textOnDark: const Color(0xFFFFFFFF),
        GenesisColorToken.textEmptyState: const Color(0xFF7A7A7A),
        GenesisColorToken.textCounter: const Color(0xFF8C8C8C),
        GenesisColorToken.textFormHint: const Color(0xFF777777),
        GenesisColorToken.textListMetadata: const Color(0xFF8A8A8A),
        GenesisColorToken.textDeveloperDisabled: const Color(0xFFA8A8AD),
        GenesisColorToken.textHighEmphasis: const Color(0xDD000000),
        GenesisColorToken.textDetailBody: const Color(0xFF444444),
        GenesisColorToken.originCharacterSubtitle: const Color(0xC7000000),
        GenesisColorToken.roleSelectorInactiveText: const Color(0xFF595959),
        GenesisColorToken.searchCancelText: const Color(0xFF222222),
        GenesisColorToken.originListTagText: const Color(0xFF4B6192),
        GenesisColorToken.discussReplyText: const Color(0xFF60636A),
        GenesisColorToken.discussComposerHint: const Color(0xFFB8B8B8),
        GenesisColorToken.messageMutedText: const Color(0xFF94979E),
        GenesisColorToken.messageMetadataText: const Color(0xFF8A8D93),
        GenesisColorToken.messageOriginLinkText: const Color(0xFF2F4F7A),
        GenesisColorToken.border: const Color(0xFFE6E6E8),
        GenesisColorToken.borderStrong: const Color(0xFFDCDCDC),
        GenesisColorToken.divider: const Color(0xFFE7E7E7),
        GenesisColorToken.borderFocus: const Color(0xFF338960),
        GenesisColorToken.listDivider: const Color(0xFFEFEFEF),
        GenesisColorToken.detailDivider: const Color(0xFFEDEDED),
        GenesisColorToken.discussQuoteBorder: const Color(0xFFD7DBE3),
        GenesisColorToken.discussRepliesBorder: const Color(0xFFD9DDE2),
        GenesisColorToken.bottomSheetHandle: const Color(0xFFD2D2D2),
        GenesisColorToken.attachmentBorder: const Color(0xFFE3E3E3),
        GenesisColorToken.roleSelectorBorder: const Color(0xFFE3E3E7),
        GenesisColorToken.roleFormBorder: const Color(0xFFE1E1E6),
        GenesisColorToken.searchCompactBorder: const Color(0xFFEBEBEB),
        GenesisColorToken.gemProductBorder: const Color(0xFFEBEBEB),
        GenesisColorToken.gemSoldOutBorder: const Color(0xFFFFD1D8),
        GenesisColorToken.profileGemBorder: const Color(0xFFFFE0E6),
        GenesisColorToken.brand: const Color(0xFF338960),
        GenesisColorToken.brandBright: const Color(0xFF00C27A),
        GenesisColorToken.brandDisabled: const Color(0xFFBFD8CD),
        GenesisColorToken.actionDisabledForeground: const Color(0xFFFFFFFF),
        GenesisColorToken.create: const Color(0xFFFF2442),
        GenesisColorToken.bottomNavigationProminent: const Color(0xFFFF2442),
        GenesisColorToken.danger: const Color(0xFFFF2442),
        GenesisColorToken.success: const Color(0xFF338960),
        GenesisColorToken.successContainer: const Color(0xFFE8F5EF),
        GenesisColorToken.warning: const Color(0xFF92400E),
        GenesisColorToken.warningContainer: const Color(0xFFFEF3C7),
        GenesisColorToken.info: const Color(0xFF2D5F9A),
        GenesisColorToken.infoContainer: const Color(0xFFEAF2FF),
        GenesisColorToken.neutralControlForeground: const Color(0xFF000000),
        GenesisColorToken.neutralControlDisabledForeground: const Color(
          0x8A000000,
        ),
        GenesisColorToken.destructiveControl: const Color(0xFFFF4D4F),
        GenesisColorToken.messagePositiveState: const Color(0xFF25845C),
        GenesisColorToken.discussInactiveAction: const Color(0xFF7D8178),
        GenesisColorToken.discussComposerCursor: const Color(0xFF6C657A),
        GenesisColorToken.discussAttachmentAction: const Color(0xFF00834C),
        GenesisColorToken.discussSendAction: const Color(0xFF4B5F8E),
        GenesisColorToken.discussSendDisabled: const Color(0xFF9BA4B8),
        GenesisColorToken.attachmentIcon: const Color(0xFF8E8E8E),
        GenesisColorToken.roleLaunchDisabled: const Color(0xFFC8D9D1),
        GenesisColorToken.roleSelectionShadow: const Color(0x33000000),
        GenesisColorToken.gemSoldOutForeground: const Color(0xFFD47B89),
        GenesisColorToken.gemTaskAction: const Color(0xFFAD403B),
        GenesisColorToken.privateChatBackground: const Color(0xFFEDEDED),
        GenesisColorToken.privateChatBubbleSelf: const Color(0xFF95EC69),
        GenesisColorToken.privateChatBubbleOther: const Color(0xFFFFFFFF),
        GenesisColorToken.locationChatBackground: const Color(0xFF111111),
        GenesisColorToken.locationChatForeground: const Color(0xFFFFFFFF),
        GenesisColorToken.locationChatChromeStrong: const Color(0xF2111111),
        GenesisColorToken.locationChatChromeSoft: const Color(0x80111111),
        GenesisColorToken.mapControlBackground: const Color(0xE6FFFFFF),
        GenesisColorToken.homeFeedAccent: const Color(0xFFFF2442),
        GenesisColorToken.gemAccent: const Color(0xFFFF2442),
        GenesisColorToken.formField: const Color(0xFFF4F4F6),
        GenesisColorToken.worldAction: const Color(0xFF2F9663),
        GenesisColorToken.originPreviewAccent: const Color(0xFF6554FF),
        GenesisColorToken.gemNewUserTag: const Color(0xFFE85C39),
        GenesisColorToken.gemStandardTag: const Color(0xFFB53B52),
        GenesisColorToken.assetOverlayLight: const Color(0xFFFFFFFF),
        for (final entry in GenesisColorToken.assetSourceByArgb.entries)
          entry.value: Color(entry.key),
      });

  static final GenesisSemanticColorConfig dark =
      GenesisSemanticColorConfig(<GenesisColorToken, Color>{
        GenesisColorToken.surface: const Color(0xFF121212),
        GenesisColorToken.surfaceMuted: const Color(0xFF18191B),
        GenesisColorToken.surfaceInput: const Color(0xFF232529),
        GenesisColorToken.surfacePanel: const Color(0xFF1D1F22),
        GenesisColorToken.surfaceElevated: const Color(0xFF26282D),
        GenesisColorToken.surfaceOverlay: const Color(0xB3000000),
        GenesisColorToken.surfaceOverlaySubtle: const Color(0x8A000000),
        GenesisColorToken.detailSheetBarrier: const Color(0x8A000000),
        GenesisColorToken.bottomNavigationBackground: const Color(0xFF18191B),
        GenesisColorToken.listItemSurface: const Color(0xFF121212),
        GenesisColorToken.neutralControlSurface: const Color(0xFF303238),
        GenesisColorToken.contentPanelSurface: const Color(0xFF232529),
        GenesisColorToken.subtleButtonSurface: const Color(0xFF303238),
        GenesisColorToken.accountCardSurface: const Color(0xFF232529),
        GenesisColorToken.notificationMenuSurface: const Color(0xFF18322F),
        GenesisColorToken.followerMenuSurface: const Color(0xFF382B18),
        GenesisColorToken.commentMenuSurface: const Color(0xFF1A2942),
        GenesisColorToken.detailMutedSurface: const Color(0xFF2A2D32),
        GenesisColorToken.detailPanelSurface: const Color(0xFF232529),
        GenesisColorToken.detailPlaceholderSurface: const Color(0xFF272A2F),
        GenesisColorToken.detailPillSurface: const Color(0xFF34373D),
        GenesisColorToken.detailCloseSurface: const Color(0xFF34373D),
        GenesisColorToken.worldTagSurface: const Color(0xFF2A2D32),
        GenesisColorToken.originCharacterTagSurface: const Color(0xFF303238),
        GenesisColorToken.originListTagSurface: const Color(0xFF252B33),
        GenesisColorToken.roleSelectorSurface: const Color(0xFF232529),
        GenesisColorToken.roleSelectorSelectedSurface: const Color(0xFF34373D),
        GenesisColorToken.worldGlobalEventSurface: const Color(0xFF173A2A),
        GenesisColorToken.actionMenuSurface: const Color(0xFF34373D),
        GenesisColorToken.searchCompactSurface: const Color(0xFF232529),
        GenesisColorToken.searchHistorySurface: const Color(0xFF303238),
        GenesisColorToken.gemProductSurface: const Color(0xFF232529),
        GenesisColorToken.gemLoadingSurface: const Color(0xFF272A2F),
        GenesisColorToken.gemEmptySurface: const Color(0xFF1D1F22),
        GenesisColorToken.discussQuoteSurface: const Color(0xFF232529),
        GenesisColorToken.discussRepliesSurface: const Color(0xFF232529),
        GenesisColorToken.discussComposerSurface: const Color(0xFF232529),
        GenesisColorToken.mediaErrorOverlay: const Color(0x99000000),
        GenesisColorToken.mediaRemoveSurface: const Color(0xFF4F4F4F),
        GenesisColorToken.mediaControlShadow: const Color(0x66000000),
        GenesisColorToken.skeletonBase: const Color(0xFF272A2F),
        GenesisColorToken.skeletonHighlight: const Color(0xFF383B42),
        GenesisColorToken.profileGemSurface: const Color(0xFF29223D),
        GenesisColorToken.mediaControlOverlay: const Color(0x99000000),
        GenesisColorToken.textPrimary: const Color(0xFFF2F2F2),
        GenesisColorToken.textSecondary: const Color(0xFFB8BBC0),
        GenesisColorToken.textTertiary: const Color(0xFF92969D),
        GenesisColorToken.textDisabled: const Color(0xFF6F737B),
        GenesisColorToken.textInverse: const Color(0xFF121212),
        GenesisColorToken.textLink: const Color(0xFF91B3FF),
        GenesisColorToken.textEmailLink: const Color(0xFF91B3FF),
        GenesisColorToken.iconPrimary: const Color(0xFFF2F2F2),
        GenesisColorToken.iconSecondary: const Color(0xFFA3A7AE),
        GenesisColorToken.detailPlaceholderIcon: const Color(0xFF92969D),
        GenesisColorToken.navigationChevron: const Color(0xFF737780),
        GenesisColorToken.textStrong: const Color(0xFFE2E3E5),
        GenesisColorToken.textSecondaryStrong: const Color(0xFFB8BBC0),
        GenesisColorToken.textMetadata: const Color(0xFFA3A7AE),
        GenesisColorToken.textRole: const Color(0xFF92969D),
        GenesisColorToken.textTimestamp: const Color(0xFFA3A7AE),
        GenesisColorToken.textMuted: const Color(0xFF92969D),
        GenesisColorToken.textSectionTitle: const Color(0xFFF2F2F2),
        GenesisColorToken.textOnDark: const Color(0xFFFFFFFF),
        GenesisColorToken.textEmptyState: const Color(0xFFB8BBC0),
        GenesisColorToken.textCounter: const Color(0xFF92969D),
        GenesisColorToken.textFormHint: const Color(0xFFA3A7AE),
        GenesisColorToken.textListMetadata: const Color(0xFFA3A7AE),
        GenesisColorToken.textDeveloperDisabled: const Color(0xFF6F737B),
        GenesisColorToken.textHighEmphasis: const Color(0xFFF2F2F2),
        GenesisColorToken.textDetailBody: const Color(0xFFC8CBD0),
        GenesisColorToken.originCharacterSubtitle: const Color(0xFFB8BBC0),
        GenesisColorToken.roleSelectorInactiveText: const Color(0xFFB8BBC0),
        GenesisColorToken.searchCancelText: const Color(0xFFE2E3E5),
        GenesisColorToken.originListTagText: const Color(0xFF9AA8B8),
        GenesisColorToken.discussReplyText: const Color(0xFFB8BBC0),
        GenesisColorToken.discussComposerHint: const Color(0xFF7D828A),
        GenesisColorToken.messageMutedText: const Color(0xFFA3A7AE),
        GenesisColorToken.messageMetadataText: const Color(0xFFA3A7AE),
        GenesisColorToken.messageOriginLinkText: const Color(0xFFA9C2F5),
        GenesisColorToken.border: const Color(0xFF303238),
        GenesisColorToken.borderStrong: const Color(0xFF42454C),
        GenesisColorToken.divider: const Color(0xFF303238),
        GenesisColorToken.borderFocus: const Color(0xFF00C27A),
        GenesisColorToken.listDivider: const Color(0xFF303238),
        GenesisColorToken.detailDivider: const Color(0xFF303238),
        GenesisColorToken.discussQuoteBorder: const Color(0xFF4B5059),
        GenesisColorToken.discussRepliesBorder: const Color(0xFF4B5059),
        GenesisColorToken.bottomSheetHandle: const Color(0xFF5A5E66),
        GenesisColorToken.attachmentBorder: const Color(0xFF4B5059),
        GenesisColorToken.roleSelectorBorder: const Color(0xFF4B5059),
        GenesisColorToken.roleFormBorder: const Color(0xFF4B5059),
        GenesisColorToken.searchCompactBorder: const Color(0xFF4B5059),
        GenesisColorToken.gemProductBorder: const Color(0xFF4B5059),
        GenesisColorToken.gemSoldOutBorder: const Color(0xFF713642),
        GenesisColorToken.profileGemBorder: const Color(0xFF5B4A82),
        GenesisColorToken.brand: const Color(0xFF00C27A),
        GenesisColorToken.brandBright: const Color(0xFF00C27A),
        GenesisColorToken.brandDisabled: const Color(0xFF274738),
        GenesisColorToken.actionDisabledForeground: const Color(0xFF6F737B),
        GenesisColorToken.create: const Color(0xFFA78BFA),
        GenesisColorToken.bottomNavigationProminent: const Color(0xFFA78BFA),
        GenesisColorToken.danger: const Color(0xFFFF6B80),
        GenesisColorToken.success: const Color(0xFF79D8A4),
        GenesisColorToken.successContainer: const Color(0xFF173A2A),
        GenesisColorToken.warning: const Color(0xFFF5C37B),
        GenesisColorToken.warningContainer: const Color(0xFF3B2A18),
        GenesisColorToken.info: const Color(0xFF9FC1FF),
        GenesisColorToken.infoContainer: const Color(0xFF182A44),
        GenesisColorToken.neutralControlForeground: const Color(0xFFF2F2F2),
        GenesisColorToken.neutralControlDisabledForeground: const Color(
          0xFF6F737B,
        ),
        GenesisColorToken.destructiveControl: const Color(0xFFFF7A7D),
        GenesisColorToken.messagePositiveState: const Color(0xFF65C99A),
        GenesisColorToken.discussInactiveAction: const Color(0xFFA3A79F),
        GenesisColorToken.discussComposerCursor: const Color(0xFFB9B2C6),
        GenesisColorToken.discussAttachmentAction: const Color(0xFF58C995),
        GenesisColorToken.discussSendAction: const Color(0xFFA9BCE9),
        GenesisColorToken.discussSendDisabled: const Color(0xFF687186),
        GenesisColorToken.attachmentIcon: const Color(0xFFA3A7AE),
        GenesisColorToken.roleLaunchDisabled: const Color(0xFF274738),
        GenesisColorToken.roleSelectionShadow: const Color(0x66000000),
        GenesisColorToken.gemSoldOutForeground: const Color(0xFFFF9AAD),
        GenesisColorToken.gemTaskAction: const Color(0xFFB7A3FF),
        GenesisColorToken.privateChatBackground: const Color(0xFF121212),
        GenesisColorToken.privateChatBubbleSelf: const Color(0xFF275E3E),
        GenesisColorToken.privateChatBubbleOther: const Color(0xFF26282D),
        GenesisColorToken.locationChatBackground: const Color(0xFF111111),
        GenesisColorToken.locationChatForeground: const Color(0xFFFFFFFF),
        GenesisColorToken.locationChatChromeStrong: const Color(0xF2111111),
        GenesisColorToken.locationChatChromeSoft: const Color(0x80111111),
        GenesisColorToken.mapControlBackground: const Color(0xE626282D),
        GenesisColorToken.homeFeedAccent: const Color(0xFFA78BFA),
        GenesisColorToken.gemAccent: const Color(0xFFA78BFA),
        GenesisColorToken.formField: const Color(0xFF232529),
        GenesisColorToken.worldAction: const Color(0xFF49B67D),
        GenesisColorToken.originPreviewAccent: const Color(0xFF9A8FFF),
        GenesisColorToken.gemNewUserTag: const Color(0xFFFF7A59),
        GenesisColorToken.gemStandardTag: const Color(0xFF7658D6),
        GenesisColorToken.assetOverlayLight: const Color(0xFFFFFFFF),
        for (final entry in GenesisColorToken.assetSourceByArgb.entries)
          entry.value: Color(_darkAssetArgb[entry.key]!),
      });
}

@immutable
class GenesisSemanticColors extends ThemeExtension<GenesisSemanticColors> {
  const GenesisSemanticColors({required this.config, required this.revision});

  final GenesisSemanticColorConfig config;
  final int revision;

  Color color(GenesisColorToken token) => config.color(token);

  static GenesisSemanticColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GenesisSemanticColors>() ??
        GenesisSemanticColors(
          config: theme.brightness == Brightness.dark
              ? GenesisColorDefaults.dark
              : GenesisColorDefaults.light,
          revision: 0,
        );
  }

  @override
  GenesisSemanticColors copyWith({
    GenesisSemanticColorConfig? config,
    int? revision,
  }) {
    return GenesisSemanticColors(
      config: config ?? this.config,
      revision: revision ?? this.revision,
    );
  }

  @override
  GenesisSemanticColors lerp(
    covariant ThemeExtension<GenesisSemanticColors>? other,
    double t,
  ) {
    if (other is! GenesisSemanticColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Transitional runtime access for shared style factories that cannot receive
/// a BuildContext. New widgets should prefer [GenesisSemanticColors.of].
abstract final class GenesisColorRuntime {
  static GenesisSemanticColorConfig _active = GenesisColorDefaults.light;
  static int _revision = 0;

  static GenesisSemanticColorConfig get active => _active;
  static int get revision => _revision;

  static Color color(GenesisColorToken token) => _active.color(token);

  static void activate(GenesisSemanticColorConfig config, int revision) {
    _active = config;
    _revision = revision;
  }
}
