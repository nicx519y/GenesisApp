import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../network/models/gem_product.dart';
import '../../platform/billing/billing_models.dart';
import '../../ui/components/genesis_page_title.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import 'gem_assets.dart';
import 'gem_colors.dart';

const double kGemProductCardHeight = 126;
const double kGemPriceButtonHeight = 28;

/// Layout box the gem-stack artwork occupies on a product card. The artwork
/// is fitted inside it, so the painted width can be narrower than [Size.width].
const Size kGemProductIconSize = Size(42, 34);

class GemPurchaseCatalogSection extends StatelessWidget {
  const GemPurchaseCatalogSection({
    super.key,
    required this.balance,
    required this.catalog,
    this.balanceKey = const ValueKey<String>('gem-wallet-balance'),
  });

  final int balance;
  final Key balanceKey;
  final Widget catalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GemBalancePanel(balance: balance, balanceKey: balanceKey),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Packs',
              style: GenesisTypography.sectionTitle.copyWith(
                color: context.genesisColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Struck price = first top-up bonus',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w400,
                  color: context.genesisColors.textPlaceholder,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        catalog,
      ],
    );
  }
}

class GemBalancePanel extends StatelessWidget {
  const GemBalancePanel({
    super.key,
    required this.balance,
    this.balanceKey = const ValueKey<String>('gem-wallet-balance'),
  });

  final int balance;
  final Key balanceKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('gem-balance-panel'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My balance',
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
              color: context.genesisColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SvgPicture.asset(
                gemIconAsset,
                key: const ValueKey('gem-balance-icon'),
                width: 20,
                height: 31,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              GenesisMetricValueText(
                value: formatGemInteger(balance),
                textKey: balanceKey,
                size: GenesisMetricValueSize.prominent,
                style: TextStyle(color: context.genesisColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Gems',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: context.genesisColors.textPlaceholder,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GemProductGrid extends StatelessWidget {
  const GemProductGrid({
    super.key,
    required this.products,
    required this.billingStateListenable,
    required this.onPurchase,
  });

  final List<GemProduct> products;
  final ValueListenable<BillingState> billingStateListenable;
  final ValueChanged<GemProduct> onPurchase;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BillingState>(
      valueListenable: billingStateListenable,
      builder: (context, billingState, _) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: kGemProductCardHeight,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          return GemProductCard(
            product: product,
            isBuying: billingState.isBusy(product.productId),
            isPurchaseInProgress: billingState.hasBusyPurchase,
            onPurchase: () => onPurchase(product),
          );
        },
      ),
    );
  }
}

class GemProductCard extends StatelessWidget {
  const GemProductCard({
    super.key,
    required this.product,
    required this.isBuying,
    required this.isPurchaseInProgress,
    required this.onPurchase,
  });

  final GemProduct product;
  final bool isBuying;
  final bool isPurchaseInProgress;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final isNewUserProduct = product.productId.trim() == 'gem_pack_500';
    final isSoldOut = isNewUserProduct && !product.canPurchase;
    final enabled = product.canPurchase && !isPurchaseInProgress;
    final hasBonusGems = product.bonusGems > 0;
    final tag = product.tagText;
    final normalizedTag = tag.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final usesStandardPromotionTagWidth =
        normalizedTag == 'new user' ||
        normalizedTag == 'first top-up' ||
        normalizedTag == 'first top up';
    final defaultTagColor = isNewUserProduct
        ? context.genesisGemColors.priceGradientStart
        : context.genesisGemColors.priceGradientEnd;
    final tagColor = _parseActivityColor(
      product.activityColor,
      fallback: defaultTagColor,
    );
    final card = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 13),
          decoration: BoxDecoration(
            // 9p: the sold-out card drops to white 4%, one step under the
            // white 7% live card.
            color: isSoldOut
                ? context.genesisColors.foregroundStrong.withValues(alpha: 0.04)
                : context.genesisColors.inputBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              SvgPicture.asset(
                gemStackIconAsset,
                key: ValueKey<String>('gem-product-icon-${product.productId}'),
                width: kGemProductIconSize.width,
                height: kGemProductIconSize.height,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '+${formatGemInteger(product.totalGems)}',
                        key: ValueKey<String>(
                          'gem-product-amount-${product.productId}',
                        ),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: context.genesisColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    hasBonusGems ? formatGemInteger(product.baseGems) : 'Gems',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: hasBonusGems
                          ? context.genesisColors.textDisabled
                          : context.genesisColors.textPlaceholder,
                      decoration: hasBonusGems
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: context.genesisColors.textDisabled,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                key: ValueKey<String>('gem-product-price-${product.productId}'),
                width: double.infinity,
                height: kGemPriceButtonHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSoldOut
                      ? context.genesisColors.surfaceSubtle
                      : context.genesisGemColors.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: isBuying && !isSoldOut
                    ? SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: context.genesisColors.onDanger,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isSoldOut
                              ? 'Sold out'
                              : formatGemPrice(
                                  product.priceAmount,
                                  product.priceCurrencyCode,
                                ),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: isSoldOut
                                ? context.genesisColors.textDisabled
                                : context.genesisColors.textHighEmphasis,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (tag.isNotEmpty)
          Positioned(
            left: -1,
            top: -1,
            child: Container(
              key: ValueKey<String>('gem-product-tag-${product.productId}'),
              width: usesStandardPromotionTagWidth ? 68 : null,
              height: usesStandardPromotionTagWidth ? 20 : null,
              constraints: const BoxConstraints(maxWidth: 86),
              padding: usesStandardPromotionTagWidth
                  ? null
                  : const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              alignment: usesStandardPromotionTagWidth
                  ? Alignment.center
                  : null,
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 14 / 10,
                  fontWeight: FontWeight.w400,
                  color: context.genesisColors.onDanger,
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: isSoldOut
          ? 'Sold out ${product.productId}'
          : 'Buy ${product.productId}',
      child: GestureDetector(
        key: ValueKey<String>('gem-product-${product.productId}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPurchase : null,
        child: Opacity(
          opacity: isSoldOut ? 0.4 : (product.canPurchase ? 1 : 0.45),
          child: _UnavailableProductFilter(
            unavailable: !product.canPurchase && !isSoldOut,
            child: card,
          ),
        ),
      ),
    );
  }
}

class _UnavailableProductFilter extends StatelessWidget {
  const _UnavailableProductFilter({
    required this.unavailable,
    required this.child,
  });

  final bool unavailable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!unavailable) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
      child: child,
    );
  }
}

String formatGemInteger(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String formatGemPrice(int cents, String currencyCode) {
  final amount = cents / 100;
  var text = amount.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  final cleanCurrencyCode = currencyCode.trim().toUpperCase();
  final currencyLabel = cleanCurrencyCode == 'USD' ? r'$' : cleanCurrencyCode;
  return '$currencyLabel$text';
}

Color _parseActivityColor(String value, {required Color fallback}) {
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) return fallback;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return fallback;
  if (normalized.length == 6) return Color(0xFF000000 | parsed);
  return Color(parsed);
}
