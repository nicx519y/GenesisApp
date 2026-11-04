import 'package:flutter/material.dart';
import '../../l10n/genesis_localizations.dart';
import 'memory_membership_style.dart';

/// Shared lock card. The host owns navigation and checkout availability.
class MemoryMembershipOfferCard extends StatefulWidget {
  const MemoryMembershipOfferCard({
    super.key,
    required this.tier,
    required this.onSubscribe,
    required this.onDetails,
    this.onPlanSubscribe,
    this.yearlyPrice,
    this.monthlyPrice,
  });
  final MemoryMembershipTier tier;
  final VoidCallback onSubscribe;
  final VoidCallback onDetails;

  /// Only retain a selected plan when the host can carry the choice onward.
  /// Without this callback, either plan opens details through [onDetails].
  final ValueChanged<bool>? onPlanSubscribe;
  final String? yearlyPrice;
  final String? monthlyPrice;

  @override
  State<MemoryMembershipOfferCard> createState() =>
      _MemoryMembershipOfferCardState();
}

class _MemoryMembershipOfferCardState extends State<MemoryMembershipOfferCard> {
  final _yearly = {for (final tier in MemoryMembershipTier.values) tier: true};

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    return MemoryMembershipSurface(
      tier: tier,
      kind: MemoryMembershipSurfaceKind.offer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: MemoryMembershipHeading(tier: tier, fontSize: 17),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    key: ValueKey('membership-details-${tier.name}'),
                    tooltip: context.l10n.memoryMembershipDetails(
                      membership: tier.title(context),
                    ),
                    onPressed: widget.onDetails,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x1AFFFFFF),
                    ),
                    icon: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: tier.bodyColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MemoryMembershipOfferText(
              tier.offer(context),
              gem: true,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: tier.bodyColor,
              ),
              figureStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            MemoryMembershipPlanSelector(
              tier: tier,
              offer: true,
              yearly: _yearly[tier]!,
              yearlyPrice: widget.yearlyPrice,
              monthlyPrice: widget.monthlyPrice,
              onChanged: (value) => setState(() => _yearly[tier] = value),
            ),
            const SizedBox(height: 14),
            MemoryMembershipButton(
              key: ValueKey('membership-subscribe-${tier.name}'),
              tier: tier,
              onPressed: () {
                final subscribe = widget.onPlanSubscribe;
                if (subscribe != null) {
                  subscribe(_yearly[tier]!);
                } else {
                  widget.onSubscribe();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
