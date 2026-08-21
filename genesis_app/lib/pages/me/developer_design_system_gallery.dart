import 'package:flutter/material.dart';

import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../ui/genesis_ui.dart';

class DeveloperDesignSystemGalleryPage extends StatefulWidget {
  const DeveloperDesignSystemGalleryPage({super.key});

  @override
  State<DeveloperDesignSystemGalleryPage> createState() =>
      _DeveloperDesignSystemGalleryPageState();
}

class _DeveloperDesignSystemGalleryPageState
    extends State<DeveloperDesignSystemGalleryPage> {
  final _textController = TextEditingController();
  final _areaController = TextEditingController();
  int _selectedFilter = 0;

  @override
  void dispose() {
    _textController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GenesisPageScaffold.secondary(
      title: 'Design System',
      contentPadding: EdgeInsets.zero,
      body: ListView(
        padding: GenesisSpacing.formPagePadding.copyWith(top: 20, bottom: 32),
        children: [
          const GenesisSectionPanel(
            title: 'Typography',
            margin: EdgeInsets.only(bottom: GenesisSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Page title', style: GenesisTypography.pageTitle),
                SizedBox(height: 8),
                Text(
                  'Navigation title',
                  style: GenesisTypography.navigationTitle,
                ),
                SizedBox(height: 8),
                Text('Section title', style: GenesisTypography.sectionTitle),
                SizedBox(height: 8),
                Text('Body text', style: GenesisTypography.body),
                SizedBox(height: 8),
                Text('Supporting text', style: GenesisTypography.supporting),
              ],
            ),
          ),
          GenesisSectionPanel(
            title: 'Buttons',
            margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
            child: Column(
              children: [
                GenesisButton(label: 'Primary', onPressed: () {}),
                const SizedBox(height: 8),
                GenesisButton(
                  label: 'Secondary',
                  variant: GenesisButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                GenesisButton(
                  label: 'Destructive',
                  variant: GenesisButtonVariant.destructive,
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
              ],
            ),
          ),
          GenesisSectionPanel(
            title: 'Controls and metadata',
            margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GenesisControlButton(
                      tooltip: 'More actions',
                      onPressed: () {},
                      child: GenesisMoreIcon(
                        color: context.genesisColors.foregroundStrong,
                      ),
                    ),
                    const SizedBox(width: GenesisSpacing.lg),
                    GenesisControlButton(
                      tooltip: 'Disabled action',
                      onPressed: null,
                      child: GenesisCloseIcon(
                        color: context.genesisColors.iconMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GenesisSpacing.xl),
                Wrap(
                  spacing: GenesisSpacing.md,
                  runSpacing: GenesisSpacing.xs,
                  children: [
                    for (var index = 0; index < 3; index++)
                      GenesisFilterChip(
                        label: const ['All', 'Active', 'Archived'][index],
                        selected: _selectedFilter == index,
                        onPressed: () =>
                            setState(() => _selectedFilter = index),
                      ),
                    const GenesisFilterChip(
                      label: 'Disabled',
                      selected: false,
                      onPressed: null,
                    ),
                  ],
                ),
                const SizedBox(height: GenesisSpacing.xl),
                const Wrap(
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
                    GenesisTag(
                      label: 'blocked',
                      tone: GenesisTagTone.danger,
                      size: GenesisTagSize.compact,
                    ),
                    GenesisUnreadBadge(count: 7),
                    GenesisUnreadBadge(count: 120),
                  ],
                ),
              ],
            ),
          ),
          GenesisSectionPanel(
            title: 'Form controls',
            margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
            child: Column(
              children: [
                GenesisTextField(
                  controller: _textController,
                  label: 'Name',
                  requiredIndicator: true,
                  hintText: 'Enter a name',
                  supportText: 'Single-line field with shared focus styling.',
                  maxLength: 30,
                ),
                const SizedBox(height: 16),
                GenesisTextArea(
                  controller: _areaController,
                  label: 'Description',
                  hintText: 'Describe this world...',
                  maxLength: 300,
                ),
                const SizedBox(height: 16),
                GenesisSelectField(
                  label: 'Role',
                  hintText: 'Select a role',
                  onTap: () {},
                ),
              ],
            ),
          ),
          GenesisSectionPanel(
            title: 'Search and navigation',
            margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
            child: Column(
              children: [
                GenesisSearchField.launcher(onTap: () {}),
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
            title: 'Media',
            margin: EdgeInsets.only(bottom: GenesisSpacing.section),
            child: Row(
              children: [
                GenesisAvatar(name: 'Worldo', size: 48),
                SizedBox(width: GenesisSpacing.xl),
                GenesisCharacterAvatar(
                  url: '',
                  name: 'Nikos',
                  size: 48,
                  showStar: true,
                ),
              ],
            ),
          ),
          GenesisSectionPanel(
            title: 'Page states',
            margin: const EdgeInsets.only(bottom: GenesisSpacing.section),
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
            child: Column(
              children: [
                GenesisButton(
                  label: 'Action box',
                  variant: GenesisButtonVariant.secondary,
                  onPressed: _showActionBox,
                ),
                const SizedBox(height: 8),
                GenesisButton(
                  label: 'Content dialog',
                  variant: GenesisButtonVariant.secondary,
                  onPressed: _showContentDialog,
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
      ),
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

  Future<void> _showContentDialog() async {
    await showGenesisContentDialog<void>(
      context: context,
      title: 'Content dialog',
      content: const Text(
        'Use this pattern for structured content that does not fit an action box.',
      ),
      showCloseButton: true,
      actions: [
        GenesisDialogAction(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
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
