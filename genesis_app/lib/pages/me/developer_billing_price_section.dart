part of 'developer_page.dart';

@visibleForTesting
Widget developerBillingPriceSectionForTesting() =>
    const _DeveloperBillingPriceSection();

class _DeveloperBillingPriceSection extends StatefulWidget {
  const _DeveloperBillingPriceSection();

  @override
  State<_DeveloperBillingPriceSection> createState() =>
      _DeveloperBillingPriceSectionState();
}

class _DeveloperBillingPriceSectionState
    extends State<_DeveloperBillingPriceSection> {
  String _storefrontCountry = 'Loading...';
  String _storefrontId = 'Loading...';
  String? _storefrontError;
  AppVersionInfo? _buildVersion;
  bool _readingStorefront = false;
  late List<BillingPriceCapture> _captures;
  late List<StorePriceQueryCapture> _rawQueries;

  @override
  void initState() {
    super.initState();
    _captures = billingPriceDiagnostics.captures;
    _rawQueries = storePriceQueryDiagnostics.captures;
    unawaited(_refreshStorefront());
  }

  Future<void> _refreshStorefront() async {
    if (_readingStorefront) return;
    setState(() => _readingStorefront = true);
    String country = 'N/A';
    String storefrontId = 'N/A';
    String? error;
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      try {
        final data = await GenesisMethodChannels.device
            .invokeMapMethod<String, String>(
              GenesisMethodChannels.getStorefrontDiagnostics,
            )
            .timeout(const Duration(seconds: 10));
        country = data?['country_code']?.trim().isNotEmpty == true
            ? data!['country_code']!
            : '(unavailable)';
        storefrontId = data?['storefront_id']?.trim().isNotEmpty == true
            ? data!['storefront_id']!
            : '(unavailable)';
      } catch (exception) {
        country = '(query failed)';
        storefrontId = '(query failed)';
        error = '${exception.runtimeType}: $exception';
      }
    }
    final version = await AppMetadataService.buildAppVersion();
    if (!mounted) return;
    setState(() {
      _storefrontCountry = country;
      _storefrontId = storefrontId;
      _storefrontError = error;
      _buildVersion = version;
      _readingStorefront = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final captures = _captures;
    return _DeveloperTestSectionPanel(
      key: const ValueKey<String>('developer-billing-price-panel'),
      child: ExpansionTile(
        key: const PageStorageKey<String>('developer-billing-price-expanded'),
        initiallyExpanded: true,
        onExpansionChanged: (expanded) {
          if (!expanded) return;
          setState(() {
            _captures = billingPriceDiagnostics.captures;
            _rawQueries = storePriceQueryDiagnostics.captures;
          });
        },
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: GenesisColors.darkTextPrimary,
        collapsedIconColor: GenesisColors.darkTextPrimary,
        title: const _DeveloperSectionTitle('Price diagnostics'),
        children: [
          _DeveloperInfoRow(
            title: 'Build',
            content: _buildVersion?.displayVersion ?? 'Loading...',
          ),
          _DeveloperInfoRow(
            title: 'App locale',
            content: Localizations.localeOf(context).toLanguageTag(),
          ),
          _DeveloperInfoRow(
            title: 'System locale',
            content: WidgetsBinding.instance.platformDispatcher.locale
                .toLanguageTag(),
          ),
          _DeveloperInfoRow(title: 'Storefront', content: _storefrontCountry),
          _DeveloperInfoRow(title: 'Storefront ID', content: _storefrontId),
          if (_storefrontError != null)
            _DeveloperInfoRow(title: 'Store error', content: _storefrontError!),
          const SizedBox(height: 8),
          const Text(
            'Open Buy Gems and Subscription in this build, then return here. These are the last prices actually applied by each page.',
            style: TextStyle(
              fontSize: 12,
              color: GenesisColors.darkTextSecondary,
            ),
          ),
          if (captures.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('No purchase page prices captured yet.'),
          ],
          for (final group in const ['Gems', 'Subscription']) ...[
            const Divider(color: GenesisColors.darkFaintFill),
            Align(
              alignment: Alignment.centerLeft,
              child: _DeveloperSectionTitle(group),
            ),
            ..._productGroups(group),
          ],
        ],
      ),
    );
  }

  List<Widget> _productGroups(String group) {
    final queries = _rawQueries.where((query) => query.group == group).toList();
    final captures = _captures
        .where(
          (capture) => group == 'Subscription'
              ? capture.surface == 'Subscription'
              : capture.surface == 'Gems wallet' ||
                    capture.surface == 'Buy Gems sheet',
        )
        .toList();
    final ids = <String>{
      for (final capture in captures)
        for (final line in capture.lines)
          if (group == 'Subscription'
              ? line.productKey == 'pro_yearly'
              : line.gemsCent == 50000)
            line.storeProductId,
    };
    final services = AppServicesScope.maybeRead(context);
    if (group == 'Gems') {
      for (final product
          in services?.gemStoreCatalog.cached ?? const <GemProduct>[]) {
        if (product.totalGemsCent == 50000) {
          ids.add(
            defaultTargetPlatform == TargetPlatform.iOS
                ? product.appleProductId
                : product.googleProductId,
          );
        }
      }
    } else {
      for (final offer
          in services?.membershipCatalog.cached?.offers ??
              const <MembershipOffer>[]) {
        if (offer.product.planCode == 'pro_yearly')
          ids.add(offer.product.storeProductId);
      }
    }
    return [
      for (final id in ids.where((id) => id.isNotEmpty)) ...[
        const Divider(color: GenesisColors.darkFaintFill),
        Align(
          alignment: Alignment.centerLeft,
          child: _DeveloperSectionTitle(id),
        ),
        for (final query
            in queries
                .where((query) => query.requestedIds.contains(id))
                .take(1)) ...[
          _priceDataBlock('Store', _rawQueryReport(query, productId: id)),
        ],
        for (final surface
            in (group == 'Subscription'
                ? const ['Subscription']
                : const ['Gems wallet', 'Buy Gems sheet']))
          for (final capture
              in captures
                  .where(
                    (capture) =>
                        capture.surface == surface &&
                        capture.lines.any((line) => line.storeProductId == id),
                  )
                  .take(1)) ...[
            _priceDataBlock('Page', _reportCapture(capture, productId: id)),
          ],
        if (!captures.any(
          (capture) =>
              capture.surface ==
                  (group == 'Subscription' ? 'Subscription' : 'Gems wallet') &&
              capture.lines.any((line) => line.storeProductId == id),
        )) ...[
          _priceDataBlock('Page', 'No page display captured for this product.'),
        ],
      ],
    ];
  }

  Widget _priceDataBlock(String title, String content) => Padding(
    padding: EdgeInsets.only(
      top: title == 'Store' ? 12 : 6,
      bottom: title == 'Store' ? 0 : 12,
    ),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _DeveloperSectionTitle(title),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 12,
              color: GenesisColors.darkTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );

  String _reportCapture(BillingPriceCapture capture, {String? productId}) {
    final buffer = StringBuffer()
      ..writeln(
        'Applied: ${capture.capturedAt.toLocal()} | ${capture.snapshotSource}',
      );
    for (final line in capture.lines.where(
      (line) =>
          (productId == null || line.storeProductId == productId) &&
          (capture.surface != 'Subscription' ||
              line.productKey == 'pro_yearly'),
    )) {
      buffer
        ..writeln(
          'Backend: ${line.backendAmount} ${line.backendCurrency} (minor units)',
        )
        ..writeln(
          'Store quote: ${line.storeFormatted ?? '(missing)'} [${line.storeCurrency ?? '(missing)'}]',
        )
        ..writeln('Shown: ${line.displayText} ← ${line.displaySource}');
    }
    if (capture.error != null) buffer.writeln('Error: ${capture.error}');
    return buffer.toString().trimRight();
  }

  String _rawQueryReport(StorePriceQueryCapture query, {String? productId}) {
    final buffer = StringBuffer()
      ..writeln('Queried: ${query.queriedAt.toLocal()}')
      ..writeln('Status: ${query.status}');
    final products = query.returned.where(
      (product) => productId == null || product.id == productId,
    );
    for (final product in products) {
      buffer.writeln(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(product.sdkFields['StoreKit2'] ?? product.sdkFields),
      );
    }
    if (products.isEmpty) buffer.writeln('No product returned');
    if (productId != null && query.notFoundIds.contains(productId))
      buffer.writeln('Not found: $productId');
    return buffer.toString().trimRight();
  }
}
