import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/page_header.dart';
import '../../components/world_memory/world_memory.dart';
import '../../components/world_memory/world_memory_preview_data.dart';
import '../../components/gems/memory_membership_style.dart';
import '../../components/gems/memory_membership_preview_page.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/navigation/genesis_dark_page_route.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';

/// Explicit, isolated design gallery. No account override, cache mutation,
/// network service or checkout is reachable from the sample controls.
class DeveloperGlobalMemoryPreview extends StatefulWidget {
  const DeveloperGlobalMemoryPreview({super.key});

  @override
  State<DeveloperGlobalMemoryPreview> createState() =>
      _DeveloperGlobalMemoryPreviewState();
}

class _DeveloperGlobalMemoryPreviewState
    extends State<DeveloperGlobalMemoryPreview> {
  var _ownership = 3;
  var _scenario = 0;
  var _section = WorldMemorySection.recap;
  var _phone = false;
  var _showControls = false;

  bool get _premium => _ownership == 1 || _ownership == 3;
  bool get _deluxe => _ownership == 2 || _ownership == 3;

  void _membership([MemoryMembershipTier tier = MemoryMembershipTier.premium]) {
    Navigator.of(context).push(
      GenesisDarkPageRoute<void>(
        builder: (_) => MemoryMembershipPreviewPage(
          premiumActive: _premium,
          deluxeActive: _deluxe,
          initialTier: tier,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final l10n = context.l10n;
    final snapshot = switch (_scenario) {
      1 => WorldMemoryPreviewData.fresh(),
      2 => WorldMemoryPreviewData.departures(),
      _ => WorldMemoryPreviewData.live(),
    };
    return Scaffold(
      appBar: GenesisBackAppBar(
        pageName: switch (_section) {
          WorldMemorySection.recap => l10n.worldRecap,
          WorldMemorySection.cast => l10n.memoryCast,
          WorldMemorySection.bonds => l10n.memoryBonds,
        },
        actions: [
          IconButton(
            tooltip: l10n.memoryPreviewTitle,
            icon: const Icon(Icons.tune, size: 20),
            onPressed: () => setState(() => _showControls = !_showControls),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.memoryPreviewNotice,
                  style: GenesisTypography.supporting,
                ),
              ),
            ),
            if (_showControls) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: _ownership,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(
                              l10n.memoryPreviewFree,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 1,
                            child: Text('Premium'),
                          ),
                          const DropdownMenuItem(
                            value: 2,
                            child: Text('Deluxe'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text(
                              l10n.memoryPreviewBoth,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _ownership = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<int>(
                        value: _scenario,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(
                              l10n.memoryPreviewLive,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              l10n.memoryPreviewFresh,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              l10n.memoryPreviewDepartures,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _scenario = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.memoryPreviewPhone),
                      selected: _phone,
                      onSelected: (value) => setState(() => _phone = value),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _membership,
                      child: Text(l10n.memoryPreviewMemberships),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: WorldMemoryView(
                key: ValueKey((_section, _scenario, _ownership, _phone)),
                section: _section,
                snapshot: snapshot,
                premiumActive: _premium,
                deluxeActive: _deluxe,
                phone: _phone,
                onOpenBonds: () =>
                    setState(() => _section = WorldMemorySection.bonds),
                onSubscribe: _membership,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  for (final section in WorldMemorySection.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: TextButton(
                          onPressed: () => setState(() => _section = section),
                          style: TextButton.styleFrom(
                            foregroundColor: GenesisColors.darkTextPrimary,
                            backgroundColor: _section == section
                                ? GenesisColors.darkFaintFill
                                : Colors.transparent,
                          ),
                          child: Text(switch (section) {
                            WorldMemorySection.recap => l10n.worldRecap,
                            WorldMemorySection.cast => l10n.memoryCast,
                            WorldMemorySection.bonds => l10n.memoryBonds,
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
