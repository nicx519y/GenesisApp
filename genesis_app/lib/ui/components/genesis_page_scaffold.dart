import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_spacing.dart';
import 'genesis_app_bar.dart';
import 'genesis_page_header.dart';

enum GenesisPageScaffoldVariant { root, secondary, editor, immersive, custom }

/// The standard scrollable body for ordinary root, secondary, and editor pages.
///
/// Keep page chrome in [GenesisPageScaffold] and place only the page-specific
/// sections in [children]. This prevents each new page from recreating its own
/// scroll padding and keyboard-dismiss behavior.
class GenesisPageScrollBody extends StatelessWidget {
  const GenesisPageScrollBody({
    super.key,
    required this.children,
    this.padding = GenesisSpacing.pagePadding,
    this.controller,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: padding,
      physics: physics,
      keyboardDismissBehavior: keyboardDismissBehavior,
      children: children,
    );
  }
}

class GenesisPageScaffold extends StatelessWidget {
  const GenesisPageScaffold.root({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.showSearchField = false,
    this.searchHintText = 'Explore',
    this.onSearchTap,
    this.contentPadding = GenesisSpacing.pagePadding,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.bottomNavigationBar,
    this.floatingActionButton,
  }) : variant = GenesisPageScaffoldVariant.root,
       onBack = null,
       actions = null,
       appBar = null,
       showBackButton = false,
       extendBodyBehindAppBar = false,
       safeAreaBottom = true;

  const GenesisPageScaffold.secondary({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions,
    this.showBackButton = true,
    this.contentPadding = GenesisSpacing.pagePadding,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeAreaBottom = true,
  }) : variant = GenesisPageScaffoldVariant.secondary,
       trailing = null,
       appBar = null,
       showSearchField = false,
       searchHintText = 'Explore',
       onSearchTap = null,
       extendBodyBehindAppBar = false;

  const GenesisPageScaffold.editor({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions,
    this.showBackButton = true,
    this.contentPadding = GenesisSpacing.formPagePadding,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeAreaBottom = true,
  }) : variant = GenesisPageScaffoldVariant.editor,
       trailing = null,
       appBar = null,
       showSearchField = false,
       searchHintText = 'Explore',
       onSearchTap = null,
       extendBodyBehindAppBar = false;

  const GenesisPageScaffold.immersive({
    super.key,
    this.title = '',
    required this.body,
    this.onBack,
    this.actions,
    this.showBackButton = false,
    this.contentPadding = EdgeInsets.zero,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true,
    this.safeAreaBottom = false,
  }) : variant = GenesisPageScaffoldVariant.immersive,
       trailing = null,
       appBar = null,
       showSearchField = false,
       searchHintText = 'Explore',
       onSearchTap = null;

  /// Keeps legacy pages inside the shared page-chrome boundary while their
  /// feature-specific header, map, or fixed composer layout is migrated.
  ///
  /// New ordinary pages should use one of the semantic constructors above.
  const GenesisPageScaffold.custom({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = false,
  }) : variant = GenesisPageScaffoldVariant.custom,
       title = '',
       onBack = null,
       actions = null,
       trailing = null,
       showBackButton = false,
       showSearchField = false,
       searchHintText = 'Explore',
       onSearchTap = null,
       contentPadding = EdgeInsets.zero,
       safeAreaBottom = false;

  final GenesisPageScaffoldVariant variant;
  final String title;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? trailing;
  final bool showBackButton;
  final bool showSearchField;
  final String searchHintText;
  final VoidCallback? onSearchTap;
  final EdgeInsetsGeometry contentPadding;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    final root = variant == GenesisPageScaffoldVariant.root;
    final immersive = variant == GenesisPageScaffoldVariant.immersive;
    final custom = variant == GenesisPageScaffoldVariant.custom;
    final content = SafeArea(
      top: immersive,
      bottom: safeAreaBottom,
      child: Padding(padding: contentPadding, child: body),
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? context.genesisColors.pageBackground,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: custom
          ? appBar
          : root || immersive
          ? null
          : GenesisAppBar(
              title: title,
              variant: GenesisAppBarVariant.leadingTitle,
              onBack: onBack,
              showBackButton: showBackButton,
              actions: actions,
            ),
      body: root
          ? Column(
              children: [
                GenesisPageHeader(
                  title: title,
                  showSearchField: showSearchField,
                  searchHintText: searchHintText,
                  onSearchTap: onSearchTap,
                  trailing: trailing,
                ),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
