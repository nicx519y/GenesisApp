import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../components/auth/login_guard.dart';
import '../../../components/common/genesis_center_toast.dart';
import '../../../components/common/genesis_upload_progress_overlay.dart';
import '../../../components/common/local_image_crop_page.dart';
import '../../../platform/native_image_picker.dart';
import '../../../platform/session/user_session_store.dart';
import '../../../utils/image_format_guards.dart';
import '../../../ui/tokens/genesis_colors.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';
import '../session/mini_phone_session.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_panel.dart';
import 'wallpaper/mini_phone_wallpaper_controller.dart';
import 'wallpaper/mini_phone_wallpaper_image.dart';

class MiniPhoneSettingsPage extends StatefulWidget {
  const MiniPhoneSettingsPage({
    super.key,
    required this.session,
    required this.wallpaper,
    required this.header,
    required this.active,
  });
  final MiniPhoneSession session;
  final MiniPhoneWallpaperController wallpaper;
  final Widget header;
  final bool active;
  @override
  State<MiniPhoneSettingsPage> createState() => _MiniPhoneSettingsPageState();
}

class _MiniPhoneSettingsPageState extends State<MiniPhoneSettingsPage> {
  MiniPhoneWallpaperController get wallpaper => widget.wallpaper;
  MiniPhoneStore? get phone => widget.session.data;
  bool _authorizingWallpaper = false;
  String feedback = '';
  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  @override
  void initState() {
    super.initState();
    wallpaper.addListener(_changed);
    phone?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    wallpaper.removeListener(_changed);
    phone?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => miniPhonePanel(
    widget.header,
    GenesisRefreshIndicator(
      onRefresh: wallpaper.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: miniPageInset),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: miniPhoneWallpaperPreviewWidth,
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _wallpaperBackground(
                        wallpaper.draftImage,
                        wallpaper.draftPhoto?.bytes ??
                            wallpaper.appliedPreviewBytes,
                        settingsPreview: true,
                      ),
                      const ColoredBox(color: Color(0x22000000)),
                      Column(
                        children: [
                          const SizedBox(height: 25),
                          Text(
                            phone?.worldDay ?? 'Day 2',
                            textScaler: TextScaler.noScaling,
                            style: miniStyle(14),
                          ),
                          Text(
                            widget.session.clockTime,
                            textScaler: TextScaler.noScaling,
                            style: miniStyle(38, FontWeight.w600),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final i in [
                                  'messages',
                                  'posts',
                                  'photos',
                                  'settings',
                                ])
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: miniRaised,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: MiniIcon(i, size: 18),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (wallpaper.saving || wallpaper.saveProgress == 1)
                        IgnorePointer(
                          child: GenesisUploadProgressOverlay(
                            progress: wallpaper.saveProgress,
                            showIndicator: false,
                            revealFromBottom: true,
                            animationDuration: const Duration(
                              milliseconds: 180,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Wallpaper', style: miniStyle(14, FontWeight.w600)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (wallpaper.wallpapers.length + 1).clamp(
                1,
                constraints.maxWidth < 280 ? 2 : 4,
              );
              final width = (constraints.maxWidth - columns * 8) / columns;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        selected: wallpaper.draftPhoto != null,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  width: 2,
                                  color: wallpaper.draftPhoto != null
                                      ? miniPink
                                      : Colors.transparent,
                                ),
                              ),
                              child: Material(
                                color: GenesisColors.darkCardBackground,
                                borderRadius: BorderRadius.circular(8),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap:
                                      !wallpaper.available ||
                                          wallpaper.saving ||
                                          _authorizingWallpaper
                                      ? null
                                      : _pickWallpaperPhoto,
                                  child: const SizedBox(
                                    height: 100,
                                    width: double.infinity,
                                    child: Center(
                                      child: Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 24,
                                        color: miniPink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('Upload', style: miniStyle(14)),
                          ],
                        ),
                      ),
                    ),
                    for (final w in wallpaper.wallpapers)
                      SizedBox(
                        width: width,
                        child: Semantics(
                          button: true,
                          selected:
                              wallpaper.draftPhoto == null &&
                              wallpaper.draftImage == w.imageUrl,
                          child: InkWell(
                            onTap: wallpaper.saving || _authorizingWallpaper
                                ? null
                                : () {
                                    wallpaper.select(w.imageUrl);
                                    _update(() => feedback = '');
                                  },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      width: 2,
                                      color:
                                          wallpaper.draftPhoto == null &&
                                              wallpaper.draftImage == w.imageUrl
                                          ? miniPink
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      height: 100,
                                      width: double.infinity,
                                      child: MiniPhoneWallpaperPreview(
                                        key: ValueKey(w.imageUrl),
                                        url: w.imageUrl,
                                        placeholder: const ColoredBox(
                                          color: miniRaised,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  w.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: miniStyle(14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          miniPhoneButton(
            'Apply wallpaper',
            !wallpaper.available ||
                    wallpaper.saving ||
                    _authorizingWallpaper ||
                    (!wallpaper.loaded && wallpaper.draftPhoto == null)
                ? null
                : _applyWallpaper,
            primary: true,
            isLoading: wallpaper.saving,
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
    subtitle: 'Make this phone feel like yours.',
  );

  Future<void> _pickWallpaperPhoto() async {
    final target = widget.active;
    final revision = wallpaper.identityRevision;
    bool isCurrent() =>
        mounted &&
        widget.active &&
        widget.active == target &&
        wallpaper.identityRevision == revision &&
        !wallpaper.saving &&
        !_authorizingWallpaper;
    if (!isCurrent()) return;
    try {
      final owner = await wallpaper.sessionStore.readLoginUid();
      if (!isCurrent()) return;
      final picked = await pickGenesisImages(limit: 1);
      if (picked.isEmpty || !mounted || !isCurrent()) return;
      final crop = await widget.session.push<LocalImageCropResult>(
        context,
        MaterialPageRoute<LocalImageCropResult>(
          builder: (_) => LocalImageCropPage(
            imageBytes: picked.first.bytes,
            // Match the Location cover's crop, scaling and encoding pipeline.
            cropSize: const Size(1500, 3000),
            filename: 'wallpaper.png',
            contentType: 'image/png',
            uploadOnConfirm: false,
            deferUploadPreparation: true,
          ),
        ),
      );
      if (crop == null || !isCurrent()) return;
      final currentOwner = await wallpaper.sessionStore.readLoginUid();
      if (currentOwner != owner || !isCurrent()) return;
      _update(() {
        wallpaper.selectPhoto(
          MiniWallpaperPhoto(
            bytes: crop.bytes,
            filename: crop.filename,
            contentType: crop.contentType,
            prepareUpload: crop.prepareUpload == null
                ? null
                : (onProgress) async {
                    // Paint the full cover before starting image preparation.
                    await WidgetsBinding.instance.endOfFrame;
                    final prepared = await crop.prepareUpload!(onProgress);
                    return MiniWallpaperPhoto(
                      bytes: prepared.bytes,
                      filename: prepared.filename,
                      contentType: prepared.contentType,
                    );
                  },
          ),
        );
        feedback = '';
      });
    } on UnsupportedGifImageException {
      if (mounted && isCurrent()) {
        showGenesisToast(context, unsupportedGifImageMessage);
      }
    } catch (_) {
      if (mounted && isCurrent()) {
        showGenesisToast(
          context,
          'Could not open this photo. Please try another.',
        );
      }
    }
  }

  Widget _wallpaperBackground(
    String url,
    Uint8List? photo, {
    bool settingsPreview = false,
  }) {
    return MiniPhoneWallpaperImage(
      key: ValueKey(wallpaper.identityRevision),
      url: url,
      photo: photo,
      settingsPreview: settingsPreview,
      cachedBytes: url == wallpaper.displayBackgroundImage
          ? wallpaper.displayBytes
          : null,
    );
  }

  Future<void> _applyWallpaper() async {
    if (_authorizingWallpaper || wallpaper.saving || !wallpaper.available) {
      return;
    }
    setState(() => _authorizingWallpaper = true);
    try {
      final previousUid = await wallpaper.sessionStore.readLoginUid();
      if (!mounted) return;
      if (!await ensureGenesisLogin(context)) {
        if (mounted &&
            await wallpaper.sessionStore.readLoginUid() != previousUid) {
          await wallpaper.refresh(resetDraft: true);
        }
        return;
      }
      if (!mounted) return;
      final success = await wallpaper.apply();
      if (mounted && wallpaper.feedback != null) {
        showGenesisToast(
          context,
          wallpaper.feedback!,
          brightness: Brightness.dark,
        );
      }
      if (success && mounted) setState(() => feedback = '');
    } catch (error) {
      if (mounted) {
        showGenesisToast(context, MiniPhoneStore.errorText(error));
      }
    } finally {
      if (mounted) setState(() => _authorizingWallpaper = false);
    }
  }
}
