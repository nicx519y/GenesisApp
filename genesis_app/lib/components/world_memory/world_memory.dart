import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/genesis_localizations.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/theme/genesis_theme.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../utils/genesis_display_text.dart';
import '../gems/memory_membership_offer_card.dart';
import '../gems/memory_membership_style.dart';
import '../common/genesis_center_toast.dart';
import 'world_memory_models.dart';
import 'world_memory_tick_tile.dart';

export 'world_memory_models.dart';

part 'world_memory_common.dart';
part 'world_memory_recap.dart';
part 'world_memory_cast.dart';
part 'world_memory_bonds.dart';

/// Shared content for World sheets and MiniPhone. Hosts own navigation, data,
/// entitlement loading, and purchasing. No example data is imported here.
class WorldMemoryView extends StatefulWidget {
  const WorldMemoryView({
    super.key,
    required this.section,
    required this.snapshot,
    required this.premiumActive,
    required this.deluxeActive,
    required this.onSubscribe,
    this.scrollController,
    this.summaryContent,
    this.phone = false,
    this.premiumYearlyPrice,
    this.premiumMonthlyPrice,
    this.onOpenMessage,
    this.onOpenBonds,
    this.phoneHeaderBuilder,
  });

  final WorldMemorySection section;
  final WorldMemorySnapshot snapshot;
  final bool premiumActive;
  final bool deluxeActive;
  final ValueChanged<MemoryMembershipTier> onSubscribe;
  final ScrollController? scrollController;

  /// Stands in for the whole Summary body and scrolls itself. Hosts with a live
  /// recap supply it; without one, [WorldMemorySnapshot.summaryTicks] is shown.
  final Widget? summaryContent;
  final bool phone;

  /// The store's prices when already known; list prices stand in until then.
  final String? premiumYearlyPrice;
  final String? premiumMonthlyPrice;
  final ValueChanged<WorldMemoryPerson>? onOpenMessage;
  final VoidCallback? onOpenBonds;
  final Widget Function(BuildContext, VoidCallback?)? phoneHeaderBuilder;

  @override
  State<WorldMemoryView> createState() => _WorldMemoryViewState();
}

class _WorldMemoryViewState extends State<WorldMemoryView> {
  late bool _timeline = widget.deluxeActive;
  String? _openPersonId;
  final _expandedPersonIds = <String>{};
  final _internalScrollController = ScrollController();
  ScrollController get _scrollController =>
      widget.scrollController ?? _internalScrollController;

  @override
  void dispose() {
    _internalScrollController.dispose();
    super.dispose();
  }

  void _togglePerson(String id) => setState(() {
    if (!_expandedPersonIds.remove(id)) _expandedPersonIds.add(id);
  });

  void _openPerson(String? id) {
    setState(() => _openPersonId = _openPersonId == id ? null : id);
    if (widget.phone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant WorldMemoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _timeline = widget.deluxeActive;
      _openPersonId = null;
      _expandedPersonIds.clear();
    }
    if (!widget.deluxeActive) {
      _openPersonId = null;
      _expandedPersonIds.clear();
    }
    final ids = widget.snapshot.cast.map((c) => c.person.id).toSet();
    if (!ids.contains(_openPersonId)) _openPersonId = null;
    _expandedPersonIds.retainAll(ids);
  }

