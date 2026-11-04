import 'package:flutter/material.dart';

import '../../l10n/genesis_localizations.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../page_header.dart';
import 'memory_membership_carousel.dart';
import 'memory_membership_style.dart';

/// Explicit Developer gallery. No account lookup, catalog load or checkout.
class MemoryMembershipPreviewPage extends StatefulWidget {
  const MemoryMembershipPreviewPage({
    super.key,
    this.premiumActive = false,
    this.deluxeActive = false,
    this.initialTier,
  });
  final bool premiumActive;
  final bool deluxeActive;
  final MemoryMembershipTier? initialTier;

  @override
  State<MemoryMembershipPreviewPage> createState() =>
      _MemoryMembershipPreviewPageState();
}

class _MemoryMembershipPreviewPageState
    extends State<MemoryMembershipPreviewPage> {
  bool _profile = false;
  late MemoryMembershipTier? _tier = widget.initialTier;

  void _showSubscription(MemoryMembershipTier tier) => setState(() {
    _tier = tier;
    _profile = false;
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GenesisColors.darkBackground,
    appBar: GenesisBackAppBar(
      pageName: _profile
          ? context.l10n.navMe
          : context.l10n.premiumSubscription,
      actions: [
        IconButton(
          tooltip: _profile
              ? context.l10n.premiumSubscription
              : context.l10n.navMe,
          onPressed: () => setState(() => _profile = !_profile),
          icon: Icon(_profile ? Icons.credit_card : Icons.person_outline),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              context.l10n.memoryMembershipDraftPreview,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: GenesisColors.darkTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: _profile
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: MemoryMembershipProfileCarousel(
                      premiumActive: widget.premiumActive,
                      deluxeActive: widget.deluxeActive,
                      premiumExpiry: widget.premiumActive
                          ? DateTime(2027, 9, 7)
                          : null,
                      deluxeExpiry: widget.deluxeActive
                          ? DateTime(2027, 11, 3)
                          : null,
                      onPremiumSubscribe: () =>
                          _showSubscription(MemoryMembershipTier.premium),
                      onDeluxeSubscribe: () =>
                          _showSubscription(MemoryMembershipTier.deluxe),
                    ),
                  )
                : MemoryMembershipSubscriptionCarousel(
                    premiumActive: widget.premiumActive,
                    deluxeActive: widget.deluxeActive,
                    premiumExpiry: widget.premiumActive
                        ? DateTime(2027, 9, 7)
                        : null,
                    deluxeExpiry: widget.deluxeActive
                        ? DateTime(2027, 11, 3)
                        : null,
                    initialTier: _tier,
                    onPremiumSubscribe: () {},
                    onDeluxeSubscribe: () {},
                  ),
          ),
        ],
      ),
    ),
  );
}
