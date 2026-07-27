import 'package:flutter/foundation.dart';

enum GenesisColorGroup {
  surface('Surface'),
  textIcon('Text / Icon'),
  border('Border'),
  actionState('Action / State'),
  scene('Scene'),
  asset('Asset');

  const GenesisColorGroup(this.label);

  final String label;
}

@immutable
class GenesisColorToken {
  const GenesisColorToken({
    required this.id,
    required this.label,
    required this.group,
    required this.description,
  });

  final String id;
  final String label;
  final GenesisColorGroup group;
  final String description;

  static const surface = GenesisColorToken(
    id: 'surface.page',
    label: 'Page surface',
    group: GenesisColorGroup.surface,
    description: 'Default Scaffold and full-page background.',
  );
  static const surfaceMuted = GenesisColorToken(
    id: 'surface.muted',
    label: 'Muted surface',
    group: GenesisColorGroup.surface,
    description: 'Navigation bars and low-emphasis sections.',
  );
  static const surfaceInput = GenesisColorToken(
    id: 'surface.input',
    label: 'Input surface',
    group: GenesisColorGroup.surface,
    description: 'Search fields and editable controls.',
  );
  static const surfacePanel = GenesisColorToken(
    id: 'surface.panel',
    label: 'Panel surface',
    group: GenesisColorGroup.surface,
    description: 'Cards, grouped panels and secondary sheets.',
  );
  static const surfaceElevated = GenesisColorToken(
    id: 'surface.elevated',
    label: 'Elevated surface',
    group: GenesisColorGroup.surface,
    description: 'Dialogs, bottom sheets and elevated cards.',
  );
  static const surfaceOverlay = GenesisColorToken(
    id: 'surface.overlay',
    label: 'Overlay scrim',
    group: GenesisColorGroup.surface,
    description: 'Modal barrier and image overlay scrim.',
  );
  static const surfaceOverlaySubtle = GenesisColorToken(
    id: 'surface.overlay_subtle',
    label: 'Subtle overlay scrim',
    group: GenesisColorGroup.surface,
    description: 'Lower-emphasis modal barrier and translucent scrim.',
  );
  static const detailSheetBarrier = GenesisColorToken(
    id: 'surface.detail_sheet_barrier',
    label: 'Detail sheet barrier',
    group: GenesisColorGroup.surface,
    description: 'Barrier behind World and Origin detail bottom sheets.',
  );
  static const bottomNavigationBackground = GenesisColorToken(
    id: 'surface.bottom_navigation',
    label: 'Bottom navigation surface',
    group: GenesisColorGroup.surface,
    description: 'Main bottom navigation background.',
  );
  static const listItemSurface = GenesisColorToken(
    id: 'surface.list_item',
    label: 'List item surface',
    group: GenesisColorGroup.surface,
    description: 'Rows and cards used by profile and feed collections.',
  );
  static const neutralControlSurface = GenesisColorToken(
    id: 'surface.neutral_control',
    label: 'Neutral control surface',
    group: GenesisColorGroup.surface,
    description: 'Secondary buttons and inactive controls.',
  );
  static const contentPanelSurface = GenesisColorToken(
    id: 'surface.content_panel',
    label: 'Content panel surface',
    group: GenesisColorGroup.surface,
    description: 'Inline status and metadata panels inside feed cards.',
  );
  static const subtleButtonSurface = GenesisColorToken(
    id: 'surface.subtle_button',
    label: 'Subtle button surface',
    group: GenesisColorGroup.surface,
    description: 'Secondary account actions using the legacy #E1E1E3 fill.',
  );
  static const accountCardSurface = GenesisColorToken(
    id: 'surface.account_card',
    label: 'Account card surface',
    group: GenesisColorGroup.surface,
    description: 'Current login account summary card.',
  );
  static const notificationMenuSurface = GenesisColorToken(
    id: 'surface.message_notifications',
    label: 'Notification menu surface',
    group: GenesisColorGroup.surface,
    description: 'Messages notification shortcut tile.',
  );
  static const followerMenuSurface = GenesisColorToken(
    id: 'surface.message_followers',
    label: 'Follower menu surface',
    group: GenesisColorGroup.surface,
    description: 'Messages new-followers shortcut tile.',
  );
  static const commentMenuSurface = GenesisColorToken(
    id: 'surface.message_comments',
    label: 'Comment menu surface',
    group: GenesisColorGroup.surface,
    description: 'Messages comments shortcut tile.',
  );
  static const detailMutedSurface = GenesisColorToken(
    id: 'surface.detail_muted',
    label: 'Detail muted surface',
    group: GenesisColorGroup.surface,
    description: 'Muted image and section surface in World and Origin detail.',
  );
  static const detailPanelSurface = GenesisColorToken(
    id: 'surface.detail_panel',
    label: 'Detail panel surface',
    group: GenesisColorGroup.surface,
    description: 'Nested World and Origin detail content panel.',
  );
  static const detailPlaceholderSurface = GenesisColorToken(
    id: 'surface.detail_placeholder',
    label: 'Detail placeholder surface',
    group: GenesisColorGroup.surface,
    description: 'Missing media placeholder in detail pages.',
  );
  static const detailPillSurface = GenesisColorToken(
    id: 'surface.detail_pill',
    label: 'Detail pill surface',
    group: GenesisColorGroup.surface,
    description: 'Compact status and tag pills in detail pages.',
  );
  static const detailCloseSurface = GenesisColorToken(
    id: 'surface.detail_close',
    label: 'Detail close surface',
    group: GenesisColorGroup.surface,
    description: 'Circular close control in detail bottom sheets.',
  );
  static const worldTagSurface = GenesisColorToken(
    id: 'surface.world_tag',
    label: 'World tag surface',
    group: GenesisColorGroup.surface,
    description: 'World detail bottom navigation tag surface.',
  );
  static const originCharacterTagSurface = GenesisColorToken(
    id: 'surface.origin_character_tag',
    label: 'Origin character tag surface',
    group: GenesisColorGroup.surface,
    description: 'Character tag chip in Origin detail.',
  );
  static const originListTagSurface = GenesisColorToken(
    id: 'surface.origin_list_tag',
    label: 'Origin list tag surface',
    group: GenesisColorGroup.surface,
    description: 'Tag chip background on Origin list cards.',
  );
  static const roleSelectorSurface = GenesisColorToken(
    id: 'surface.role_selector',
    label: 'Role selector surface',
    group: GenesisColorGroup.surface,
    description: 'Role-launch segmented control track.',
  );
  static const roleSelectorSelectedSurface = GenesisColorToken(
    id: 'surface.role_selector_selected',
    label: 'Selected role surface',
    group: GenesisColorGroup.surface,
    description: 'Selected segment in the role-launch selector.',
  );
  static const worldGlobalEventSurface = GenesisColorToken(
    id: 'surface.world_global_event',
    label: 'World global event surface',
    group: GenesisColorGroup.surface,
    description: 'Global event card in World and Origin tick content.',
  );
  static const actionMenuSurface = GenesisColorToken(
    id: 'surface.action_menu',
    label: 'Action menu surface',
    group: GenesisColorGroup.surface,
    description: 'Report, delete and contextual action popup surface.',
  );
  static const searchCompactSurface = GenesisColorToken(
    id: 'surface.search_compact',
    label: 'Compact search surface',
    group: GenesisColorGroup.surface,
    description: 'Compact page-header and SearchPage input surface.',
  );
  static const searchHistorySurface = GenesisColorToken(
    id: 'surface.search_history',
    label: 'Search history surface',
    group: GenesisColorGroup.surface,
    description: 'Search history query chip surface.',
  );
  static const gemProductSurface = GenesisColorToken(
    id: 'surface.gem_product',
    label: 'Gem product surface',
    group: GenesisColorGroup.surface,
    description: 'Buy Gems product and task card surface.',
  );
  static const gemLoadingSurface = GenesisColorToken(
    id: 'surface.gem_loading',
    label: 'Gem loading surface',
    group: GenesisColorGroup.surface,
    description: 'Buy Gems catalog loading skeleton surface.',
  );
  static const gemEmptySurface = GenesisColorToken(
    id: 'surface.gem_empty',
    label: 'Gem empty surface',
    group: GenesisColorGroup.surface,
    description: 'Buy Gems empty and unavailable panel surface.',
  );
  static const discussQuoteSurface = GenesisColorToken(
    id: 'surface.discuss_quote',
    label: 'Discuss quote surface',
    group: GenesisColorGroup.surface,
    description: 'Nested reply preview surface in Discuss comments.',
  );
  static const discussRepliesSurface = GenesisColorToken(
    id: 'surface.discuss_replies',
    label: 'Discuss replies surface',
    group: GenesisColorGroup.surface,
    description: 'Expanded reply-list surface.',
  );
  static const discussComposerSurface = GenesisColorToken(
    id: 'surface.discuss_composer',
    label: 'Discuss composer surface',
    group: GenesisColorGroup.surface,
    description: 'Discuss entry and expanded composer input surface.',
  );
  static const mediaErrorOverlay = GenesisColorToken(
    id: 'surface.media_error_overlay',
    label: 'Media error overlay',
    group: GenesisColorGroup.surface,
    description: 'Failed attachment overlay.',
  );
  static const mediaRemoveSurface = GenesisColorToken(
    id: 'surface.media_remove',
    label: 'Media remove surface',
    group: GenesisColorGroup.surface,
    description: 'Attachment remove-button surface.',
  );
  static const mediaControlShadow = GenesisColorToken(
    id: 'surface.media_control_shadow',
    label: 'Media control shadow',
    group: GenesisColorGroup.surface,
    description: 'Drop shadow behind attachment media controls.',
  );
  static const skeletonBase = GenesisColorToken(
    id: 'surface.skeleton_base',
    label: 'Skeleton base',
    group: GenesisColorGroup.surface,
    description: 'Base stop of list loading shimmer.',
  );
  static const skeletonHighlight = GenesisColorToken(
    id: 'surface.skeleton_highlight',
    label: 'Skeleton highlight',
    group: GenesisColorGroup.surface,
    description: 'Highlight stop of list loading shimmer.',
  );
  static const profileGemSurface = GenesisColorToken(
    id: 'surface.profile_gem',
    label: 'Profile Gem surface',
    group: GenesisColorGroup.surface,
    description: 'Gem balance entry on profile pages.',
  );
  static const mediaControlOverlay = GenesisColorToken(
    id: 'surface.media_control_overlay',
    label: 'Media control overlay',
    group: GenesisColorGroup.surface,
    description: 'Circular edit and close controls displayed over images.',
  );

