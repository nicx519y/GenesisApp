import '../../l10n/genesis_l10n.dart';
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
  off,
  yearly,
  monthly,
  expired,
  none;

  String get label => switch (this) {
    off => GenesisL10n.current.developerMembershipOff,
    yearly => GenesisL10n.current.developerMembershipYearly,
    monthly => GenesisL10n.current.developerMembershipMonthly,
    expired => GenesisL10n.current.expiredStatus,
    none => GenesisL10n.current.developerMembershipNone,
  };
}

final ValueNotifier<MembershipDebugOverride> membershipDebugOverride =
    ValueNotifier(MembershipDebugOverride.off);

/// The override in force, which release builds never honour.
MembershipDebugOverride get activeMembershipDebugOverride =>
    kDebugMode ? membershipDebugOverride.value : MembershipDebugOverride.off;
