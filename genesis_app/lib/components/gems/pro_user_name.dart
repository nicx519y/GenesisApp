import 'package:flutter/material.dart';

import 'pro_membership_badge.dart';

/// Preserves the caller's text style, ellipsis and tap target.
class ProUserName extends StatelessWidget {
  const ProUserName({
    super.key,
    required this.membershipStatus,
    this.membershipDeluxeStatus = 0,
    required this.fontSize,
    required this.child,
    this.deleted = false,
  });

  final int membershipStatus;
  final int membershipDeluxeStatus;
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
        membershipDeluxeStatus: membershipDeluxeStatus,
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
    this.membershipDeluxeStatus = 0,
    required this.fontSize,
    this.deleted = false,
    this.leadingGap = 4,
  });
  final int membershipStatus;
  final int membershipDeluxeStatus;
  final double fontSize;
  final bool deleted;
  final double leadingGap;

  static WidgetSpan span({
    required int membershipStatus,
    int membershipDeluxeStatus = 0,
    required double fontSize,
    bool deleted = false,
  }) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: ProUserBadge(
      membershipStatus: membershipStatus,
      membershipDeluxeStatus: membershipDeluxeStatus,
      fontSize: fontSize,
      deleted: deleted,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (deleted) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (membershipDeluxeStatus == 1) _badge(context, true, leadingGap),
        if (membershipStatus == 1)
          _badge(context, false, membershipDeluxeStatus == 1 ? 4 : leadingGap),
      ],
    );
  }

  Widget _badge(BuildContext context, bool deluxe, double gap) => Padding(
    padding: EdgeInsets.only(left: gap),
    child: ProMembershipBadge.beside(
      deluxe: deluxe,
      fontSize: MediaQuery.textScalerOf(context).scale(fontSize),
    ),
  );
}
