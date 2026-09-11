import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/membership/user_membership_status_store.dart';
import 'pro_membership_badge.dart';

/// Preserves the caller's text style, ellipsis and tap target.
class ProUserName extends StatelessWidget {
  const ProUserName({
    super.key,
    required this.uid,
    required this.fontSize,
    required this.child,
    this.deleted = false,
  });

  final String uid;
  final double fontSize;
  final Widget child;
  final bool deleted;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Flexible(child: child),
      ProUserBadge(uid: uid, fontSize: fontSize, deleted: deleted),
    ],
  );
}

/// Includes its own gap, so unknown/non-member names have no empty badge slot.
class ProUserBadge extends StatefulWidget {
  const ProUserBadge({
    super.key,
    required this.uid,
    required this.fontSize,
    this.deleted = false,
  });
  final String uid;
  final double fontSize;
  final bool deleted;

  static WidgetSpan span({
    required String uid,
    required double fontSize,
    bool deleted = false,
  }) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: ProUserBadge(uid: uid, fontSize: fontSize, deleted: deleted),
  );

  @override
  State<ProUserBadge> createState() => _ProUserBadgeState();
}

class _ProUserBadgeState extends State<ProUserBadge>
    with WidgetsBindingObserver {
  UserMembershipStatusStore? _store;
  String _uid = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind(AppServicesScope.maybeOf(context)?.userMemberships);
  }

  @override
  void didUpdateWidget(ProUserBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind(_store);
  }

  void _bind(UserMembershipStatusStore? store) {
    final uid = widget.deleted ? '' : widget.uid.trim();
    if (identical(store, _store) && uid == _uid) return;
    _store?.unwatch(_uid);
    _store = store;
    _uid = uid;
    _store?.watch(_uid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _store?.refreshWatched();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store?.unwatch(_uid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null || _uid.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => !store.isActive(_uid)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ProMembershipBadge.beside(
                fontSize: MediaQuery.textScalerOf(
                  context,
                ).scale(widget.fontSize),
              ),
            ),
    );
  }
}
