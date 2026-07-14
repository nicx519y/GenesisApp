import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../network/models/gem_product.dart';
import '../../platform/billing/billing_models.dart';

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
    return Container(
      width: double.infinity,
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/custom-icons/svg/ruby.svg',
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'My Balance',
                    style: TextStyle(
                      fontSize: 12,
                      height: 18 / 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                formatGemInteger(balance),
                key: balanceKey,
                style: const TextStyle(
                  fontSize: 34,
                  height: 40 / 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
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
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 105 / 142,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          return GemProductCard(
            product: product,
            index: index,
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
    required this.index,
    required this.isBuying,
    required this.isPurchaseInProgress,
    required this.onPurchase,
  });

  final GemProduct product;
  final int index;
  final bool isBuying;
  final bool isPurchaseInProgress;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final tag = product.tagText.isNotEmpty
        ? product.tagText
        : index == 0
        ? 'New user'
        : '';
    const tagTextStyle = TextStyle(
      fontSize: 10,
      height: 1,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    final tagPainter = TextPainter(
      text: TextSpan(text: tag, style: tagTextStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final tagWidth = (tagPainter.width + 8).clamp(46.0, 86.0).toDouble();
    final enabled = product.canPurchase && !isPurchaseInProgress;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Buy ${product.productId}',
      child: GestureDetector(
        key: ValueKey<String>('gem-product-${product.productId}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPurchase : null,
        child: Opacity(
          opacity: product.canPurchase ? 1 : 0.45,
          child: Container(
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEBEBEB)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (tag.isNotEmpty)
                  Positioned(
                    left: -1,
                    top: -1,
                    child: SizedBox(
                      width: tagWidth,
                      height: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B6192),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(tag, maxLines: 1, style: tagTextStyle),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/custom-icons/svg/ruby.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  left: 8,
                  right: 8,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '+${formatGemInteger(product.baseGems)}',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 20 / 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ),
                if (product.bonusGems > 0)
                  Positioned(
                    top: 84,
                    left: 8,
                    right: 8,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '+${formatGemInteger(product.bonusGems)} Bonus',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 14 / 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF42C47),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  height: 24,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF42C47),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: isBuying
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white,
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatGemPrice(
                                product.priceAmount,
                                product.priceCurrencyCode,
                              ),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 14 / 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  final sign = switch (currencyCode.toUpperCase()) {
    'USD' => r'$',
    'HKD' => r'HK$',
    'TWD' => r'NT$',
    'CNY' => r'¥',
    'JPY' => r'¥',
    'KRW' => r'₩',
    'EUR' => r'€',
    'GBP' => r'£',
    _ => '${currencyCode.toUpperCase()} ',
  };
  final amount = cents / 100;
  var text = amount.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return '$sign$text';
}
