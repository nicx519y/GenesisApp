import '../../../l10n/genesis_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_panel.dart';
import '../../../app/bootstrap/app_services_scope.dart';
import '../../../ui/components/genesis_list_image.dart';
import '../../../ui/components/genesis_primary_button.dart';
import '../../../ui/tokens/genesis_colors.dart';
import '../../../platform/native_image_picker.dart';
import '../../../utils/image_upload_processing.dart';
import '../../../utils/upload_image_byte_limit.dart';
import '../../../utils/genesis_image_resource.dart';
import 'mini_phone_post_draft.dart';

import 'mini_phone_draft_photo.dart';

class MiniPhoneCreatePostPage extends StatefulWidget {
  const MiniPhoneCreatePostPage({
    super.key,
    required this.store,
    required this.draft,
    required this.active,
    required this.header,
    required this.onPublished,
  });
  final MiniPhoneStore store;
  final MiniPhonePostDraft draft;
  final bool active;
  final Widget header;
  final VoidCallback onPublished;
  @override
  State<MiniPhoneCreatePostPage> createState() =>
      _MiniPhoneCreatePostPageState();
}

class _MiniPhoneCreatePostPageState extends State<MiniPhoneCreatePostPage> {
  MiniPhoneStore get phone => widget.store;
  MiniPhonePostDraft get postDraft => widget.draft;
  PhonePerson get _liveMe => phone.person(phone.uid ?? '', type: 1);
  final postInput = TextEditingController();
  Object? _profile;
  Object get _currentProfile => (
    phone.accountGeneration,
    phone.worldName,
    _liveMe.id,
    _liveMe.name,
    _liveMe.avatar,
    postDraft.locked,
  );
  @override
  void initState() {
    super.initState();
    postInput.text = postDraft.text;
    _profile = _currentProfile;
    phone.addListener(_profileChanged);
    postDraft.addListener(_changed);
  }

  void _profileChanged() {
    final next = _currentProfile;
    if (_profile == next) return;
    _profile = next;
    _changed();
  }

  void _changed() {
    if (!mounted) return;
    if (postInput.text != postDraft.text) postInput.text = postDraft.text;
    setState(() {});
  }

  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  @override
  void dispose() {
    phone.removeListener(_profileChanged);
    postDraft.removeListener(_changed);
    postInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _liveCreate();
  Future<void> _chooseLivePhoto() => postDraft.choose(() async {
    final files = await pickGenesisImageFiles(
      limit: 1,
      normalizeForUpload: true,
      allowGif: true,
    );
    if (files.isEmpty) return null;
    final file = files.first;
    return fitPreparedUploadImage(
      ProcessedUploadImage(
        bytes: await file.readAsBytes(),
        filename: imageFilename(file),
        contentType: file.mimeType ?? guessImageContentType(file.name),
      ),
    );
  });

  Future<void> _publishLivePost() async {
    final data = phone;
    final generation = data.accountGeneration;
    final ok = await postDraft.submit((photo) async {
      final api = AppServicesScope.read(context).api;
      final result = await api.v1.upload.image(
        bytes: photo.bytes,
        filename: photo.filename,
        contentType: photo.contentType,
      );
      return GenesisImageResourceRegistry.resolve(result).displayUrl;
    });
    if (!mounted ||
        phone.requests.disposed ||
        generation != data.accountGeneration ||
        !ok) {
      return;
    }
    // Navigation remains available while sending; don't pull the user back.
    if (widget.active) {
      data.authorFilter = null;
      widget.onPublished();
    }
  }

  Widget _liveCreate() => miniPhonePanel(
    widget.header,
    SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(miniPageInset, 8, miniPageInset, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              miniPhonePersonAvatar(_liveMe, 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_liveMe.name, style: miniStyle(14, FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      phone.worldName,
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: postInput,
            readOnly: postDraft.locked,
            minLines: 5,
            maxLines: 8,
            maxLength: MiniPhonePostDraft.maxCharacters,
            maxLengthEnforcement:
                MaxLengthEnforcement.truncateAfterCompositionEnds,
            onChanged: (value) {
              postDraft.setText(value);
              _update(() {});
            },
            style: miniStyle(14),
            decoration: InputDecoration(
              hintText: context.l10n.miniPhonePostHint,
              hintStyle: miniStyle(14, FontWeight.w400, miniPlaceholder),
              filled: true,
              fillColor: GenesisColors.darkFaintFill,
              contentPadding: const EdgeInsets.all(14),
              border: const OutlineInputBorder(
                borderRadius: miniInputRadius,
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: miniInputRadius,
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: miniInputRadius,
                borderSide: BorderSide.none,
              ),
              counterStyle: miniStyle(12, FontWeight.w400, miniTertiary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.miniPhonePhotoOptional,
            style: miniStyle(14, FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 108,
                height: 144,
                child: CustomPaint(
                  painter: MiniPhoneUploadBorder(),
                  child: InkWell(
                    onTap: postDraft.locked || postDraft.preparing
                        ? null
                        : _chooseLivePhoto,
                    borderRadius: BorderRadius.circular(13),
                    child: postDraft.photo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image(
                              key: const ValueKey('mini-phone-draft-photo'),
                              image: miniPhoneDraftPhotoProvider(
                                postDraft.photo!.bytes,
                                devicePixelRatio: MediaQuery.devicePixelRatioOf(
                                  context,
                                ),
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.image_outlined),
                              ),
                            ),
                          )
                        : postDraft.uploadedUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: GenesisListImage(
                              imageUrl: postDraft.uploadedUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const MiniIcon(
                                'upload',
                                size: 22,
                                color: miniPink,
                              ),
                              const SizedBox(height: 9),
                              Flexible(
                                child: Text(
                                  context.l10n.miniPhoneChoosePhoto,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: miniStyle(
                                    12,
                                    FontWeight.w600,
                                    miniPink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (postDraft.photo != null ||
                        postDraft.uploadedUrl != null) ...[
                      miniPhoneButton(
                        context.l10n.miniPhoneReplacePhoto,
                        postDraft.locked || postDraft.preparing
                            ? null
                            : _chooseLivePhoto,
                      ),
                      miniPhoneButton(
                        context.l10n.miniPhoneRemovePhoto,
                        postDraft.locked || postDraft.preparing
                            ? null
                            : postDraft.removePhoto,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    footer: Padding(
      padding: const EdgeInsets.fromLTRB(miniPageInset, 12, miniPageInset, 12),
      child: GenesisPrimaryButton(
        label: context.l10n.miniPhonePublish,
        onPressed: postDraft.canSubmit ? _publishLivePost : null,
        isLoading: postDraft.submitting,
        backgroundColor: miniRed,
        foregroundColor: miniWhite,
        disabledBackgroundColor: GenesisColors.darkButtonDisabledBackground,
        disabledForegroundColor: GenesisColors.darkButtonDisabledForeground,
      ),
    ),
  );
}
