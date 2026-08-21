import 'package:flutter/material.dart';

import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../ui/genesis_ui.dart';

const EdgeInsets _gallerySectionPadding = EdgeInsets.symmetric(
  vertical: GenesisSpacing.page,
);

class DeveloperDesignSystemGalleryContent extends StatefulWidget {
  const DeveloperDesignSystemGalleryContent({super.key});

  @override
  State<DeveloperDesignSystemGalleryContent> createState() =>
      _DeveloperDesignSystemGalleryContentState();
}

class _DeveloperDesignSystemGalleryContentState
    extends State<DeveloperDesignSystemGalleryContent> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GenesisSectionPanel(
          title: 'Typography',
          margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
          padding: _gallerySectionPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Titles',
                style: GenesisTypography.sectionTitle.copyWith(
                  color: context.genesisColors.textPrimary,
                ),
              ),
              const SizedBox(height: GenesisSpacing.md),
              const _TypographySpecimen(
                name: 'Page / display title',
                spec: 'Size 24 · Extra bold',
                child: Text('Messages', style: GenesisTypography.pageTitle),
              ),
              const _TypographySpecimen(
                name: 'Navigation title',
                spec: 'Size 17 · Bold',
                child: Text(
                  'Buy Gems',
                  style: GenesisTypography.navigationTitle,
                ),
              ),
              const _TypographySpecimen(
                name: 'Content title',
                spec: 'Size 17 · Extra bold',
                child: Text(
                  'Story title',
                  style: GenesisTypography.contentTitle,
                ),
              ),
              const _TypographySpecimen(
                name: 'Section title',
                spec: 'Size 15 · Bold',
                child: Text(
                  'World Brief',
                  style: GenesisTypography.sectionTitle,
                ),
              ),
              const SizedBox(height: GenesisSpacing.lg),
              Text(
                'Content and controls',
                style: GenesisTypography.sectionTitle.copyWith(
                  color: context.genesisColors.textPrimary,
                ),
              ),
              const SizedBox(height: GenesisSpacing.md),
              const _TypographySpecimen(
                name: 'Body text',
                spec: 'Size 14 · Regular / semibold emphasis',
                child: Text('Body', style: GenesisTypography.body),
              ),
              const _TypographySpecimen(
                name: 'Supporting text',
                spec: 'Size 12 · Regular',
                child: Text('Supporting', style: GenesisTypography.supporting),
              ),
              const _TypographySpecimen(
                name: 'Tab text',
                spec: 'Size 11 · Regular',
                child: Text('Tab', style: GenesisTypography.tabLabel),
              ),
              const _TypographySpecimen(
                name: 'Caption',
                spec: 'Size 10 · Medium',
                child: Text('Caption', style: GenesisTypography.caption),
              ),
            ],
          ),
        ),
        GenesisSectionPanel(
          title: 'Page navigation',
          margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
          padding: EdgeInsets.zero,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: SizedBox(
              key: const ValueKey<String>('design-system-leading-title-header'),
              height: 64,
              child: GenesisAppBar(
                title: 'Buy Gems',
                variant: GenesisAppBarVariant.leadingTitle,
                onBack: () {},
                backgroundColor: context.genesisColors.surfaceRaised,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(
                      right: GenesisControlMetrics.appBarHorizontalPadding,
                    ),
                    child: GenesisAppBarActionLink(
                      label: 'Records',
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GenesisSectionPanel(
          title: 'Buttons',
          margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
          padding: _gallerySectionPadding,
          child: Column(
            children: [
              Text(
                'Regular 42px · Compact 40px · minimum tap target 44px',
                style: GenesisTypography.caption.copyWith(
                  color: context.genesisColors.textSecondary,
                ),
              ),
              const SizedBox(height: GenesisSpacing.lg),
              GenesisButton(label: 'Primary', onPressed: () {}),
              const SizedBox(height: 8),
              GenesisButton(
                label: 'Secondary',
                variant: GenesisButtonVariant.secondary,
                onPressed: () {},
              ),
              const SizedBox(height: 8),
              const GenesisButton(label: 'Disabled', onPressed: null),
              const SizedBox(height: 8),
              const GenesisButton(
                label: 'Loading',
                onPressed: null,
                isLoading: true,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: GenesisCardActionButton(
                  key: const ValueKey<String>('design-system-select-button'),
                  label: 'Select',
                  height: GenesisUiTheme.of(context).regularButtonHeight,
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: GenesisSpacing.xl),
              Divider(height: 1, color: context.genesisColors.dividerSubtle),
              const SizedBox(height: GenesisSpacing.xl),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Icon buttons',
                  style: GenesisTypography.supporting.copyWith(
                    color: context.genesisColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: GenesisSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  GenesisBackButton(
                    key: const ValueKey<String>('design-system-back-button'),
                    onPressed: () {},
                  ),
                  const SizedBox(width: GenesisSpacing.md),
                  GenesisCardActionButton.icon(
                    icon: Icons.edit_rounded,
                    tooltip: 'Edit',
                    onPressed: () {},
                  ),
                  const SizedBox(width: GenesisSpacing.md),
                  GenesisControlButton(
                    tooltip: 'More actions',
                    onPressed: () {},
                    child: GenesisMoreIcon(
                      color: context.genesisColors.foregroundStrong,
                    ),
                  ),
                  const SizedBox(width: GenesisSpacing.md),
                  GenesisControlButton(
                    tooltip: 'Close',
                    onPressed: () {},
                    child: GenesisCloseIcon(
                      color: context.genesisColors.foregroundStrong,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        GenesisSectionPanel(
          title: 'Search, tabs and list navigation',
          margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
          padding: _gallerySectionPadding,
          child: Column(
            children: [
              GenesisSearchField.launcher(onTap: () {}),
              const SizedBox(height: 16),
              DefaultTabController(
                length: 3,
                child: GenesisTabBar(
                  labels: const ['Following', 'Worlds', 'Origins'],
                  horizontalPadding: 0,
                  indicatorMatchesLabelWidth: true,
                ),
              ),
              const SizedBox(height: 16),
              GenesisNavigationRow(
                label: 'Navigation row',
                trailing: const Text('Value'),
                onTap: () {},
              ),
            ],
          ),
        ),
        const GenesisSectionPanel(
          title: 'Tags and badges',
          margin: EdgeInsets.only(bottom: GenesisSpacing.section),
          padding: _gallerySectionPadding,
          child: Wrap(
            spacing: GenesisSpacing.md,
            runSpacing: GenesisSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GenesisTag(label: 'world'),
              GenesisTag(
                label: 'trending',
                tone: GenesisTagTone.accent,
                size: GenesisTagSize.compact,
              ),
              _UnreadBadgePreview(name: 'M', count: 7),
              _UnreadBadgePreview(name: 'W', count: 120),
            ],
          ),
        ),
        GenesisSectionPanel(
          title: 'Page States',
          margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
          padding: _gallerySectionPadding,
          child: Column(
            children: [
              const GenesisStateView.loading(height: 64),
              const GenesisStateView.empty(
                message: 'Nothing here yet.',
                height: 64,
                compact: true,
              ),
              GenesisStateView.error(
                message: 'Unable to load.',
                onAction: () {},
                height: 96,
                compact: true,
              ),
            ],
          ),
        ),
        GenesisSectionPanel(
          title: 'Overlays',
          padding: _gallerySectionPadding,
          child: Column(
            children: [
              GenesisButton(
                label: 'Action box',
                variant: GenesisButtonVariant.secondary,
                onPressed: _showActionBox,
              ),
              const SizedBox(height: 8),
              GenesisButton(
                label: 'Bottom sheet',
                variant: GenesisButtonVariant.secondary,
                onPressed: _showBottomSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showActionBox() async {
    await showGenesisActionBox<bool>(
      context: context,
      title: 'Discard changes?',
      titleContent: const Text('This is the shared confirmation pattern.'),
      titleHeight: 104,
      actions: const [
        GenesisActionBoxAction<bool>(label: 'Discard', value: true),
      ],
    );
  }

  Future<void> _showBottomSheet() async {
    await showGenesisModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => GenesisBottomSheetPanel.content(
        title: 'Bottom sheet',
        trailing: GenesisBottomSheetCloseButton(
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
        child: const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'Content-sized sheets use the shared surface and header.',
          ),
        ),
      ),
    );
  }
}

class _TypographySpecimen extends StatelessWidget {
  const _TypographySpecimen({
    required this.name,
    required this.spec,
    required this.child,
  });

  final String name;
  final String spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: GenesisSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.genesisColors.dividerSubtle),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GenesisTypography.bodyStrong.copyWith(
                    color: context.genesisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: GenesisSpacing.xs),
                Text(
                  spec,
                  style: GenesisTypography.supporting.copyWith(
                    color: context.genesisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: GenesisSpacing.lg),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _UnreadBadgePreview extends StatelessWidget {
  const _UnreadBadgePreview({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: GenesisAvatar(name: name, size: 44),
          ),
          Positioned(top: 0, right: 0, child: GenesisUnreadBadge(count: count)),
        ],
      ),
    );
  }
}
