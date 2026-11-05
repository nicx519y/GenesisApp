import '../../utils/api_error_message.dart';
import '../../components/common/genesis_center_toast.dart';
import 'dart:math' as math;
import '../../utils/gem_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/gems/gem_assets.dart';
import '../../components/common/genesis_bottom_sheet_panel.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../icons/custom_icon_assets.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/components/genesis_dark_close_button.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_localized_rich_text.dart';
import '../../ui/tokens/genesis_radii.dart';
import 'shared/mini_phone_ui.dart';

/// Local presentation preference only; confirming never creates a photo.
Future<bool> confirmCameraMoment(
  BuildContext context, {
  required String preferenceScope,
  bool forceShow = false,
  int? priceCent,
  bool recovering = false,
  bool? cameraFreeAvailable,
  Future<int> Function()? loadPrice,
}) async {
  final key = loadPrice != null
      ? 'chat-photo-confirmation-v2:$preferenceScope'
      : cameraFreeAvailable != null
      ? 'phone-camera-confirmation-v1:$preferenceScope'
      : priceCent == null
      ? 'camera-moment-confirmation:$preferenceScope'
      : 'chat-photo-confirmation-v1:$preferenceScope';
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
    if (!forceShow &&
        (loadPrice != null || !recovering) &&
        (loadPrice != null
            ? preferences.getBool(key) == true ||
                  (preferences.get(key) == null &&
                      preferences.get(
                            'chat-photo-confirmation-v1:$preferenceScope',
                          )
                          is int)
            : cameraFreeAvailable != null
            ? preferences.getString(key) == '$priceCent:$cameraFreeAvailable'
            : priceCent == null
            ? preferences.getBool(key) == true
            : preferences.getInt(key) == priceCent)) {
      return true;
    }
  } catch (_) {
    // A preference read must not prevent the explanation from being shown.
  }
  if (!context.mounted) return false;
  final result = await showGenesisModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CameraMomentConfirmation(
      priceCent: priceCent,
      loadPrice: loadPrice,
      recovering: recovering,
      cameraFreeAvailable: cameraFreeAvailable,
    ),
  );
  if (result == null) return false;
  if (preferences != null) {
    try {
      if (result) {
        if (loadPrice != null) {
          await preferences.setBool(key, true);
        } else if (cameraFreeAvailable != null) {
          await preferences.setString(key, '$priceCent:$cameraFreeAvailable');
        } else if (priceCent == null) {
          await preferences.setBool(key, true);
        } else if (!recovering) {
          await preferences.setInt(key, priceCent);
        }
      } else {
        if (loadPrice != null) {
          await preferences.setBool(key, false);
        } else {
          await preferences.remove(key);
        }
      }
    } catch (_) {
      // A failed preference save safely leaves confirmation enabled next time.
    }
  }
  return true;
}

class _CameraMomentConfirmation extends StatefulWidget {
  const _CameraMomentConfirmation({
    this.priceCent,
    this.loadPrice,
    this.recovering = false,
    this.cameraFreeAvailable,
  });
  final bool? cameraFreeAvailable;
  final int? priceCent;
  final Future<int> Function()? loadPrice;
  final bool recovering;
  @override
  State<_CameraMomentConfirmation> createState() =>
      _CameraMomentConfirmationState();
}

class _CameraMomentConfirmationState extends State<_CameraMomentConfirmation> {
  bool remember = true;
  int? _loadedPrice;
  bool get _realPrice => widget.priceCent != null || widget.loadPrice != null;
  int? get _price => _loadedPrice ?? widget.priceCent;

  @override
  void initState() {
    super.initState();
    final load = widget.loadPrice;
    if (load != null) _fetchPrice(load);
  }

  Future<void> _fetchPrice(Future<int> Function() load) async {
    try {
      final price = await load();
      if (mounted) setState(() => _loadedPrice = price);
    } catch (error) {
      if (mounted) {
        showGenesisToast(
          context,
          apiErrorMessage(error),
          brightness: Brightness.dark,
        );
      }
    }
  }