  static const textPrimary = GenesisColorToken(
    id: 'text.primary',
    label: 'Primary text',
    group: GenesisColorGroup.textIcon,
    description: 'Titles and normal high-emphasis body text.',
  );
  static const textSecondary = GenesisColorToken(
    id: 'text.secondary',
    label: 'Secondary text',
    group: GenesisColorGroup.textIcon,
    description: 'Supporting copy and secondary metadata.',
  );
  static const textTertiary = GenesisColorToken(
    id: 'text.tertiary',
    label: 'Tertiary text',
    group: GenesisColorGroup.textIcon,
    description: 'Timestamps and low-emphasis metadata.',
  );
  static const textDisabled = GenesisColorToken(
    id: 'text.disabled',
    label: 'Disabled text',
    group: GenesisColorGroup.textIcon,
    description: 'Disabled controls and placeholders.',
  );
  static const textInverse = GenesisColorToken(
    id: 'text.inverse',
    label: 'Inverse text',
    group: GenesisColorGroup.textIcon,
    description: 'Text displayed over strong or dark fills.',
  );
  static const textLink = GenesisColorToken(
    id: 'text.link',
    label: 'Link / name text',
    group: GenesisColorGroup.textIcon,
    description: 'Interactive links, names and edit actions.',
  );
  static const textEmailLink = GenesisColorToken(
    id: 'text.email_link',
    label: 'Email link text',
    group: GenesisColorGroup.textIcon,
    description: 'Contact email link in About.',
  );
  static const iconPrimary = GenesisColorToken(
    id: 'icon.primary',
    label: 'Primary icon',
    group: GenesisColorGroup.textIcon,
    description: 'Default high-emphasis icon foreground.',
  );
  static const iconSecondary = GenesisColorToken(
    id: 'icon.secondary',
    label: 'Secondary icon',
    group: GenesisColorGroup.textIcon,
    description: 'Muted icon foreground.',
  );
  static const detailPlaceholderIcon = GenesisColorToken(
    id: 'icon.detail_placeholder',
    label: 'Detail placeholder icon',
    group: GenesisColorGroup.textIcon,
    description: 'Missing media icon in World and Origin detail pages.',
  );
  static const navigationChevron = GenesisColorToken(
    id: 'icon.navigation_chevron',
    label: 'Navigation chevron',
    group: GenesisColorGroup.textIcon,
    description: 'Trailing chevrons in settings and navigation lists.',
  );
  static const textStrong = GenesisColorToken(
    id: 'text.strong',
    label: 'Strong text',
    group: GenesisColorGroup.textIcon,
    description: 'Strong neutral labels that are softer than primary text.',
  );
  static const textSecondaryStrong = GenesisColorToken(
    id: 'text.secondary_strong',
    label: 'Strong secondary text',
    group: GenesisColorGroup.textIcon,
    description:
        'Secondary labels and list metadata using the legacy #666 tone.',
  );
  static const textMetadata = GenesisColorToken(
    id: 'text.metadata',
    label: 'Metadata text',
    group: GenesisColorGroup.textIcon,
    description: 'Timestamps, suffixes and compact supporting metadata.',
  );
  static const textRole = GenesisColorToken(
    id: 'text.role',
    label: 'Role text',
    group: GenesisColorGroup.textIcon,
    description: 'Character and player role labels in world cards.',
  );
  static const textTimestamp = GenesisColorToken(
    id: 'text.timestamp',
    label: 'Timestamp text',
    group: GenesisColorGroup.textIcon,
    description: 'Compact activity timestamps using the legacy #8B8B8B tone.',
  );
  static const textMuted = GenesisColorToken(
    id: 'text.muted',
    label: 'Muted text',
    group: GenesisColorGroup.textIcon,
    description: 'Empty states and very low-emphasis labels.',
  );
  static const textSectionTitle = GenesisColorToken(
    id: 'text.section_title',
    label: 'Section title',
    group: GenesisColorGroup.textIcon,
    description: 'Compact feed section headings.',
  );
  static const textOnDark = GenesisColorToken(
    id: 'text.on_dark',
    label: 'Text on dark media',
    group: GenesisColorGroup.textIcon,
    description: 'Foreground that remains light over dark media in both modes.',
  );
  static const textEmptyState = GenesisColorToken(
    id: 'text.empty_state',
    label: 'Empty-state text',
    group: GenesisColorGroup.textIcon,
    description: 'Prominent supporting text in signed-out and empty states.',
  );
  static const textCounter = GenesisColorToken(
    id: 'text.counter',
    label: 'Input counter text',
    group: GenesisColorGroup.textIcon,
    description: 'Character counters and compact form metadata.',
  );
  static const textFormHint = GenesisColorToken(
    id: 'text.form_hint',
    label: 'Form hint text',
    group: GenesisColorGroup.textIcon,
    description:
        'Agreement, UID and load-state copy using the legacy #777 tone.',
  );
  static const textListMetadata = GenesisColorToken(
    id: 'text.list_metadata',
    label: 'List metadata text',
    group: GenesisColorGroup.textIcon,
    description: 'Compact list metadata using the legacy #8A8A8A tone.',
  );
  static const textDeveloperDisabled = GenesisColorToken(
    id: 'text.developer_disabled',
    label: 'Developer disabled text',
    group: GenesisColorGroup.textIcon,
    description: 'Disabled action label in Developer tools.',
  );
  static const textHighEmphasis = GenesisColorToken(
    id: 'text.high_emphasis',
    label: 'High-emphasis text',
    group: GenesisColorGroup.textIcon,
    description: 'Legacy black87 titles and labels.',
  );
  static const textDetailBody = GenesisColorToken(
    id: 'text.detail_body',
    label: 'Detail body text',
    group: GenesisColorGroup.textIcon,
    description:
        'World and Origin detail body copy using the legacy #444 tone.',
  );
  static const originCharacterSubtitle = GenesisColorToken(
    id: 'text.origin_character_subtitle',
    label: 'Origin character subtitle',
    group: GenesisColorGroup.textIcon,
    description: 'Supporting character copy in Origin detail.',
  );
  static const roleSelectorInactiveText = GenesisColorToken(
    id: 'text.role_selector_inactive',
    label: 'Inactive role selector text',
    group: GenesisColorGroup.textIcon,
    description: 'Unselected role-launch segment label.',
  );
  static const searchCancelText = GenesisColorToken(
    id: 'text.search_cancel',
    label: 'Search cancel text',
    group: GenesisColorGroup.textIcon,
    description: 'Cancel action beside the SearchPage input.',
  );
  static const originListTagText = GenesisColorToken(
    id: 'text.origin_list_tag',
    label: 'Origin list tag text',
    group: GenesisColorGroup.textIcon,
    description: 'Muted tag label on Origin list cards.',
  );
  static const discussReplyText = GenesisColorToken(
    id: 'text.discuss_reply',
    label: 'Discuss reply text',
    group: GenesisColorGroup.textIcon,
    description: 'Reply author and reply-target text.',
  );
  static const discussComposerHint = GenesisColorToken(
    id: 'text.discuss_composer_hint',
    label: 'Discuss composer hint',
    group: GenesisColorGroup.textIcon,
    description: 'Placeholder text in the expanded Discuss composer.',
  );
  static const messageMutedText = GenesisColorToken(
    id: 'text.message_muted',
    label: 'Message muted text',
    group: GenesisColorGroup.textIcon,
    description: 'Messages empty and error states.',
  );
  static const messageMetadataText = GenesisColorToken(
    id: 'text.message_metadata',
    label: 'Message metadata text',
    group: GenesisColorGroup.textIcon,
    description: 'Notification status metadata and trailing chevrons.',
  );
  static const messageOriginLinkText = GenesisColorToken(
    id: 'text.message_origin_link',
    label: 'Message origin link',
    group: GenesisColorGroup.textIcon,
    description: 'Origin and World names in notification copy.',
  );

