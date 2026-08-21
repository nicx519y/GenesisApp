part of 'developer_page.dart';

class _DeveloperTestSectionPanel extends StatelessWidget {
  const _DeveloperTestSectionPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GenesisSurface(
      variant: GenesisSurfaceVariant.raised,
      padding: const EdgeInsets.all(14),
      border: Border.all(color: context.genesisColors.borderNeutral),
      borderRadius: const BorderRadius.all(GenesisRadii.lg),
      child: child,
    );
  }
}

class _DeveloperKeepAliveTab extends StatefulWidget {
  const _DeveloperKeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_DeveloperKeepAliveTab> createState() => _DeveloperKeepAliveTabState();
}

class _DeveloperKeepAliveTabState extends State<_DeveloperKeepAliveTab>
    with AutomaticKeepAliveClientMixin<_DeveloperKeepAliveTab> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _DeveloperThemeModeSelector extends StatelessWidget {
  const _DeveloperThemeModeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onOpenDesignSystemGallery,
  });

  final ThemeMode value;
  final bool enabled;
  final ValueChanged<ThemeMode> onChanged;
  final VoidCallback onOpenDesignSystemGallery;

  @override
  Widget build(BuildContext context) {
    return _DeveloperTestSectionPanel(
      key: const ValueKey<String>('developer-theme-mode-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DeveloperSectionTitle('Appearance'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: SegmentedButton<ThemeMode>(
              key: const ValueKey<String>('developer-theme-mode-selector'),
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Tooltip(
                    message: 'Follow system',
                    child: Text('System'),
                  ),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Tooltip(message: 'Light theme', child: Text('Light')),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Tooltip(message: 'Dark theme', child: Text('Dark')),
                ),
              ],
              selected: <ThemeMode>{value},
              showSelectedIcon: false,
              onSelectionChanged: enabled
                  ? (selection) => onChanged(selection.single)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.genesisColors.divider),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey<String>(
                'developer-design-system-gallery-button',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.genesisColors.textPrimary,
                side: BorderSide(color: context.genesisColors.textPrimary),
              ),
              onPressed: onOpenDesignSystemGallery,
              child: const Text('Design System Gallery'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperTelemetryUploadPanel extends StatelessWidget {
  const _DeveloperTelemetryUploadPanel({
    required this.state,
    required this.savingChannels,
    required this.onChanged,
  });

  final TelemetryUploadState state;
  final Set<TelemetryChannel> savingChannels;
  final void Function(TelemetryChannel channel, bool enabled) onChanged;

  @override
  Widget build(BuildContext context) {
    return _DeveloperTestSectionPanel(
      key: const ValueKey<String>('developer-telemetry-upload-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Telemetry Debug Upload',
            style: TextStyle(
              fontSize: 15,
              color: context.genesisColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enable individual telemetry channels for debugging.',
            style: TextStyle(
              fontSize: 12,
              color: context.genesisColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _telemetryStatusLabel(state),
            key: const ValueKey<String>('developer-telemetry-status'),
            style: TextStyle(
              fontSize: 12,
              color: context.genesisColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.genesisColors.divider),
          _DeveloperTelemetryChannelSwitch(
            label: 'Collect',
            value: state.debugOverrides.collect,
            enabled: !savingChannels.contains(TelemetryChannel.collect),
            switchKey: const ValueKey<String>(
              'developer-telemetry-collect-switch',
            ),
            onChanged: (value) => onChanged(TelemetryChannel.collect, value),
          ),
          _DeveloperTelemetryChannelSwitch(
            label: 'Firebase Analytics',
            value: state.debugOverrides.analytics,
            enabled: !savingChannels.contains(TelemetryChannel.analytics),
            switchKey: const ValueKey<String>(
              'developer-telemetry-analytics-switch',
            ),
            onChanged: (value) => onChanged(TelemetryChannel.analytics, value),
          ),
          _DeveloperTelemetryChannelSwitch(
            label: 'Firebase Performance',
            value: state.debugOverrides.performance,
            enabled: !savingChannels.contains(TelemetryChannel.performance),
            switchKey: const ValueKey<String>(
              'developer-telemetry-performance-switch',
            ),
            onChanged: (value) =>
                onChanged(TelemetryChannel.performance, value),
          ),
          _DeveloperTelemetryChannelSwitch(
            label: 'Firebase Crashlytics',
            value: state.debugOverrides.crashlytics,
            enabled: !savingChannels.contains(TelemetryChannel.crashlytics),
            switchKey: const ValueKey<String>(
              'developer-telemetry-crashlytics-switch',
            ),
            showDivider: false,
            onChanged: (value) =>
                onChanged(TelemetryChannel.crashlytics, value),
          ),
        ],
      ),
    );
  }
}

class _DeveloperTelemetryChannelSwitch extends StatelessWidget {
  const _DeveloperTelemetryChannelSwitch({
    required this.label,
    required this.value,
    required this.enabled,
    required this.switchKey,
    required this.onChanged,
    this.showDivider = true,
  });

  final String label;
  final bool value;
  final bool enabled;
  final Key switchKey;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.genesisColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 32,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: _DeveloperSwitch(
                    switchKey: switchKey,
                    value: value,
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: context.genesisColors.dividerSubtle),
      ],
    );
  }
}

