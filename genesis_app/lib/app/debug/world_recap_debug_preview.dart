import 'package:flutter/foundation.dart';

import '../../network/models/world_recent_summary.dart';

/// Debug-only stand-in for the recap's membership and content, so each state
/// the section can show is reachable without a real subscription, or a world
/// far enough along to have produced a recap.
///
/// Held in memory only: a forced membership must not outlive the session it
/// was set in, so a restart always returns to the real state.
enum WorldRecapDebugPreview {
  off('Off (real membership)'),
  locked('Locked · non-member'),
  memberEmpty('Member · not generated yet'),
  memberSample('Member · sample recap'),
  memberLive('Member · live recap');

  const WorldRecapDebugPreview(this.label);

  final String label;
}

final ValueNotifier<WorldRecapDebugPreview> worldRecapDebugPreview =
    ValueNotifier(WorldRecapDebugPreview.off);

/// The preview in force, which release builds never honour.
WorldRecapDebugPreview get activeWorldRecapDebugPreview =>
    kDebugMode ? worldRecapDebugPreview.value : WorldRecapDebugPreview.off;

/// Membership as the preview dictates it, or null to ask the real store. The
/// live mode is a member reading this world's real recap, for looking at real
/// content without a subscription.
bool? get worldRecapForcedMembership => switch (activeWorldRecapDebugPreview) {
  WorldRecapDebugPreview.off => null,
  WorldRecapDebugPreview.locked => false,
  WorldRecapDebugPreview.memberEmpty ||
  WorldRecapDebugPreview.memberSample ||
  WorldRecapDebugPreview.memberLive => true,
};

/// Enough ticks and length to judge the recap's type, spacing and scrolling.
const List<WorldRecentSummary> worldRecapDebugSample = [
  WorldRecentSummary(
    tickNo: 14,
    body:
        'Luna left the Moonlit Market before the second bell, the ledger '
        'still hidden under her coat. Behind her, Captain Hale questioned the '
        'lamplighter, who swore he had seen no one pass.',
  ),
  WorldRecentSummary(
    tickNo: 14,
    body:
        'At the Old Harbor, the tide brought in a sealed crate bearing the '
        'crest of a house everyone believed extinct.',
  ),
  WorldRecentSummary(
    tickNo: 13,
    body:
        'The council met in secret. Mira argued for opening the archive to '
        'the public; Orsen refused, and left the chamber before the vote was '
        'called. The measure failed by a single voice.',
  ),
  WorldRecentSummary(
    tickNo: 12,
    body:
        'A stranger arrived at the Lantern Inn asking after Luna by her old '
        'name. The innkeeper said nothing, but sent word to the harbour that '
        'same night.',
  ),
  WorldRecentSummary(
    tickNo: 11,
    body:
        'Rain kept the streets empty. In the quiet, Luna finally deciphered '
        'the first page of the ledger and learned whose debts it recorded.',
  ),
];