  static const border = GenesisColorToken(
    id: 'border.default',
    label: 'Default border',
    group: GenesisColorGroup.border,
    description: 'Dividers and subtle outlines.',
  );
  static const borderStrong = GenesisColorToken(
    id: 'border.strong',
    label: 'Strong border',
    group: GenesisColorGroup.border,
    description: 'Controls that need a visible outline.',
  );
  static const divider = GenesisColorToken(
    id: 'border.divider',
    label: 'List divider',
    group: GenesisColorGroup.border,
    description: 'One-pixel separators in settings and list pages.',
  );
  static const borderFocus = GenesisColorToken(
    id: 'border.focus',
    label: 'Focus border',
    group: GenesisColorGroup.border,
    description: 'Focused input and selected outline.',
  );
  static const listDivider = GenesisColorToken(
    id: 'border.list_divider',
    label: 'Feed list divider',
    group: GenesisColorGroup.border,
    description: 'Separators between feed and collection entries.',
  );
  static const detailDivider = GenesisColorToken(
    id: 'border.detail_divider',
    label: 'Detail divider',
    group: GenesisColorGroup.border,
    description: 'World, Origin and Discuss list separator.',
  );
  static const discussQuoteBorder = GenesisColorToken(
    id: 'border.discuss_quote',
    label: 'Discuss quote border',
    group: GenesisColorGroup.border,
    description: 'Leading rule for nested reply previews.',
  );
  static const discussRepliesBorder = GenesisColorToken(
    id: 'border.discuss_replies',
    label: 'Discuss replies border',
    group: GenesisColorGroup.border,
    description: 'Leading rule for expanded reply lists.',
  );
  static const bottomSheetHandle = GenesisColorToken(
    id: 'border.bottom_sheet_handle',
    label: 'Bottom sheet handle',
    group: GenesisColorGroup.border,
    description: 'Drag handle shown on detail bottom sheets.',
  );
  static const attachmentBorder = GenesisColorToken(
    id: 'border.attachment',
    label: 'Attachment border',
    group: GenesisColorGroup.border,
    description: 'Add-attachment tile border.',
  );
  static const roleSelectorBorder = GenesisColorToken(
    id: 'border.role_selector',
    label: 'Role selector border',
    group: GenesisColorGroup.border,
    description: 'Selected role segment outline.',
  );
  static const roleFormBorder = GenesisColorToken(
    id: 'border.role_form',
    label: 'Role form border',
    group: GenesisColorGroup.border,
    description: 'Custom role form outline.',
  );
  static const searchCompactBorder = GenesisColorToken(
    id: 'border.search_compact',
    label: 'Compact search border',
    group: GenesisColorGroup.border,
    description: 'Outline around compact search fields.',
  );
  static const gemProductBorder = GenesisColorToken(
    id: 'border.gem_product',
    label: 'Gem product border',
    group: GenesisColorGroup.border,
    description: 'Buy Gems product and task card outline.',
  );
  static const gemSoldOutBorder = GenesisColorToken(
    id: 'border.gem_sold_out',
    label: 'Gem sold-out border',
    group: GenesisColorGroup.border,
    description: 'Sold-out gem price control outline.',
  );
  static const profileGemBorder = GenesisColorToken(
    id: 'border.profile_gem',
    label: 'Profile Gem border',
    group: GenesisColorGroup.border,
    description: 'Outline around the profile Gem balance entry.',
  );

