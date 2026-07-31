import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/common/genesis_upload_progress_overlay.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../platform/native_image_picker.dart';
import '../../ui/components/genesis_static_network_image.dart';
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

const Color createFormGreen = Color(0xFF338960);
const Color createFormFieldFill = Color(0xFFF4F4F6);
const Color createFormHint = Color(0xFFA8A8AD);
const Color createFormText = Color(0xFF111111);
const Color createFormMuted = Color(0xFF6F6F6F);
const Color createFormNote = Color(0xFF888888);
const Color createFormBorder = Color(0xFFE1E1E6);
const Color createFormDash = Color(0xFFB8CDBF);
const Color createFormDanger = Color(0xFFFF2442);
const String createFormDeleteIconAsset =
    'assets/custom-icons/svg/delete-icon.svg';
const String createFormInfoIconAsset = 'assets/custom-icons/svg/info.svg';
const TextStyle createFormSupportTextStyle = TextStyle(
  fontSize: 12,
  height: 1.25,
);

final Object createFormTextFieldTapRegionGroup = Object();
