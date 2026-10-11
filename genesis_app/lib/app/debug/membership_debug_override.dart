import 'package:flutter/foundation.dart';

/// Debug-only stand-in for the account's membership, so the app can be seen
/// as a subscriber (or a lapsed one) without buying a plan.
///
/// Applied inside the membership store, so every screen that asks about
/// membership sees the same answer. The server still knows the real account:
/// quotas and purchases it enforces are unchanged.
///
/// Held in memory only: a forced membership must not outlive the session it
/// was set in, so a restart always returns to the real state.
enum MembershipDebugOverride {
  off('Off (real membership)'),
  yearly('Premium · yearly'),
  monthly('Premium · monthly'),
  expired('Expired'),
  none('Non-member');

  const MembershipDebugOverride(this.label);

  final String label;
}

final ValueNotifier<MembershipDebugOverride> membershipDebugOverride =
    ValueNotifier(MembershipDebugOverride.off);

/// The override in force, which release builds never honour.
MembershipDebugOverride get activeMembershipDebugOverride =>
    kDebugMode ? membershipDebugOverride.value : MembershipDebugOverride.off;