  static const brand = GenesisColorToken(
    id: 'action.brand',
    label: 'Brand action',
    group: GenesisColorGroup.actionState,
    description: 'Primary green action and progress color.',
  );
  static const brandBright = GenesisColorToken(
    id: 'action.brand_bright',
    label: 'Bright brand',
    group: GenesisColorGroup.actionState,
    description: 'Bright green Material seed and dark-mode action.',
  );
  static const brandDisabled = GenesisColorToken(
    id: 'action.brand_disabled',
    label: 'Disabled brand',
    group: GenesisColorGroup.actionState,
    description: 'Disabled primary action fill.',
  );
  static const actionDisabledForeground = GenesisColorToken(
    id: 'action.disabled_foreground',
    label: 'Disabled action foreground',
    group: GenesisColorGroup.actionState,
    description: 'Text and icons on disabled primary actions.',
  );
  static const create = GenesisColorToken(
    id: 'action.create',
    label: 'Prominent action accent',
    group: GenesisColorGroup.actionState,
    description: 'Create and other prominent product actions.',
  );
  static const bottomNavigationProminent = GenesisColorToken(
    id: 'action.bottom_navigation_prominent',
    label: 'Bottom navigation Create',
    group: GenesisColorGroup.actionState,
    description: 'Prominent Create icon and label in bottom navigation.',
  );
  static const danger = GenesisColorToken(
    id: 'state.danger',
    label: 'Danger',
    group: GenesisColorGroup.actionState,
    description: 'Errors and destructive actions.',
  );
  static const success = GenesisColorToken(
    id: 'state.success',
    label: 'Success',
    group: GenesisColorGroup.actionState,
    description: 'Successful and completed state foreground.',
  );
  static const successContainer = GenesisColorToken(
    id: 'state.success_container',
    label: 'Success container',
    group: GenesisColorGroup.actionState,
    description: 'Background for successful state chips.',
  );
  static const warning = GenesisColorToken(
    id: 'state.warning',
    label: 'Warning',
    group: GenesisColorGroup.actionState,
    description: 'Warning foreground.',
  );
  static const warningContainer = GenesisColorToken(
    id: 'state.warning_container',
    label: 'Warning container',
    group: GenesisColorGroup.actionState,
    description: 'Background for warning chips.',
  );
  static const info = GenesisColorToken(
    id: 'state.info',
    label: 'Info',
    group: GenesisColorGroup.actionState,
    description: 'Informational foreground.',
  );
  static const infoContainer = GenesisColorToken(
    id: 'state.info_container',
    label: 'Info container',
    group: GenesisColorGroup.actionState,
    description: 'Background for informational chips.',
  );
  static const neutralControlForeground = GenesisColorToken(
    id: 'action.neutral_foreground',
    label: 'Neutral control foreground',
    group: GenesisColorGroup.actionState,
    description: 'Text and icons on neutral secondary controls.',
  );
  static const neutralControlDisabledForeground = GenesisColorToken(
    id: 'action.neutral_disabled_foreground',
    label: 'Disabled neutral foreground',
    group: GenesisColorGroup.actionState,
    description: 'Disabled text and icons on neutral secondary controls.',
  );
  static const destructiveControl = GenesisColorToken(
    id: 'action.destructive_control',
    label: 'Destructive control',
    group: GenesisColorGroup.actionState,
    description: 'Checkbox and destructive control accent.',
  );
  static const messagePositiveState = GenesisColorToken(
    id: 'state.message_positive',
    label: 'Message positive state',
    group: GenesisColorGroup.actionState,
    description: 'Approved and pending join-request state.',
  );
  static const discussInactiveAction = GenesisColorToken(
    id: 'action.discuss_inactive',
    label: 'Discuss inactive action',
    group: GenesisColorGroup.actionState,
    description: 'Unselected like and reply controls.',
  );
  static const discussComposerCursor = GenesisColorToken(
    id: 'action.discuss_cursor',
    label: 'Discuss composer cursor',
    group: GenesisColorGroup.actionState,
    description: 'Text cursor in the Discuss composer.',
  );
  static const discussAttachmentAction = GenesisColorToken(
    id: 'action.discuss_attachment',
    label: 'Discuss attachment action',
    group: GenesisColorGroup.actionState,
    description: 'Add-photo action in the Discuss composer.',
  );
  static const discussSendAction = GenesisColorToken(
    id: 'action.discuss_send',
    label: 'Discuss send action',
    group: GenesisColorGroup.actionState,
    description: 'Enabled Discuss composer send action.',
  );
  static const discussSendDisabled = GenesisColorToken(
    id: 'action.discuss_send_disabled',
    label: 'Discuss send disabled',
    group: GenesisColorGroup.actionState,
    description: 'Disabled Discuss composer send action.',
  );
  static const attachmentIcon = GenesisColorToken(
    id: 'action.attachment_icon',
    label: 'Attachment icon',
    group: GenesisColorGroup.actionState,
    description: 'Add-attachment tile foreground.',
  );
  static const roleLaunchDisabled = GenesisColorToken(
    id: 'action.role_launch_disabled',
    label: 'Role launch disabled',
    group: GenesisColorGroup.actionState,
    description: 'Disabled Launch action fill.',
  );
  static const roleSelectionShadow = GenesisColorToken(
    id: 'action.role_selection_shadow',
    label: 'Role selection shadow',
    group: GenesisColorGroup.actionState,
    description: 'Selection badge shadow in role launch.',
  );
  static const gemSoldOutForeground = GenesisColorToken(
    id: 'action.gem_sold_out',
    label: 'Gem sold-out foreground',
    group: GenesisColorGroup.actionState,
    description: 'Sold-out gem price and claimed task foreground.',
  );
  static const gemTaskAction = GenesisColorToken(
    id: 'action.gem_task',
    label: 'Gem task action',
    group: GenesisColorGroup.actionState,
    description: 'Default action foreground for gem tasks.',
  );

