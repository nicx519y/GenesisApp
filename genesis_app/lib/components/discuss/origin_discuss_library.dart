import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_ugc_text.dart';
import '../../utils/stat_count_formatter.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_image_viewer_overlay.dart';
import '../common/genesis_timestamp_text.dart';
import 'discuss_post_input.dart';
import 'origin_discuss_replies_list.dart';
import '../auth/login_guard.dart';

part 'origin_discuss_models.dart';
part 'origin_discuss_controller.dart';
part 'origin_discuss_list_view.dart';
part 'origin_discuss_comment_row.dart';
part 'origin_discuss_reply_actions.dart';
part 'origin_discuss_media_meta.dart';

typedef OriginDiscussPageLoader =
    Future<OriginDiscussPage> Function({
      required String oid,
      required int pn,
      required int rn,
    });
typedef OriginDiscussReplyTap =
    void Function(OriginDiscussListItem item, Map<String, dynamic> reply);
typedef OriginDiscussItemTap = void Function(OriginDiscussListItem item);

const int originDiscussPageSize = 20;
const int originDiscussRepliesPageSize = 20;
const String _discussLikeFilledAsset =
    'assets/custom-icons/png/discuss_like_filled.png';
const String _discussLikeOutlineAsset =
    'assets/custom-icons/png/discuss_like_outline.png';
const String _discussReplyAsset = 'assets/custom-icons/png/discuss_reply.png';
const double _discussAvatarSize = 36;

Future<OriginDiscussPage> loadOriginDiscussPage(
  BuildContext context,
  String oid, {
  int pn = 1,
  int rn = originDiscussPageSize,
}) async {
  final resolvedOid = oid.trim();
  if (resolvedOid.isEmpty) return OriginDiscussPage.empty(pn: pn, rn: rn);

  final api = AppServicesScope.read(context).api.v1;
  final data = await api.discuss.list(bizId: resolvedOid, pn: pn, rn: rn);
  return OriginDiscussPage.fromJson(data);
}
