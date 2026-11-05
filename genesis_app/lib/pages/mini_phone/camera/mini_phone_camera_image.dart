import 'package:flutter/material.dart';

import '../../../network/mini_phone/mini_phone_models.dart';
import '../../../ui/components/genesis_static_network_image.dart';
import '../../../utils/genesis_image_resource.dart';
import '../shared/mini_phone_controls.dart';

/// Camera requests use DPR 2, independent of the device's display density.
String miniPhoneCameraImageUrl(
  String imageUrl, {
  required double logicalWidth,
  bool fixedSize = false,
}) {
  if (imageUrl.trim().isEmpty) return '';
  final source = GenesisImageResourceRegistry.resolve(imageUrl).displayUrl;
  if (source.startsWith('assets/')) return source;
  if (!logicalWidth.isFinite || logicalWidth <= 0) return source;
  return fixedSize
      ? buildGenesisCdnResizeUrl(source, width: (logicalWidth * 2).ceil())
      : resizeGenesisImageUrl(
          source,
          logicalWidth: logicalWidth,
          devicePixelRatio: 2,
        );
}

/// Reuses the phone's avatar presentation with an exact fixed-size CDN request.
Widget miniPhoneCameraPersonAvatar(
  PhonePerson person,
  double size, {
  double? radius,
}) => miniPhonePersonAvatar(
  person,
  size,
  radius: radius,
  avatarUrl: miniPhoneCameraImageUrl(
    person.avatar,
    logicalWidth: size,
    fixedSize: true,
  ),
);

class MiniPhoneCameraImage extends StatelessWidget {
  const MiniPhoneCameraImage({
    super.key,
    required this.imageUrl,
    this.fixedSize = false,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final bool fixedSize;
  final BoxFit fit;
  final WidgetBuilder? placeholder;
  final Widget Function(BuildContext, Object)? errorWidget;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final url = miniPhoneCameraImageUrl(
        imageUrl,
        logicalWidth: bounds.maxWidth,
        fixedSize: fixedSize,
      );
      if (url.startsWith('assets/')) {
        return Image.asset(
          url,
          fit: fit,
          errorBuilder: errorWidget == null
              ? null
              : (context, error, _) => errorWidget!(context, error),
        );
      }
      return GenesisStaticNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    },
  );
}