  static const privateChatBackground = GenesisColorToken(
    id: 'scene.private_chat.background',
    label: 'Private chat background',
    group: GenesisColorGroup.scene,
    description: 'Direct-message conversation canvas.',
  );
  static const privateChatBubbleSelf = GenesisColorToken(
    id: 'scene.private_chat.bubble_self',
    label: 'Private chat self bubble',
    group: GenesisColorGroup.scene,
    description: 'Current-user private-message bubble.',
  );
  static const privateChatBubbleOther = GenesisColorToken(
    id: 'scene.private_chat.bubble_other',
    label: 'Private chat other bubble',
    group: GenesisColorGroup.scene,
    description: 'Other-user private-message bubble.',
  );
  static const locationChatBackground = GenesisColorToken(
    id: 'scene.location_chat.background',
    label: 'Location chat background',
    group: GenesisColorGroup.scene,
    description: 'Immersive location-chat canvas.',
  );
  static const locationChatForeground = GenesisColorToken(
    id: 'scene.location_chat.foreground',
    label: 'Location chat foreground',
    group: GenesisColorGroup.scene,
    description: 'Text and icons over the immersive location-chat canvas.',
  );
  static const locationChatChromeStrong = GenesisColorToken(
    id: 'scene.location_chat.chrome_strong',
    label: 'Location chat strong chrome',
    group: GenesisColorGroup.scene,
    description: 'Strong location-chat glass gradient stop.',
  );
  static const locationChatChromeSoft = GenesisColorToken(
    id: 'scene.location_chat.chrome_soft',
    label: 'Location chat soft chrome',
    group: GenesisColorGroup.scene,
    description: 'Soft location-chat glass gradient stop.',
  );
  static const mapControlBackground = GenesisColorToken(
    id: 'scene.map.control_background',
    label: 'Map control background',
    group: GenesisColorGroup.scene,
    description: 'Floating controls displayed over the world map.',
  );
  static const homeFeedAccent = GenesisColorToken(
    id: 'scene.home.feed_accent',
    label: 'Home feed accent',
    group: GenesisColorGroup.scene,
    description: 'Section icons in My Worlds and Popular feeds.',
  );
  static const gemAccent = GenesisColorToken(
    id: 'scene.gem.accent',
    label: 'Gem accent',
    group: GenesisColorGroup.scene,
    description: 'Gem wallet and purchase accent.',
  );
  static const formField = GenesisColorToken(
    id: 'scene.create.form_field',
    label: 'Create form field',
    group: GenesisColorGroup.scene,
    description: 'Origin create/edit field fill.',
  );
  static const worldAction = GenesisColorToken(
    id: 'scene.world.action',
    label: 'World action',
    group: GenesisColorGroup.scene,
    description: 'Primary join and progress action in World detail.',
  );
  static const originPreviewAccent = GenesisColorToken(
    id: 'scene.origin_preview_accent',
    label: 'Origin preview accent',
    group: GenesisColorGroup.scene,
    description: 'Launch Preview section accent in Origin detail.',
  );
  static const gemNewUserTag = GenesisColorToken(
    id: 'scene.gem.new_user_tag',
    label: 'Gem new-user tag',
    group: GenesisColorGroup.scene,
    description: 'New-user gem pack tag background.',
  );
  static const gemStandardTag = GenesisColorToken(
    id: 'scene.gem.standard_tag',
    label: 'Gem standard tag',
    group: GenesisColorGroup.scene,
    description: 'Standard promotional gem pack tag background.',
  );