class _DeveloperToggleRow extends StatelessWidget {
  const _DeveloperToggleRow({
    required this.sectionTitle,
    required this.label,
    required this.value,
    required this.enabled,
    required this.switchKey,
    required this.onChanged,
  });

  final String sectionTitle;
  final String label;
  final bool value;
  final bool enabled;
  final Key switchKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DeveloperSectionTitle(sectionTitle),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.genesisColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          height: 32,
          child: FittedBox(
            fit: BoxFit.contain,
            child: _DeveloperSwitch(
              switchKey: switchKey,
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeveloperSwitch extends StatelessWidget {
  const _DeveloperSwitch({
    required this.switchKey,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return Switch(
      key: switchKey,
      value: value,
      onChanged: onChanged,
      inactiveThumbColor: colors.switchInactiveThumb,
      inactiveTrackColor: colors.controlMuted,
    );
  }
}

class _DeveloperSliderControl extends StatelessWidget {
  const _DeveloperSliderControl({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.sliderKey,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Key sliderKey;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: context.genesisColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 13,
                color: context.genesisColors.textSecondary,
              ),
            ),
          ],
        ),
        Slider(
          key: sliderKey,
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}

class _DeveloperGemPurchasePreview {
  _DeveloperGemPurchasePreview()
    : walletStore = GemWalletStore(
        loadWallet: () async => const GemWallet(balance: 12),
        readUid: () async => 'developer_preview_user',
      );

  final GemWalletStore walletStore;
  final _DeveloperPreviewBillingService billing =
      _DeveloperPreviewBillingService();

  List<GemProduct> get products => const <GemProduct>[
    GemProduct(
      productId: 'gem_pack_500',
      appleProductId: 'worldo.gems.500',
      googleProductId: 'worldo.gems.500',
      baseGems: 500,
      bonusGems: 0,
      priceCurrencyCode: 'USD',
      priceAmount: 149,
      canPurchase: true,
      activityType: 'new_user',
      activityText: 'New User',
      activityColor: '#E85C39',
    ),
    GemProduct(
      productId: 'gem_pack_1100',
      appleProductId: 'worldo.gems.1100',
      googleProductId: 'worldo.gems.1100',
      baseGems: 1000,
      bonusGems: 100,
      priceCurrencyCode: 'USD',
      priceAmount: 590,
      canPurchase: true,
      activityType: 'first_top_up',
      activityText: 'First Top-up',
      activityColor: '#B53B52',
    ),
    GemProduct(
      productId: 'gem_pack_4400',
      appleProductId: 'worldo.gems.4400',
      googleProductId: 'worldo.gems.4400',
      baseGems: 4000,
      bonusGems: 400,
      priceCurrencyCode: 'USD',
      priceAmount: 1990,
      canPurchase: true,
      activityType: 'first_top_up',
      activityText: 'First Top-up',
      activityColor: '#B53B52',
    ),
    GemProduct(
      productId: 'gem_pack_8800',
      appleProductId: 'worldo.gems.8800',
      googleProductId: 'worldo.gems.8800',
      baseGems: 8000,
      bonusGems: 800,
      priceCurrencyCode: 'USD',
      priceAmount: 3890,
      canPurchase: true,
      activityType: 'first_top_up',
      activityText: 'First Top-up',
      activityColor: '#B53B52',
    ),
    GemProduct(
      productId: 'gem_pack_16500',
      appleProductId: 'worldo.gems.16500',
      googleProductId: 'worldo.gems.16500',
      baseGems: 15000,
      bonusGems: 1500,
      priceCurrencyCode: 'USD',
      priceAmount: 6990,
      canPurchase: true,
      activityType: 'first_top_up',
      activityText: 'First Top-up',
      activityColor: '#B53B52',
    ),
    GemProduct(
      productId: 'gem_pack_55000',
      appleProductId: 'worldo.gems.55000',
      googleProductId: 'worldo.gems.55000',
      baseGems: 50000,
      bonusGems: 5000,
      priceCurrencyCode: 'USD',
      priceAmount: 19990,
      canPurchase: true,
      activityType: 'first_top_up',
      activityText: 'First Top-up',
      activityColor: '#B53B52',
    ),
  ];

  void dispose() {
    walletStore.dispose();
    billing.dispose();
  }
}

class _DeveloperPreviewBillingService implements BillingService {
  final ValueNotifier<BillingState> _state = ValueNotifier<BillingState>(
    BillingState(storeAvailable: true),
  );
  final StreamController<BillingUiEvent> _events =
      StreamController<BillingUiEvent>.broadcast();
  bool _disposed = false;

  @override
  Stream<BillingUiEvent> get events => _events.stream;

  @override
  ValueListenable<BillingState> get state => _state;

  @override
  Future<void> start() async {}

  @override
  Future<void> purchaseGem(
    GemProduct product, {
    BillingPurchaseSource source = BillingPurchaseSource.buyGemsPage,
    String payTrackId = '',
  }) async {
    if (_disposed) return;
    if (_state.value.hasBusyPurchase) return;
    _state.value = BillingState(
      storeAvailable: true,
      busyProductIds: <String>{product.productId},
    );
    _events.add(
      BillingUiEvent(
        kind: BillingUiEventKind.processing,
        productId: product.productId,
        attemptId: 'developer_preview',
        message: 'Purchasing Gems',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_disposed) return;
    _state.value = BillingState(storeAvailable: true);
    _events.add(
      BillingUiEvent(
        kind: BillingUiEventKind.success,
        productId: product.productId,
        attemptId: 'developer_preview',
        message: 'Purchase successful!',
        grantedGems: product.totalGems,
      ),
    );
  }

  @override
  Future<void> recover(BillingRecoverySource source) async {}

  @override
  Future<bool> recoverStorePurchases({
    List<GemProduct>? productCatalog,
  }) async => true;

  @override
  void resetForSession() {}

  @override
  void dispose() {
    _disposed = true;
    _state.dispose();
    _events.close();
  }
}

class _DeveloperAccountIdentity {
  const _DeveloperAccountIdentity({required this.uid, required this.uuid});

  final String uid;
  final String uuid;
}

class _DeveloperSectionTitle extends StatelessWidget {
  const _DeveloperSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: context.genesisColors.textPrimary,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }
}

class _DeveloperVersionField extends StatelessWidget {
  const _DeveloperVersionField({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    this.digitsOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
      inputFormatters: digitsOnly
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      textInputAction: TextInputAction.done,
      style: TextStyle(fontSize: 14, color: context.genesisColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _DeveloperEndpointHeader extends StatelessWidget {
  const _DeveloperEndpointHeader({
    required this.isTestEnvironment,
    required this.enabled,
    required this.onPressed,
  });

  final bool isTestEnvironment;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final actionText = isTestEnvironment
        ? 'Switch to production'
        : 'Switch to test';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: _DeveloperSectionTitle('Endpoint overrides')),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                actionText,
                textAlign: TextAlign.right,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled
                      ? context.genesisColors.textPrimary
                      : context.genesisColors.textDisabled,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeveloperEndpointField extends StatelessWidget {
  const _DeveloperEndpointField({
    super.key,
    required this.label,
    required this.scheme,
    required this.hintText,
    required this.controller,
  });

  final String label;
  final String scheme;
  final String hintText;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final host = controller.text.trim().isEmpty
        ? hintText
        : controller.text.trim();
    final displayText = '$scheme$host';
    return _DeveloperInfoSingleLineRow(title: label, content: displayText);
  }
}

class _DeveloperInfoSingleLineRow extends StatelessWidget {
  const _DeveloperInfoSingleLineRow({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  static const double _titleWidth = 104;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _titleWidth,
          child: Text(
            '$title:',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: context.genesisColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _copyContent(context),
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                content,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 14,
                  color: context.genesisColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyContent(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    showGenesisToast(context, 'Copied');
  }
}

class _DeveloperInfoRow extends StatelessWidget {
  const _DeveloperInfoRow({required this.title, required this.content});

  final String title;
  final String content;

  static const double _titleWidth = 104;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _titleWidth,
          child: Text(
            '$title:',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              color: context.genesisColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _copyContent(context),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: context.genesisColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyContent(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    showGenesisToast(context, 'Copied');
  }
}

class _DeveloperInfoBlock extends StatelessWidget {
  const _DeveloperInfoBlock({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _copyContent(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title:',
            style: TextStyle(
              fontSize: 14,
              color: context.genesisColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: context.genesisColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyContent(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    showGenesisToast(context, 'Copied');
  }
}
