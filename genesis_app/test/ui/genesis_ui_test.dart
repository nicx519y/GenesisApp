import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_action_box.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_palette.dart';

void main() {
  testWidgets('GenesisTheme provides shared app styles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Text('body', style: theme.textTheme.bodyMedium);
          },
        ),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.theme?.scaffoldBackgroundColor,
      GenesisPalette.redesignPaper,
    );
    expect(
      materialApp.theme?.textTheme.bodyMedium?.fontSize,
      GenesisTypography.body.fontSize,
    );
    expect(
      materialApp.theme?.textTheme.bodyMedium?.fontFamilyFallback,
      GenesisTypography.fontFamilyFallback,
    );
    expect(
      materialApp.theme?.textTheme.bodyMedium?.fontFamily,
      GenesisTypography.fontFamily,
    );
    final dialogShape = materialApp.theme?.dialogTheme.shape;
    expect(dialogShape, isA<RoundedRectangleBorder>());
    final roundedDialogShape = dialogShape! as RoundedRectangleBorder;
    expect(roundedDialogShape.side.width, genesisModalBorderWidth);
    expect(
      roundedDialogShape.side.color,
      GenesisPalette.redesignInk.withValues(alpha: genesisModalBorderOpacity),
    );
    final popupShape = materialApp.theme?.popupMenuTheme.shape;
    expect(popupShape, isA<RoundedRectangleBorder>());
    final roundedPopupShape = popupShape! as RoundedRectangleBorder;
    expect(roundedPopupShape.side.width, genesisModalBorderWidth);
    expect(
      roundedPopupShape.side.color,
      GenesisPalette.redesignInk.withValues(alpha: genesisModalBorderOpacity),
    );
    final bottomSheetShape = materialApp.theme?.bottomSheetTheme.shape;
    expect(bottomSheetShape, isA<RoundedRectangleBorder>());
    final roundedBottomSheetShape = bottomSheetShape! as RoundedRectangleBorder;
    expect(roundedBottomSheetShape.side.width, genesisModalBorderWidth);
    expect(
      roundedBottomSheetShape.side.color,
      GenesisPalette.redesignInk.withValues(alpha: genesisModalBorderOpacity),
    );
  });

  test('GenesisTheme disables Material state effects', () {
    final theme = GenesisTheme.worldoLight();
    const pressed = <WidgetState>{WidgetState.pressed};
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.splashColor, Colors.transparent);
    expect(theme.highlightColor, Colors.transparent);
    expect(theme.hoverColor, Colors.transparent);
    expect(theme.focusColor, Colors.transparent);
    for (final style in <ButtonStyle?>[
      theme.filledButtonTheme.style,
      theme.textButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.elevatedButtonTheme.style,
      theme.iconButtonTheme.style,
    ]) {
      expect(style?.splashFactory, NoSplash.splashFactory);
      expect(style?.overlayColor?.resolve(pressed), Colors.transparent);
    }
    expect(
      theme.checkboxTheme.overlayColor?.resolve(pressed),
      Colors.transparent,
    );
    expect(theme.radioTheme.overlayColor?.resolve(pressed), Colors.transparent);
    expect(
      theme.switchTheme.overlayColor?.resolve(pressed),
      Colors.transparent,
    );
    expect(theme.floatingActionButtonTheme.splashColor, Colors.transparent);
    expect(theme.tabBarTheme.splashFactory, NoSplash.splashFactory);
    expect(
      theme.tabBarTheme.overlayColor?.resolve(pressed),
      Colors.transparent,
    );
  });

  test('GenesisTypography applies the Worldo Inter font stack', () {
    for (final style in <TextStyle>[
      GenesisTypography.pageTitle,
      GenesisTypography.displayTitle,
      GenesisTypography.metricValue,
      GenesisTypography.prominentMetricValue,
      GenesisTypography.navigationTitle,
      GenesisTypography.immersiveTitle,
      GenesisTypography.contentTitle,
      GenesisTypography.sectionTitle,
      GenesisTypography.body,
      GenesisTypography.bodyStrong,
      GenesisTypography.supporting,
      GenesisTypography.tabLabel,
    ]) {
      expect(style.fontFamily, GenesisTypography.fontFamily);
      expect(style.fontFamilyFallback, GenesisTypography.fontFamilyFallback);
      expect(style.color, isNull);
    }
    expect(GenesisTypography.pageTitle.fontSize, 24);
    expect(GenesisTypography.pageTitle.fontWeight, FontWeight.w900);
    expect(GenesisTypography.pageTitle.height, 1);
    expect(GenesisTypography.pageTitle.letterSpacing, -0.36);
    expect(GenesisTypography.displayTitle.fontSize, 24);
    expect(GenesisTypography.displayTitle.fontWeight, FontWeight.w900);
    expect(GenesisTypography.displayTitle.height, 1);
    expect(GenesisTypography.displayTitle.letterSpacing, isNull);
    expect(GenesisTypography.metricValue, GenesisTypography.displayTitle);
    expect(GenesisTypography.prominentMetricValue.fontSize, 30);
    expect(GenesisTypography.prominentMetricValue.fontWeight, FontWeight.w900);
    expect(GenesisTypography.prominentMetricValue.height, 1);
    expect(GenesisTypography.navigationTitle.fontSize, 17);
    expect(GenesisTypography.navigationTitle.fontWeight, FontWeight.w800);
    expect(GenesisTypography.navigationTitle.height, 1);
    expect(GenesisTypography.immersiveTitle.fontSize, 17);
    expect(GenesisTypography.immersiveTitle.fontWeight, FontWeight.w800);
    expect(GenesisTypography.immersiveTitle.height, 1.1);
    expect(GenesisTypography.contentTitle.fontSize, 17);
    expect(GenesisTypography.contentTitle.fontWeight, FontWeight.w900);
    expect(GenesisTypography.contentTitle.height, 1.15);
    expect(GenesisTypography.sectionTitle.fontSize, 15);
    expect(GenesisTypography.sectionTitle.fontWeight, FontWeight.w800);
    expect(GenesisTypography.sectionTitle.height, 1);
  });

  testWidgets('explicit Text styles keep their own font selection', (
    tester,
  ) async {
    const styledText = '☛ ˙۵ও⃢♥︎ ━  𝙏ᶦⁿᶦᵗᵃ 🍓|🎀〬𓈒ֹ⁠꙳';

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          styledText,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text.style?.fontFamily, isNull);
    expect(richText.text.style?.fontFamilyFallback, isNull);
  });

  testWidgets('Genesis UI components read colors from semantic theme roles', (
    tester,
  ) async {
    const searchColor = Color(0xFF123456);
    const titleColor = Color(0xFF654321);
    const primaryColor = Color(0xFF246824);
    const selectedColor = Color(0xFF135790);
    const unselectedColor = Color(0xFF975310);
    final semanticColors = GenesisSemanticColors.worldoLight().copyWith(
      inputBackground: searchColor,
      textPrimary: titleColor,
      danger: Colors.orange,
      primary: primaryColor,
      navigationSelected: selectedColor,
      navigationUnselected: unselectedColor,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight().copyWith(
          extensions: <ThemeExtension<dynamic>>[
            semanticColors,
            GenesisUiTheme.worldo(),
          ],
        ),
        home: Scaffold(
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const GenesisPageTitle(text: 'Styled title'),
                const GenesisSearchField(hintText: 'Styled search'),
                const GenesisTabBar(labels: ['One', 'Two']),
                GenesisButton(
                  key: const ValueKey('semantic-primary-button'),
                  label: 'Continue',
                  onPressed: () {},
                  fullWidth: false,
                ),
              ],
            ),
          ),
          bottomNavigationBar: GenesisBottomNavigation(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              GenesisBottomNavigationItem(
                label: 'Create',
                icon: Icons.add_circle_outline,
                prominent: true,
              ),
            ],
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Styled title'));
    expect(title.style?.color, titleColor);

    final searchContainer = tester.widget<Container>(
      find.descendant(
        of: find.byType(GenesisSearchField),
        matching: find.byType(Container),
      ),
    );
    final searchDecoration = searchContainer.decoration as BoxDecoration;
    expect(searchDecoration.color, searchColor);

    final icon = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
    expect(icon.color, semanticColors.onDanger);
    final prominentSurface = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(GenesisBottomNavigation),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<ShapeDecoration>()
        .single;
    expect(prominentSurface.color, Colors.orange);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.labelColor, selectedColor);
    expect(tabBar.unselectedLabelColor, unselectedColor);
    expect(
      (tabBar.indicator! as GenesisFixedUnderlineIndicator).color,
      Colors.orange,
    );

    final primaryButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('semantic-primary-button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      primaryButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      primaryColor,
    );
  });

  test('Worldo light semantic roles use paper ink and accent', () {
    final colors = GenesisSemanticColors.worldoLight();

    expect(colors.pageBackground, GenesisPalette.redesignPaper);
    expect(colors.surface, GenesisPalette.redesignPaper);
    expect(colors.inputBackground, GenesisPalette.white);
    expect(colors.textPrimary, GenesisPalette.redesignInk);
    expect(colors.textSecondary, GenesisPalette.redesignInk60);
    expect(colors.primary, GenesisPalette.redesignAccent);
    expect(colors.primaryDisabled, GenesisPalette.redesignAccent40);
    expect(colors.danger, GenesisPalette.redesignAccent);
    expect(colors.navigationSelected, GenesisPalette.redesignInk);
    expect(colors.navigationUnselected, GenesisPalette.redesignTextSecondary);
    expect(colors.textStrong, GenesisPalette.redesignInk88);
    expect(colors.textHighEmphasis, GenesisPalette.redesignInk88);
    expect(colors.foregroundStrong, GenesisPalette.redesignInk);
    expect(colors.textHeading, GenesisPalette.redesignInk);
    expect(colors.textBody, GenesisPalette.redesignInk80);
    expect(colors.textMuted, GenesisPalette.redesignInk60);
    expect(colors.textSubtle, GenesisPalette.redesignInk50);
    expect(colors.textTagline, GenesisPalette.redesignInk50);
    expect(colors.textFaint, GenesisPalette.redesignInk50);
    expect(colors.textSupporting, GenesisPalette.redesignInk50);
    expect(colors.textTimestamp, GenesisPalette.redesignInk42);
    expect(colors.textMetadata, GenesisPalette.redesignInk42);
    expect(colors.inputHint, GenesisPalette.redesignInk50);
    expect(colors.textEmptyState, GenesisPalette.redesignInk50);
    expect(colors.textLabelMuted, GenesisPalette.redesignInk50);
    expect(colors.textPlaceholder, GenesisPalette.redesignInk42);
    expect(colors.iconMuted, const Color(0xFF5C5862));
    expect(colors.dividerSubtle, const Color(0xFFE7E7E7));
    expect(colors.dividerMuted, const Color(0xFFEFEFEF));
    expect(colors.inputBorder, const Color(0xFFD8D8DE));
    expect(colors.surfaceDisabled, const Color(0xFFE5E5E5));
    expect(colors.surfaceProgress, const Color(0xFFF4F4F8));
    expect(colors.surfaceGrouped, const Color(0xFFF4F4F5));
    expect(colors.surfaceTag, const Color(0xFFF1F3F6));
    expect(colors.dangerControl, GenesisPalette.redesignAccent);
    expect(colors.dangerSurface, const Color(0xFFFFF4F6));
    expect(colors.dangerBorder, const Color(0xFFFFE0E6));
  });

  test('GenesisTheme registers all feature color extensions', () {
    final theme = GenesisTheme.worldoLight();

    expect(theme.extension<GenesisChatTheme>(), isNotNull);
    expect(theme.extension<GenesisGemColors>(), isNotNull);
    expect(theme.extension<GenesisOriginColors>(), isNotNull);
    expect(theme.extension<GenesisDiscussColors>(), isNotNull);
    expect(theme.extension<GenesisCreateColors>(), isNotNull);
    expect(theme.extension<GenesisWorldColors>(), isNotNull);
    expect(theme.extension<GenesisMessageColors>(), isNotNull);
  });

  testWidgets('GenesisSearchField keeps placeholder on one line', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 180, child: GenesisSearchField())),
      ),
    );

    final placeholder = tester.widget<Text>(find.text('Explore'));
    expect(placeholder.maxLines, 1);
    expect(placeholder.overflow, TextOverflow.ellipsis);
    expect(placeholder.softWrap, isFalse);
  });

  testWidgets(
    'GenesisSearchField uses decorative unicode visual fallback input',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      const raw = '☛ ˙۵ও⃢♥︎ ━  𝙏ᶦⁿᶦᵗᵃ 🍓|🎀〬𓈒ֹ⁠꙳';
      const rendered = '☛ ˙۵▤▤▤♥︎ ━  𝙏ᶦⁿᶦᵗᵃ 🍓|🎀°ₒ✩';

      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.worldoLight(),
          home: Scaffold(
            body: GenesisSearchField(
              controller: controller,
              hintText: 'Search',
              textStyle: const TextStyle(fontSize: 16),
              hintStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), raw);
      await tester.pump();

      expect(controller.text, rendered);
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.style?.fontFamily, GenesisTypography.fontFamily);
      expect(
        input.style?.fontFamilyFallback,
        GenesisTypography.fontFamilyFallback,
      );
      expect(
        input.decoration?.hintStyle?.fontFamilyFallback,
        GenesisTypography.fontFamilyFallback,
      );
    },
  );

  testWidgets('GenesisPageHeader composes title and search field', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenesisPageHeader(
            title: 'Worldo',
            onSearchTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Worldo'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    expect(tapped, isTrue);
  });

  testWidgets('GenesisSearchField compact uses the product search asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisSearchField(
            variant: GenesisSearchFieldVariant.compact,
            hintText: 'Explore',
          ),
        ),
      ),
    );

    expect(find.byType(GenesisSearchField), findsOneWidget);
    final icon = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect((icon.bytesLoader as SvgAssetLoader).assetName, searchIconAsset);
    expect(icon.width, genesisSearchIconSize);
    expect(icon.height, genesisSearchIconSize);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.text('Explore'), findsOneWidget);
    expect(
      tester.getSize(find.byType(GenesisSearchField)).height,
      GenesisControlMetrics.minimumTapTarget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('genesis-search-field-visual')))
          .height,
      genesisCompactSearchFieldHeight,
    );
  });

  testWidgets('GenesisPageHeader reuses compact GenesisSearchField', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GenesisPageHeader(title: 'Worldo')),
      ),
    );

    expect(find.text('Worldo'), findsOneWidget);
    final searchField = tester.widget<GenesisSearchField>(
      find.byType(GenesisSearchField),
    );
    expect(searchField.variant, GenesisSearchFieldVariant.compact);
  });

  testWidgets('GenesisPageHeader includes the top system view padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.only(top: 24),
          ),
          child: Scaffold(
            body: Column(
              children: [
                GenesisPageHeader(title: 'Origin', showSearchField: false),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(GenesisPageHeader)).height, 74);
    expect(tester.getTopLeft(find.text('Origin')).dy, greaterThanOrEqualTo(24));
  });

  testWidgets('GenesisBackAppBar exposes back, title tap, and actions', (
    tester,
  ) async {
    var backCount = 0;
    var titleTapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          appBar: GenesisBackAppBar(
            pageName: 'Details',
            onBack: () => backCount += 1,
            onTitleTap: () => titleTapCount += 1,
            actions: const [Icon(Icons.more_horiz)],
          ),
        ),
      ),
    );

    expect(
      const GenesisBackAppBar(pageName: 'Details').preferredSize.height,
      64,
    );
    final backButton = find.byType(GenesisBackButton);
    expect(tester.getSize(backButton), const Size.square(34));
    expect(
      find.descendant(of: backButton, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    final buttonMaterial = tester.widget<Material>(
      find.descendant(of: backButton, matching: find.byType(Material)),
    );
    final buttonContext = tester.element(backButton);
    expect(buttonMaterial.color, buttonContext.genesisColors.controlMuted);
    expect(buttonMaterial.color, const Color(0x1AFFFFFF));
    final buttonClip = tester.widget<ClipRRect>(
      find.descendant(of: backButton, matching: find.byType(ClipRRect)),
    );
    expect(buttonClip.borderRadius, BorderRadius.circular(11));
    await tester.tap(find.byType(GenesisBackIcon));
    await tester.tap(find.text('Details'));
    expect(backCount, 1);
    expect(titleTapCount, 1);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('GenesisPrimaryButton uses the shared filled-button surface', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        home: Scaffold(
          body: GenesisPrimaryButton(
            label: 'Continue',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    expect(tapped, isTrue);

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    expect(
      theme?.filledButtonTheme.style?.backgroundColor?.resolve(
        const <WidgetState>{},
      ),
      GenesisPalette.redesignAccent,
    );
  });

  testWidgets('GenesisPrimaryButton owns default disabled styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisPrimaryButton(label: 'Continue', onPressed: null),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      GenesisPalette.redesignAccent40,
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      Colors.white,
    );
  });

  testWidgets('GenesisPrimaryButton reports taps while disabled', (
    tester,
  ) async {
    var disabledTapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenesisPrimaryButton(
            label: 'Continue',
            onPressed: null,
            onDisabledPressed: () => disabledTapCount += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));

    expect(disabledTapCount, 1);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('GenesisButton exposes semantic variants', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GenesisButton(
                key: const ValueKey('primary-button'),
                label: 'Primary',
                onPressed: () {},
                fullWidth: false,
              ),
              GenesisButton(
                key: const ValueKey('secondary-button'),
                label: 'Secondary',
                onPressed: () {},
                variant: GenesisButtonVariant.secondary,
                fullWidth: false,
              ),
              GenesisButton(
                key: const ValueKey('destructive-button'),
                label: 'Delete',
                onPressed: () {},
                variant: GenesisButtonVariant.destructive,
                fullWidth: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('secondary-button')),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
    );
    final destructive = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('destructive-button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      destructive.style?.backgroundColor?.resolve(const <WidgetState>{}),
      GenesisPalette.redesignAccent,
    );
  });

  testWidgets('GenesisCardActionButton exposes text and icon actions', (
    tester,
  ) async {
    var selectCount = 0;
    var editCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 34,
            child: Row(
              children: [
                GenesisCardActionButton.icon(
                  surfaceKey: const ValueKey('card-edit-surface'),
                  interactionKey: const ValueKey('card-edit-action'),
                  icon: Icons.edit_rounded,
                  tooltip: 'Edit',
                  onPressed: () => editCount += 1,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: GenesisCardActionButton(
                    surfaceKey: const ValueKey('card-select-surface'),
                    interactionKey: const ValueKey('card-select-action'),
                    label: 'Select',
                    onPressed: () => selectCount += 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('card-edit-surface'))),
      const Size.square(34),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('card-select-surface'))).height,
      34,
    );
    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('card-select-surface')))
          .color,
      GenesisPalette.redesignWhite10,
    );
    final label = tester.widget<Text>(find.text('Select'));
    expect(label.style?.fontSize, 12);
    expect(label.style?.fontWeight, FontWeight.w700);

    await tester.tap(find.byKey(const ValueKey('card-edit-action')));
    await tester.tap(find.byKey(const ValueKey('card-select-action')));
    expect(editCount, 1);
    expect(selectCount, 1);
  });

  testWidgets('GenesisButton supports compact, regular, loading, and icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GenesisButton(
                key: const ValueKey('compact-button'),
                label: 'Retry',
                onPressed: () {},
                size: GenesisButtonSize.compact,
                fullWidth: false,
              ),
              GenesisButton(
                key: const ValueKey('regular-button'),
                label: 'Continue',
                onPressed: () {},
                leadingIcon: const Icon(Icons.rocket_launch),
                fullWidth: false,
              ),
              GenesisButton(
                key: const ValueKey('loading-button'),
                label: 'Saving',
                onPressed: () {},
                isLoading: true,
                fullWidth: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('compact-button'))).height,
      GenesisButton.compactHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('regular-button'))).height,
      GenesisButton.regularHeight,
    );
    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('loading-button')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    final loadingButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('loading-button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(loadingButton.onPressed, isNull);
    expect(
      loadingButton.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
      }),
      GenesisPalette.redesignAccent,
    );
    final loadingIndicator = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(const ValueKey('loading-button')),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(loadingIndicator.color, GenesisPalette.white);
    expect(
      loadingIndicator.backgroundColor,
      GenesisPalette.white.withValues(alpha: 0.32),
    );
    expect(loadingIndicator.strokeCap, StrokeCap.round);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        darkTheme: GenesisTheme.worldoDark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: GenesisButton(
            key: ValueKey('dark-loading-button'),
            label: 'Saving',
            onPressed: null,
            isLoading: true,
            fullWidth: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final darkLoadingButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('dark-loading-button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      darkLoadingButton.style?.backgroundColor?.resolve(const <WidgetState>{
        WidgetState.disabled,
      }),
      GenesisPalette.redesignAccent,
    );
    final darkLoadingIndicator = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(const ValueKey('dark-loading-button')),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(darkLoadingIndicator.color, GenesisPalette.white);
    expect(
      darkLoadingIndicator.backgroundColor,
      GenesisPalette.white.withValues(alpha: 0.32),
    );
  });

  testWidgets('GenesisActionBox attaches cancel for a single action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showGenesisActionBox<bool>(
                    context: context,
                    title: 'Log out of your account?',
                    actions: const [
                      GenesisActionBoxAction<bool>(
                        label: 'Log out',
                        value: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
      findsOneWidget,
    );
    final attachedBorderContainer = tester.widget<Container>(
      find.byKey(const ValueKey('genesis-action-box-attached-border')),
    );
    final attachedDecoration =
        attachedBorderContainer.foregroundDecoration! as BoxDecoration;
    final attachedBorder = attachedDecoration.border! as Border;
    expect(attachedBorder.top.width, genesisModalBorderWidth);
    expect(
      attachedBorder.top.color,
      GenesisPalette.redesignInk.withValues(alpha: genesisModalBorderOpacity),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
      ),
      const Size(700, 186),
    );
    expect(find.text('Log out of your account?'), findsOneWidget);
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
    );
    final title = tester.widget<Text>(find.text('Log out of your account?'));
    final action = tester.widget<Text>(find.text('Log out'));
    final cancel = tester.widget<Text>(find.text('Cancel'));
    expect(
      (tester.getCenter(find.text('Log out of your account?')).dy -
              dialogRect.top) /
          dialogRect.height,
      closeTo(0.22, 0.02),
    );
    expect(
      (tester.getCenter(find.text('Log out')).dy - dialogRect.top) /
          dialogRect.height,
      closeTo(0.58, 0.02),
    );
    expect(
      (tester.getCenter(find.text('Cancel')).dy - dialogRect.top) /
          dialogRect.height,
      closeTo(0.86, 0.02),
    );
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(action.style?.fontSize, 15);
    expect(action.style?.fontWeight, FontWeight.w600);
    expect(action.style?.color, GenesisPalette.redesignAccent);
    expect(cancel.style?.fontSize, 15);
    expect(cancel.style?.fontWeight, FontWeight.w400);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('GenesisActionBox uses 70 percent width on compact screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showGenesisActionBox<bool>(
                    context: context,
                    title: 'Log out of your account?',
                    actions: const [
                      GenesisActionBoxAction<bool>(
                        label: 'Log out',
                        value: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
          )
          .width,
      224,
    );
  });

  testWidgets('GenesisActionBox can render one action without cancel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showGenesisActionBox<bool>(
                    context: context,
                    title: 'Purchase successful!',
                    actions: const [
                      GenesisActionBoxAction<bool>(label: 'OK', value: true),
                    ],
                    showCancel: false,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsNothing);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
      ),
      const Size(700, 134),
    );

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('GenesisActionBox detaches cancel for multiple actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showGenesisActionBox<String>(
                    context: context,
                    title: 'Save the draft before leaving?',
                    actions: const [
                      GenesisActionBoxAction<String>(
                        label: 'Save',
                        value: 'save',
                      ),
                      GenesisActionBoxAction<String>(
                        label: 'Discard',
                        value: 'discard',
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-action-box-detached-cancel')),
      findsOneWidget,
    );
    for (final key in const <String>[
      'genesis-action-box-detached-main-border',
      'genesis-action-box-detached-cancel-border',
    ]) {
      final borderContainer = tester.widget<Container>(
        find.byKey(ValueKey(key)),
      );
      final decoration = borderContainer.foregroundDecoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.width, genesisModalBorderWidth);
      expect(
        border.top.color,
        GenesisPalette.redesignInk.withValues(alpha: genesisModalBorderOpacity),
      );
    }
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('genesis-action-box-detached-cancel')),
          )
          .width,
      800,
    );
    expect(find.text('Save the draft before leaving?'), findsOneWidget);
    final firstAction = tester.widget<Text>(find.text('Save'));
    final secondAction = tester.widget<Text>(find.text('Discard'));
    expect(firstAction.style?.fontSize, 15);
    expect(firstAction.style?.fontWeight, FontWeight.w600);
    expect(secondAction.style?.fontSize, 15);
    expect(secondAction.style?.fontWeight, FontWeight.w600);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'save');
  });

  testWidgets('GenesisActionBox renders optional content below title', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showGenesisActionBox<String>(
                    context: context,
                    title: 'Join request',
                    content: const Text(
                      'Requester U_001',
                      key: ValueKey('action-box-custom-content'),
                    ),
                    actions: const [
                      GenesisActionBoxAction<String>(
                        label: 'Approve',
                        value: 'approve',
                      ),
                      GenesisActionBoxAction<String>(
                        label: 'Reject',
                        value: 'reject',
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('action-box-custom-content')),
      findsOneWidget,
    );

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(result, 'approve');
  });

  testWidgets('GenesisActionBox lets fixed areas use custom heights', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showGenesisActionBox<bool>(
                    context: context,
                    title: 'Compact title',
                    titleHeight: 48,
                    actionRowHeight: 44,
                    cancelRowHeight: 46,
                    actions: const [
                      GenesisActionBoxAction<bool>(
                        label: 'Confirm',
                        value: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open custom action box'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open custom action box'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-action-box-attached-cancel')),
      ),
      const Size(700, 140),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-action-box-title-row')),
      ),
      const Size(700, 48),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-action-box-action-row')),
      ),
      const Size(700, 44),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-action-box-cancel-row')),
      ),
      const Size(700, 46),
    );
    expect(tester.getSize(find.text('Compact title')).height, lessThan(48));
    expect(tester.widget<Text>(find.text('Compact title')).style?.height, 1.4);
    expect(tester.getSize(find.text('Confirm')).height, lessThan(44));
  });

  testWidgets('GenesisPrimaryButton supports action-specific styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisPrimaryButton(
            label: 'Log out',
            onPressed: null,
            backgroundColor: Color(0xFFE1E1E3),
            foregroundColor: Colors.black,
            disabledBackgroundColor: Color(0xFFE3E3E3),
            disabledForegroundColor: Color(0xFF6F6F6F),
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log out'),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0xFFE3E3E3),
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0xFF6F6F6F),
    );
    final shape =
        button.style?.shape?.resolve(<WidgetState>{}) as RoundedRectangleBorder;
    expect(shape.borderRadius, GenesisRadii.button);
    final textStyle = button.style?.textStyle?.resolve(<WidgetState>{});
    expect(textStyle?.fontSize, 16);
    expect(textStyle?.fontWeight, FontWeight.w600);
  });

  testWidgets('GenesisBottomNavigation delegates selection to onTap', (
    tester,
  ) async {
    var selectedIndex = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GenesisBottomNavigation(
            currentIndex: 0,
            onTap: (index) => selectedIndex = index,
            items: const [
              GenesisBottomNavigationItem(
                label: 'Home',
                icon: Icons.home_outlined,
              ),
              GenesisBottomNavigationItem(
                label: 'Create',
                icon: Icons.add_circle_outline,
                prominent: true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Create'));
    expect(selectedIndex, 1);
  });

  testWidgets('GenesisBottomNavigation switches asset icon by selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GenesisBottomNavigation(
            currentIndex: 1,
            onTap: (_) {},
            items: const [
              GenesisBottomNavigationItem(
                label: 'Home',
                iconAsset: bottomNavHomeIconAsset,
                selectedIconAsset: bottomNavHomePressIconAsset,
              ),
              GenesisBottomNavigationItem(
                label: 'Messages',
                iconAsset: bottomNavMessagesIconAsset,
                selectedIconAsset: bottomNavMessagesPressIconAsset,
                badgeCount: 4,
              ),
              GenesisBottomNavigationItem(
                label: 'Create',
                iconAsset: bottomNavCreateIconAsset,
                prominent: true,
              ),
            ],
          ),
        ),
      ),
    );

    final icons = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(icons, hasLength(3));
    expect(icons[0].width, 24);
    expect(icons[0].height, 24);
    expect(
      (icons[0].bytesLoader as SvgAssetLoader).assetName,
      bottomNavHomeIconAsset,
    );
    expect(
      (icons[1].bytesLoader as SvgAssetLoader).assetName,
      bottomNavMessagesPressIconAsset,
    );
    expect(icons[2].width, 22);
    expect(icons[2].height, 22);
    expect(
      (icons[2].bytesLoader as SvgAssetLoader).assetName,
      bottomNavCreateIconAsset,
    );

    final spacingBoxes = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(GenesisBottomNavigation),
            matching: find.byType(SizedBox),
          ),
        )
        .where((box) => box.width == null)
        .map((box) => box.height)
        .toList();
    expect(spacingBoxes.where((height) => height == 2), hasLength(2));
    expect(spacingBoxes.where((height) => height == 1), hasLength(1));

    final navSizedBoxes = tester.widgetList<SizedBox>(
      find.descendant(
        of: find.byType(GenesisBottomNavigation),
        matching: find.byType(SizedBox),
      ),
    );
    expect(navSizedBoxes.any((box) => box.height == 49), isTrue);

    final decoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GenesisBottomNavigation),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .singleWhere((decoration) => decoration.boxShadow != null);
    expect(decoration.color, GenesisPalette.redesignPaper);
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow!.single.offset.dy, lessThan(0));

    final badgePosition = tester.widget<Positioned>(
      find.ancestor(
        of: find.byKey(const ValueKey('bottom-nav-Messages-unread-badge')),
        matching: find.byType(Positioned),
      ),
    );
    expect(badgePosition.top, -1);
    expect(badgePosition.left, 19);
  });

  testWidgets('GenesisUnreadBadge has no platform text offset', (tester) async {
    Future<void> expectCenteredLabel(TargetPlatform platform) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(platform),
          theme: GenesisTheme.worldoLight().copyWith(platform: platform),
          home: const Scaffold(body: GenesisUnreadBadge(count: 4)),
        ),
      );
      final badge = find.byType(GenesisUnreadBadge);
      expect(
        find.descendant(of: badge, matching: find.byType(Transform)),
        findsNothing,
      );
      expect(
        tester.getCenter(find.text('4')).dy,
        closeTo(tester.getCenter(badge).dy, 0.01),
      );
    }

    await expectCenteredLabel(TargetPlatform.iOS);
    await expectCenteredLabel(TargetPlatform.android);
  });

  testWidgets('GenesisBottomNavigation can show an icon-only create action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        home: Scaffold(
          bottomNavigationBar: GenesisBottomNavigation(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              GenesisBottomNavigationItem(
                label: 'Create',
                icon: Icons.add_rounded,
                prominent: true,
                showLabel: false,
                iconSize: 26,
                iconShadows: [
                  Shadow(color: Colors.white, offset: Offset(0.5, 0)),
                  Shadow(color: Colors.white, offset: Offset(-0.5, 0)),
                  Shadow(color: Colors.white, offset: Offset(0, 0.5)),
                  Shadow(color: Colors.white, offset: Offset(0, -0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Create'), findsNothing);
    expect(find.byKey(const ValueKey('bottom-nav-Create')), findsOneWidget);

    final createIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
    expect(createIcon.size, 26);
    expect(createIcon.color, Colors.white);
    expect(createIcon.shadows, hasLength(4));

    final decoration = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byKey(const ValueKey('bottom-nav-Create')),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<ShapeDecoration>()
        .singleWhere(
          (decoration) =>
              decoration.color == GenesisPalette.redesignAccent &&
              decoration.shape ==
                  const ContinuousRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
        );
    expect(decoration.color, GenesisPalette.redesignAccent);

    final createSurface = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-nav-Create')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 42 &&
              widget.constraints?.maxHeight == 33,
        ),
      ),
    );
    expect(createSurface.constraints?.maxWidth, 42);
    expect(createSurface.constraints?.maxHeight, 33);
    expect(
      tester.getCenter(find.byWidget(createSurface)).dy,
      tester.getCenter(find.byKey(const ValueKey('bottom-nav-Create'))).dy,
    );
  });

  testWidgets('GenesisBottomNavigation keeps minimum bottom padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.zero),
          child: Scaffold(
            bottomNavigationBar: GenesisBottomNavigation(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                GenesisBottomNavigationItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(GenesisBottomNavigation),
        matching: find.byType(Padding),
      ),
    );
    expect(
      padding.padding,
      const EdgeInsets.only(bottom: GenesisBottomNavigation.minBottomPadding),
    );
  });

  testWidgets('GenesisBottomNavigation uses bottom system view padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.only(bottom: 30),
          ),
          child: Scaffold(
            bottomNavigationBar: GenesisBottomNavigation(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                GenesisBottomNavigationItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(GenesisBottomNavigation),
        matching: find.byType(Padding),
      ),
    );
    expect(padding.padding, const EdgeInsets.only(bottom: 30));
  });

  testWidgets('GenesisBottomSystemBarBoundary excludes three-button area', (
    tester,
  ) async {
    MediaQueryData? innerMediaQuery;
    const systemBarColor = Color(0xFFEDF3EF);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: systemBarColor),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(300, 600),
            padding: EdgeInsets.only(bottom: 48),
            viewPadding: EdgeInsets.only(bottom: 48),
            systemGestureInsets: EdgeInsets.only(bottom: 48),
          ),
          child: GenesisBottomSystemBarStyleScope(
            style: const GenesisBottomSystemBarStyle(color: systemBarColor),
            child: GenesisBottomSystemBarBoundary(
              child: Builder(
                builder: (context) {
                  innerMediaQuery = MediaQuery.of(context);
                  return const ColoredBox(
                    key: ValueKey('bounded-content'),
                    color: Colors.red,
                    child: SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('bounded-content'))).height,
      552,
    );
    expect(innerMediaQuery?.padding.bottom, 0);
    expect(innerMediaQuery?.viewPadding.bottom, 0);
    expect(innerMediaQuery?.systemGestureInsets.bottom, 0);
    expect(
      find.byKey(
        const ValueKey<String>('genesis-bottom-system-bar-opaque-overlay'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .any((box) => box.color == systemBarColor),
      isTrue,
    );
  });

  testWidgets('GenesisBottomSystemBarBoundary detects Samsung gesture mode', (
    tester,
  ) async {
    MediaQueryData? innerMediaQuery;
    const systemBarColor = Color(0xFFEDF3EF);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(300, 600),
            padding: EdgeInsets.only(bottom: 15),
            viewPadding: EdgeInsets.only(bottom: 15),
            systemGestureInsets: EdgeInsets.fromLTRB(30, 39, 30, 32),
          ),
          child: GenesisBottomSystemBarStyleScope(
            style: const GenesisBottomSystemBarStyle(color: systemBarColor),
            child: GenesisBottomSystemBarBoundary(
              child: Builder(
                builder: (context) {
                  innerMediaQuery = MediaQuery.of(context);
                  return const ColoredBox(
                    key: ValueKey('gesture-content'),
                    color: Colors.red,
                    child: SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('gesture-content'))).height,
      600,
    );
    expect(innerMediaQuery?.padding.bottom, 15);
    expect(innerMediaQuery?.viewPadding.bottom, 15);
    expect(innerMediaQuery?.systemGestureInsets.bottom, 32);
    expect(
      find.byKey(
        const ValueKey<String>('genesis-bottom-system-bar-opaque-overlay'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'GenesisBottomSystemBarBoundary defaults ambiguous values to gesture',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(300, 600),
              padding: EdgeInsets.only(bottom: 24),
              viewPadding: EdgeInsets.only(bottom: 24),
              systemGestureInsets: EdgeInsets.only(bottom: 24),
            ),
            child: GenesisBottomSystemBarBoundary(
              child: ColoredBox(
                key: ValueKey('ambiguous-content'),
                color: Colors.red,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('ambiguous-content'))).height,
        600,
      );
      expect(
        find.byKey(
          const ValueKey<String>('genesis-bottom-system-bar-opaque-overlay'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('GenesisTabBar renders labels inside a DefaultTabController', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(body: GenesisTabBar(labels: ['Latest', 'Popular'])),
        ),
      ),
    );

    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.unselectedLabelColor, GenesisPalette.redesignTextSecondary);
  });

  testWidgets('GenesisTabBar supports an explicit controller', (tester) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GenesisTabBar(
                controller: controller,
                labels: const ['Worldo', 'World'],
              ),
              Expanded(
                child: TabBarView(
                  controller: controller,
                  children: const [Text('Worldo list'), Text('World list')],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Worldo'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
  });

  testWidgets('GenesisTabBar can center scrollable tabs as a group', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: GenesisTabBar(
              labels: ['My Worlds', 'Popular'],
              tabAlignment: TabAlignment.center,
            ),
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.isScrollable, isTrue);
    expect(tabBar.tabAlignment, TabAlignment.center);
  });

  testWidgets('GenesisTabBar can remove vertical padding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Column(
              children: [
                GenesisTabBar(labels: ['Worldo', 'World'], verticalPadding: 0),
              ],
            ),
          ),
        ),
      ),
    );

    final element = tester.element(find.byType(GenesisTabBar));
    late Widget child;
    element.visitChildren((childElement) {
      child = childElement.widget;
    });

    final padding = child as Padding;
    expect(padding.padding, EdgeInsets.zero);
  });
}