  static const assetDark = GenesisColorToken(
    id: 'asset.dark_foreground',
    label: 'Asset dark foreground',
    group: GenesisColorGroup.asset,
    description: 'Black and near-black monochrome SVG paths.',
  );
  static const assetMuted = GenesisColorToken(
    id: 'asset.muted_foreground',
    label: 'Asset muted foreground',
    group: GenesisColorGroup.asset,
    description: 'Gray monochrome SVG paths.',
  );
  static const assetLight = GenesisColorToken(
    id: 'asset.light_foreground',
    label: 'Asset light foreground',
    group: GenesisColorGroup.asset,
    description: 'White SVG paths and cut-outs.',
  );
  static const assetOverlayLight = GenesisColorToken(
    id: 'asset.overlay_light',
    label: 'Asset overlay light',
    group: GenesisColorGroup.asset,
    description:
        'White SVG foreground drawn over media or location-chat chrome.',
  );
  static const assetRed = GenesisColorToken(
    id: 'asset.red',
    label: 'Asset red',
    group: GenesisColorGroup.asset,
    description: 'Red brand paths in SVG assets.',
  );
  static const assetGreen = GenesisColorToken(
    id: 'asset.green',
    label: 'Asset green',
    group: GenesisColorGroup.asset,
    description: 'Green brand paths in SVG assets.',
  );
  static const assetBlue = GenesisColorToken(
    id: 'asset.blue',
    label: 'Asset blue',
    group: GenesisColorGroup.asset,
    description: 'Blue brand paths in SVG assets.',
  );
  static const assetYellow = GenesisColorToken(
    id: 'asset.yellow',
    label: 'Asset yellow',
    group: GenesisColorGroup.asset,
    description: 'Yellow brand paths in SVG assets.',
  );

