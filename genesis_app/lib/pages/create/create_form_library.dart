import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_upload_progress_overlay.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../components/create/genesis_create_theme.dart';
import '../../platform/native_image_picker.dart';
import '../../ui/components/genesis_form_primitives.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/text/genesis_text_input_formatters.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/genesis_message_image.dart';
import '../../utils/image_format_guards.dart';

part 'create_form_text_fields.dart';
part 'create_form_layout_actions.dart';
part 'create_upload_box.dart';
part 'create_upload_preview.dart';
part 'create_form_add_controls.dart';

const String createFormDeleteIconAsset =
    'assets/custom-icons/svg/delete-icon.svg';
const String createFormInfoIconAsset = 'assets/custom-icons/svg/info.svg';
const TextStyle createFormSupportTextStyle = TextStyle(
  fontSize: 12,
  height: 1.25,
);

final Object createFormTextFieldTapRegionGroup = Object();
