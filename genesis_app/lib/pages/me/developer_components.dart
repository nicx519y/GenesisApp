part of 'developer_page.dart';

class _DeveloperEmptyTab extends StatelessWidget {
  const _DeveloperEmptyTab({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$title monitoring is not enabled yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
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
            child: Switch(
              key: switchKey,
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
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
      style: const TextStyle(
        fontSize: 15,
        color: Colors.black,
        fontWeight: FontWeight.w600,
        height: 1.2,
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
                  color: enabled ? Colors.black : const Color(0xFFA8A8AD),
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
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
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
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
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
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