  static GenesisColorToken _assetSource(int argb) {
    final hex = argb.toRadixString(16).substring(2).toUpperCase();
    return GenesisColorToken(
      id: 'asset.source_$hex',
      label: 'Asset #$hex',
      group: GenesisColorGroup.asset,
      description:
          'SVG source color #$hex with an independently editable value.',
    );
  }

  /// Every fixed source color currently present in the 72 bundled SVGs.
  /// Shared brand colors intentionally share a token across asset paths.
  static final Map<int, GenesisColorToken> assetSourceByArgb =
      <int, GenesisColorToken>{
        0xFF000000: _assetSource(0xFF000000),
        0xFF0F0F0F: _assetSource(0xFF0F0F0F),
        0xFF111111: assetDark,
        0xFF171717: _assetSource(0xFF171717),
        0xFF176F6A: _assetSource(0xFF176F6A),
        0xFF292929: _assetSource(0xFF292929),
        0xFF2D5F9A: _assetSource(0xFF2D5F9A),
        0xFF333333: _assetSource(0xFF333333),
        0xFF338960: assetGreen,
        0xFF34A853: _assetSource(0xFF34A853),
        0xFF4285F4: assetBlue,
        0xFF444444: _assetSource(0xFF444444),
        0xFF4D4D4D: _assetSource(0xFF4D4D4D),
        0xFF5865F2: _assetSource(0xFF5865F2),
        0xFF666666: assetMuted,
        0xFF6E6E72: _assetSource(0xFF6E6E72),
        0xFF888888: _assetSource(0xFF888888),
        0xFF8A8478: _assetSource(0xFF8A8478),
        0xFF9B6B18: _assetSource(0xFF9B6B18),
        0xFFA90035: _assetSource(0xFFA90035),
        0xFFB90034: _assetSource(0xFFB90034),
        0xFFBD0035: _assetSource(0xFFBD0035),
        0xFFC40038: _assetSource(0xFFC40038),
        0xFFC51F3A: _assetSource(0xFFC51F3A),
        0xFFC7003C: _assetSource(0xFFC7003C),
        0xFFD40037: _assetSource(0xFFD40037),
        0xFFD8003B: _assetSource(0xFFD8003B),
        0xFFD82B49: _assetSource(0xFFD82B49),
        0xFFD90037: _assetSource(0xFFD90037),
        0xFFE93650: _assetSource(0xFFE93650),
        0xFFEA4335: _assetSource(0xFFEA4335),
        0xFFEB3D56: _assetSource(0xFFEB3D56),
        0xFFF14B62: _assetSource(0xFFF14B62),
        0xFFF42C47: _assetSource(0xFFF42C47),
        0xFFFBBC05: assetYellow,
        0xFFFF2442: assetRed,
        0xFFFF7F92: _assetSource(0xFFFF7F92),
        0xFFFF8CA0: _assetSource(0xFFFF8CA0),
        0xFFFFD4DC: _assetSource(0xFFFFD4DC),
        0xFFFFFFFF: assetLight,
      };

