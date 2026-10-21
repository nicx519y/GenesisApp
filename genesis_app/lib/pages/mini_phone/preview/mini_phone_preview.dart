import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../components/chat/shared/chat_ui.dart';
import '../../../platform/system_image_picker_activity.dart';
import '../session/mini_phone_session.dart';
import '../session/mini_phone_screen.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_panel.dart';
import 'mini_phone_demo_store.dart';
import 'mini_phone_preview_avatar.dart';
import 'mini_phone_preview_photo.dart';
import 'mini_phone_preview_gallery.dart';
import 'mini_phone_preview_activity.dart';

part 'mini_phone_conversations.dart';
part 'mini_phone_posts.dart';
part 'mini_phone_media.dart';

/// Worldless visual preview only. Live pages never enter this library's parts.
class MiniPhonePreview extends StatefulWidget {
  const MiniPhonePreview({
    super.key,
    required this.session,
    required this.activity,
    required this.screen,
    required this.active,
    required this.headerBuilder,
    required this.onNavigate,
    required this.onBack,
    required this.onClose,
  });
  final MiniPhoneSession session;
  final MiniPhonePreviewActivity activity;
  final MiniPhoneScreen screen;
  final bool active;
  final Widget Function(String title, {bool showModel}) headerBuilder;
  final ValueChanged<MiniPhoneScreen> onNavigate;
  final VoidCallback onBack, onClose;
  @override
  State<MiniPhonePreview> createState() => _MiniPhonePreviewState();
}

class _MiniPhonePreviewState extends State<MiniPhonePreview> {
  MiniPhoneDemoStore get store => widget.session.store;
  MiniPhoneResume get _miniResume => widget.session.resume;
  MiniPhoneScreen get screen => widget.screen;
  MiniDemoPerson get contact => _miniResume.contact;
  set contact(MiniDemoPerson value) => _miniResume.contact = value;
  MiniDemoPost? get activePost => _miniResume.post;
  set activePost(MiniDemoPost? value) => _miniResume.post = value;
  String? get authorFilter => _miniResume.filter;
  set authorFilter(String? value) => _miniResume.filter = value;
  Uint8List? get draftPhoto => _miniResume.photo;
  set draftPhoto(Uint8List? value) => _miniResume.photo = value;
  bool typing = false;
  String feedback = '';
  final messageInput = TextEditingController();
  final commentInput = TextEditingController();
  final postInput = TextEditingController();
  final chatScroll = ScrollController();
  final commentsScroll = ScrollController();
  @override
  void initState() {
    super.initState();
    postInput.text = _miniResume.draft;
    store.addListener(_changed);
    messageInput.addListener(_changed);
    if (screen == MiniPhoneScreen.chat) _scrollToEnd(chatScroll);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  void _go(MiniPhoneScreen next) {
    if (screen == MiniPhoneScreen.create) _miniResume.draft = postInput.text;
    feedback = '';
    widget.onNavigate(next);
  }

  void _back() => widget.onBack();
  void _openChat(MiniDemoPerson person) {
    contact = person;
    typing = false;
    messageInput.clear();
    store.markRead(person);
    _go(MiniPhoneScreen.chat);
  }

  Widget _navigation(String title, {bool showModel = false}) =>
      widget.headerBuilder(title, showModel: showModel);
  Widget _panel(
    String title,
    Widget body, {
    String? subtitle,
    Widget? footer,
  }) => miniPhonePanel(
    _navigation(title),
    body,
    subtitle: subtitle,
    footer: footer,
  );
  Widget _input(
    TextEditingController controller,
    String hint, {
    int? limit = 500,
    TapRegionCallback? onTapOutside,
    int maxLines = 4,
  }) => miniPhoneInput(
    controller,
    hint,
    limit: limit,
    onTapOutside: onTapOutside,
    maxLines: maxLines,
    onChanged: _changed,
  );
  void _scrollToEnd(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    if (screen == MiniPhoneScreen.create) _miniResume.draft = postInput.text;
    store.removeListener(_changed);
    messageInput.removeListener(_changed);
    messageInput.dispose();
    commentInput.dispose();
    postInput.dispose();
    chatScroll.dispose();
    commentsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (screen) {
    MiniPhoneScreen.messages => _messages(),
    MiniPhoneScreen.chat => _chat(),
    MiniPhoneScreen.posts => _posts(),
    MiniPhoneScreen.comments => _comments(),
    MiniPhoneScreen.create => _create(),
    MiniPhoneScreen.photos => _photos(),
    _ => const SizedBox.shrink(),
  };
}