  void _toggleRemember() => setState(() => remember = !remember);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: miniBackground,
      borderRadius: GenesisRadii.sheet,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Padding(
                    // This explanation needs less space below its title.
                    padding: const EdgeInsets.fromLTRB(56, 22, 56, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        l10n.miniPhoneCameraMomentTitle,
                        textAlign: TextAlign.center,
                        style: GenesisActionSheetHeader.titleStyle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: GenesisActionSheetHeader.inset,
                    child: GenesisDarkCloseButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.recovering
                      ? l10n.chatPhotoUncertain
                      : _realPrice
                      ? l10n.chatPhotoPriceExplanation
                      : l10n.miniPhoneCameraMomentBody,
                  textAlign: TextAlign.center,
                  style: miniStyle(12, FontWeight.w400, miniSecondary),
                ),
              ),
              if (widget.cameraFreeAvailable == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text(
                    l10n.cameraFreeAvailable,
                    textAlign: TextAlign.center,
                    style: miniStyle(12, FontWeight.w400, miniSecondary),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                height: 156,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = math.min(
                      98.0,
                      constraints.maxWidth * .30,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        for (final (index, name) in [
                          'selfie',
                          'friend',
                          'mirror',
                        ].indexed)
                          Transform.translate(
                            offset: Offset(
                              (index - 1) * cardWidth * .78,
                              index == 1 ? -3 : 10,
                            ),
                            child: Transform.rotate(
                              angle: (index - 1) * .12,
                              child: Container(
                                width: cardWidth,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: index == 1 ? miniPink : miniLine,
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/mini_phone/camera-templates/$name.webp',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Container(
                key: const ValueKey('camera-moment-price'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: miniPink.withValues(alpha: .4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(gemIconAsset, width: 14, height: 14),
                    const SizedBox(width: 6),
                    if (_realPrice)
                      Text(
                        l10n.chatPhotoBasePrice(
                          price: _price == null ? '—' : formatGemCent(_price!),
                        ),
                        style: miniStyle(12, FontWeight.w600),
                      )
                    else
                      GenesisLocalizedRichText(
                        template: l10n.miniPhoneCameraFreePrice(
                          originalPrice: GenesisLocalizedRichText.placeholder(
                            'originalPrice',
                          ),
                          price: GenesisLocalizedRichText.placeholder('price'),
                        ),
                        placeholders: const {
                          'originalPrice': TextSpan(
                            text: '30',
                            style: TextStyle(
                              color: miniTertiary,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: miniTertiary,
                            ),
                          ),
                          'price': TextSpan(
                            text: '0',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        },
                        style: miniStyle(12, FontWeight.w400),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GenesisPrimaryButton(
                  label: widget.recovering
                      ? l10n.chatPhotoRecover
                      : _realPrice
                      ? l10n.chatPhotoGenerate
                      : l10n.miniPhoneCameraFreeTrial,
                  leadingIcon: SvgPicture.asset(
                    cameraIconAsset,
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  height: 40,
                  fontSize: 14,
                  onPressed: () => Navigator.pop(context, remember),
                  backgroundColor: miniRed,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              if (!widget.recovering)
                Semantics(
                  key: const ValueKey('camera-moment-remember'),
                  label: l10n.miniPhoneCameraDontAskAgain,
                  checked: remember,
                  enabled: true,
                  onTap: _toggleRemember,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: _toggleRemember,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              key: const ValueKey('camera-moment-checkbox'),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: remember ? Colors.white : null,
                                border: Border.all(color: Colors.white),
                              ),
                              child: remember
                                  ? const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: miniBackground,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.miniPhoneCameraDontAskAgain,
                                style: miniStyle(
                                  11,
                                  FontWeight.w400,
                                  miniSecondary,
                                ).copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