  static final List<GenesisColorToken> values = <GenesisColorToken>[
    surface,
    surfaceMuted,
    surfaceInput,
    surfacePanel,
    surfaceElevated,
    surfaceOverlay,
    surfaceOverlaySubtle,
    detailSheetBarrier,
    bottomNavigationBackground,
    listItemSurface,
    neutralControlSurface,
    contentPanelSurface,
    subtleButtonSurface,
    accountCardSurface,
    notificationMenuSurface,
    followerMenuSurface,
    commentMenuSurface,
    detailMutedSurface,
    detailPanelSurface,
    detailPlaceholderSurface,
    detailPillSurface,
    detailCloseSurface,
    worldTagSurface,
    originCharacterTagSurface,
    originListTagSurface,
    roleSelectorSurface,
    roleSelectorSelectedSurface,
    worldGlobalEventSurface,
    actionMenuSurface,
    searchCompactSurface,
    searchHistorySurface,
    gemProductSurface,
    gemLoadingSurface,
    gemEmptySurface,
    discussQuoteSurface,
    discussRepliesSurface,
    discussComposerSurface,
    mediaErrorOverlay,
    mediaRemoveSurface,
    mediaControlShadow,
    skeletonBase,
    skeletonHighlight,
    profileGemSurface,
    mediaControlOverlay,
    textPrimary,
    textSecondary,
    textTertiary,
    textDisabled,
    textInverse,
    textLink,
    textEmailLink,
    iconPrimary,
    iconSecondary,
    detailPlaceholderIcon,
    navigationChevron,
    textStrong,
    textSecondaryStrong,
    textMetadata,
    textRole,
    textTimestamp,
    textMuted,
    textSectionTitle,
    textOnDark,
    textEmptyState,
    textCounter,
    textFormHint,
    textListMetadata,
    textDeveloperDisabled,
    textHighEmphasis,
    textDetailBody,
    originCharacterSubtitle,
    roleSelectorInactiveText,
    searchCancelText,
    originListTagText,
    discussReplyText,
    discussComposerHint,
    messageMutedText,
    messageMetadataText,
    messageOriginLinkText,
    border,
    borderStrong,
    divider,
    borderFocus,
    listDivider,
    detailDivider,
    discussQuoteBorder,
    discussRepliesBorder,
    bottomSheetHandle,
    attachmentBorder,
    roleSelectorBorder,
    roleFormBorder,
    searchCompactBorder,
    gemProductBorder,
    gemSoldOutBorder,
    profileGemBorder,
    brand,
    brandBright,
    brandDisabled,
    actionDisabledForeground,
    create,
    bottomNavigationProminent,
    danger,
    success,
    successContainer,
    warning,
    warningContainer,
    info,
    infoContainer,
    neutralControlForeground,
    neutralControlDisabledForeground,
    destructiveControl,
    messagePositiveState,
    discussInactiveAction,
    discussComposerCursor,
    discussAttachmentAction,
    discussSendAction,
    discussSendDisabled,
    attachmentIcon,
    roleLaunchDisabled,
    roleSelectionShadow,
    gemSoldOutForeground,
    gemTaskAction,
    privateChatBackground,
    privateChatBubbleSelf,
    privateChatBubbleOther,
    locationChatBackground,
    locationChatForeground,
    locationChatChromeStrong,
    locationChatChromeSoft,
    mapControlBackground,
    homeFeedAccent,
    gemAccent,
    formField,
    worldAction,
    originPreviewAccent,
    gemNewUserTag,
    gemStandardTag,
    ...assetSourceByArgb.values,
    assetOverlayLight,
  ];

  static final Map<String, GenesisColorToken> byId =
      <String, GenesisColorToken>{for (final token in values) token.id: token};

  @override
  bool operator ==(Object other) =>
      other is GenesisColorToken && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