  @override
  Widget build(BuildContext context) {
    final recap = widget.section == WorldMemorySection.recap;
    final tier = recap && !_timeline
        ? MemoryMembershipTier.premium
        : MemoryMembershipTier.deluxe;
    final unlocked = tier == MemoryMembershipTier.premium
        ? widget.premiumActive
        : widget.deluxeActive;
    final l10n = context.l10n;
    // Deliberately branch BEFORE building any data-backed child. Offstage,
    // blur, opacity and disabled controls would still disclose locked data.
    final Widget content;
    if (!unlocked) {
      content = _MemoryLockedStructure(
        section: widget.section,
        timeline: _timeline,
        snapshot: widget.snapshot,
        phone: widget.phone,
      );
    } else {
      content = switch (widget.section) {
        WorldMemorySection.recap =>
          _timeline
              ? _MemoryTimeline(events: widget.snapshot.events)
              : _MemorySummary(ticks: widget.snapshot.summaryTicks),
        WorldMemorySection.cast =>
          widget.phone && _openPersonId != null
              ? _MemoryPhoneProfile(
                  character: widget.snapshot.cast.firstWhere(
                    (c) => c.person.id == _openPersonId,
                  ),
                  relations: widget.snapshot.relations,
                  onBack: () => _openPerson(null),
                  showBack: widget.phoneHeaderBuilder == null,
                  onMessage: () {
                    final person = widget.snapshot.cast
                        .firstWhere((c) => c.person.id == _openPersonId)
                        .person;
                    if (widget.onOpenMessage != null) {
                      widget.onOpenMessage!(person);
                    } else {
                      showGenesisToast(
                        context,
                        context.l10n.miniPhoneComingSoon,
                      );
                    }
                  },
                  onBonds:
                      widget.onOpenBonds ??
                      () {
                        showGenesisToast(
                          context,
                          context.l10n.miniPhoneComingSoon,
                        );
                      },
                )
              : _MemoryCast(
                  snapshot: widget.snapshot,
                  phone: widget.phone,
                  expandedIds: _expandedPersonIds,
                  onToggle: widget.phone ? _openPerson : _togglePerson,
                ),
        WorldMemorySection.bonds => _MemoryBonds(
          relations: widget.snapshot.relations,
        ),
      };
    }
    final pitch = switch (widget.section) {
      WorldMemorySection.recap =>
        _timeline ? l10n.memoryTimelinePitch : l10n.memorySummaryPitch,
      WorldMemorySection.cast => l10n.memoryCastPitch,
      WorldMemorySection.bonds => l10n.memoryBondsPitch,
    };
    final summaryPage = unlocked && recap && !_timeline
        ? widget.summaryContent
        : null;
    // The sheet reaches the bottom of the screen; MiniPhone's SafeArea has
    // already taken this inset out.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: GenesisColors.darkBackground,
      child: DefaultTextStyle.merge(
        style: const TextStyle(letterSpacing: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.phoneHeaderBuilder != null)
              widget.phoneHeaderBuilder!(
                context,
                _openPersonId == null ? null : () => _openPerson(null),
              ),
            if (!unlocked && !widget.phone)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _MemoryText(
                  pitch,
                  small: true,
                  color: const Color(0x99FFFFFF),
                ),
              ),
            if (recap)
              Padding(
                padding: EdgeInsets.fromLTRB(16, widget.phone ? 4 : 12, 16, 0),
                child: _MemoryRecapTabs(
                  timeline: _timeline,
                  premium: widget.premiumActive,
                  deluxe: widget.deluxeActive,
                  onChanged: (value) => setState(() => _timeline = value),
                ),
              ),
            Expanded(
              child:
                  summaryPage ??
                  ScrollConfiguration(
                    behavior: const GenesisScrollBehavior(),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        fit: StackFit.expand,
                        children: [
                          SingleChildScrollView(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              16,
                              widget.phone
                                  ? 14
                                  : recap && unlocked
                                  ? 16
                                  : 12,
                              16,
                              (unlocked ? (widget.phone ? 32 : 24) : 344) +
                                  bottomInset,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!unlocked && widget.phone) ...[
                                  _MemoryText(
                                    pitch,
                                    small: true,
                                    color: const Color(0x99FFFFFF),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                content,
                              ],
                            ),
                          ),
                          if (!unlocked)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: GenesisColors.darkBackground,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xE6151517),
                                      offset: Offset(0, -16),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: constraints.maxHeight * .78,
                                  ),
                                  child: SingleChildScrollView(
                                    primary: false,
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      16 + bottomInset,
                                    ),
                                    child: MemoryMembershipOfferCard(
                                      key: ValueKey(
                                        'memory-offer-${tier.name}',
                                      ),
                                      tier: tier,
                                      yearlyPrice:
                                          tier == MemoryMembershipTier.premium
                                          ? widget.premiumYearlyPrice
                                          : null,
                                      monthlyPrice:
                                          tier == MemoryMembershipTier.premium
                                          ? widget.premiumMonthlyPrice
                                          : null,
                                      onSubscribe: () =>
                                          widget.onSubscribe(tier),
                                      onDetails: () => widget.onSubscribe(tier),
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
          ],
        ),
      ),
    );
  }
}
