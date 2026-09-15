import 'package:flutter/material.dart';

import 'pro_membership_badge.dart';

/// Preserves the caller's text style, ellipsis and tap target.
class ProUserName extends StatelessWidget {
  const ProUserName({
    super.key,
    required this.membershipStatus,
    required this.fontSize,
    required this.child,
    this.deleted = false,
  });

  final int membershipStatus;
  final double fontSize;
  final Widget child;
  final bool deleted;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Flexible(child: child),
      ProUserBadge(
        membershipStatus: membershipStatus,
        fontSize: fontSize,
        deleted: deleted,
      ),
    ],
  );
}

/// Includes its own gap, so unknown/non-member names have no empty badge slot.
class ProUserBadge extends StatelessWidget {
  const ProUserBadge({
    super.key,
    required this.membershipStatus,
    required this.fontSize,
    this.deleted = false,
  });
  final int membershipStatus;
  final double fontSize;
  final bool deleted;

  static WidgetSpan span({
    required int membershipStatus,
    required double fontSize,
    bool deleted = false,
  }) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: ProUserBadge(
      membershipStatus: membershipStatus,
      fontSize: fontSize,
      deleted: deleted,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (deleted || membershipStatus != 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: ProMembershipBadge.beside(
        fontSize: MediaQuery.textScalerOf(context).scale(fontSize),
      ),
    );
  }
}
