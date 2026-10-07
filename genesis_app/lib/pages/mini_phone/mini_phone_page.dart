import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../components/chat/shared/chat_scene_plate_tokens.dart';
import 'mini_phone_demo_store.dart';
import 'mini_phone_ui.dart';

part 'mini_phone_home.dart';
part 'mini_phone_conversations.dart';
part 'mini_phone_posts.dart';
part 'mini_phone_media.dart';

enum MiniPhoneScreen {
  home,
  messages,
  contacts,
  chat,
  posts,
  comments,
  create,
  photos,
  settings,
}

/// Only a debug UI prototype. It never receives production world/account data.
Future<void> showMiniPhoneDemo(
  BuildContext context, {
  MiniPhoneScreen initialScreen = MiniPhoneScreen.home,
}) async {
  if (!kDebugMode) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'debug/mini-phone-demo'),
      builder: (_) => MiniPhonePage(initialScreen: initialScreen),
    ),
  );
}

class MiniPhonePage extends StatefulWidget {
  const MiniPhonePage({super.key, this.initialScreen = MiniPhoneScreen.home});
  final MiniPhoneScreen initialScreen;
  @override
  State<MiniPhonePage> createState() => _MiniPhonePageState();
}

class _MiniPhonePageState extends State<MiniPhonePage> {
  final store = miniPhoneDemoStore;
  late MiniPhoneScreen screen;
  MiniDemoPerson contact = miniDemoPeople.first;
  MiniDemoPost? activePost;
  String? authorFilter;
  String search = '';
  final expandedNotificationGroups = <String>{};
  int homePagerPosition = 0;
  final homePages = PageController();
  void _selectHomePage(int page) {
    if (homePages.hasClients) {
      homePages.animateToPage(
        page,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  bool typing = false;
  final messageInput = TextEditingController();
  final commentInput = TextEditingController();
  final postInput = TextEditingController();
  final chatScroll = ScrollController();
  final commentsScroll = ScrollController();
  Uint8List? draftPhoto;
  Uint8List? draftWallpaperPhoto;
  String draftWallpaper = 'loc_1_1_1.jpg';
  String feedback = '';
  final _replyTimers = <Timer>[];

  @override
  void initState() {
    super.initState();
    screen = widget.initialScreen;
    store.addListener(_changed);
    _prepareSettings();
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    for (final t in _replyTimers) {
      t.cancel();
    }
    homePages.dispose();
    messageInput.dispose();
    commentInput.dispose();
    postInput.dispose();
    chatScroll.dispose();
    commentsScroll.dispose();
    super.dispose();
  }

  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  void _changed() {
    if (mounted) _update(() {});
  }

  void _go(MiniPhoneScreen next) {
    FocusManager.instance.primaryFocus?.unfocus();
    _update(() {
      screen = next;
      feedback = '';
      if (next == MiniPhoneScreen.settings) _prepareSettings();
    });
    if (next == MiniPhoneScreen.posts) store.markPostsRead();
    if (next == MiniPhoneScreen.chat) _scrollToEnd(chatScroll);
  }

  void _prepareSettings() {
    draftWallpaper = store.wallpaper;
    draftWallpaperPhoto = store.wallpaperPhoto;
  }

  void _openChat(MiniDemoPerson p) {
    contact = p;
    typing = false;
    messageInput.clear();
    store.markRead(p);
    _go(MiniPhoneScreen.chat);
  }

  void _back() {
    switch (screen) {
      case MiniPhoneScreen.home:
        Navigator.of(context).pop();
      case MiniPhoneScreen.chat:
      case MiniPhoneScreen.contacts:
        _go(MiniPhoneScreen.messages);
      case MiniPhoneScreen.comments:
      case MiniPhoneScreen.create:
        _go(MiniPhoneScreen.posts);
      default:
        _go(MiniPhoneScreen.home);
    }
  }

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
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return PopScope(
      canPop: screen == MiniPhoneScreen.home,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: miniBackground,
          textTheme: Theme.of(
            context,
          ).textTheme.apply(bodyColor: miniWhite, displayColor: miniWhite),
        ),
        child: Scaffold(
          backgroundColor: miniBackground,
          body: DefaultTextStyle(style: miniStyle(), child: _screen()),
        ),
      ),
    );
  }

  Widget _screen() => switch (screen) {
    MiniPhoneScreen.home => _home(),
    MiniPhoneScreen.messages => _messages(),
    MiniPhoneScreen.contacts => _contacts(),
    MiniPhoneScreen.chat => _chat(),
    MiniPhoneScreen.posts => _posts(),
    MiniPhoneScreen.comments => _comments(),
    MiniPhoneScreen.create => _create(),
    MiniPhoneScreen.photos => _photos(),
    MiniPhoneScreen.settings => _settings(),
  };

  Widget _navigation(String title, {MiniDemoPerson? person}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: miniPageInset),
    child: SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _back,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                foregroundColor: miniWhite,
              ),
              child: Row(
                children: [
                  const MiniIcon('back', size: 20),
                  const SizedBox(width: 12),
                  if (person != null) ...[
                    GestureDetector(
                      onTap: () => _go(MiniPhoneScreen.contacts),
                      child: MiniAvatar(person, size: 32),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: miniPageTitle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _panel(
    String title,
    Widget body, {
    String? subtitle,
    Widget? footer,
    bool indicator = true,
  }) => SafeArea(
    child: Column(
      children: [
        _navigation(title),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              miniPageInset,
              0,
              miniPageInset,
              12,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: miniStyle(12, FontWeight.w400, miniSecondary),
              ),
            ),
          ),
        Expanded(child: body),
        if (footer != null) footer,
        if (indicator) _indicator(),
      ],
    ),
  );
  Widget _indicator() => Semantics(
    label: 'Mini phone home',
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _go(MiniPhoneScreen.home),
      child: SizedBox(
        height: 28,
        width: double.infinity,
        child: Center(
          child: Container(
            height: 4,
            width: 124,
            decoration: BoxDecoration(
              color: const Color(0xCCF4F3F6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _button(String text, VoidCallback? action, {bool primary = false}) =>
      primary
      ? GenesisPrimaryButton(
          label: text,
          onPressed: action,
          fullWidth: false,
          backgroundColor: miniRed,
          foregroundColor: miniWhite,
          disabledBackgroundColor: GenesisColors.darkButtonDisabledBackground,
          disabledForegroundColor: GenesisColors.darkButtonDisabledForeground,
        )
      : TextButton(
          onPressed: action,
          style: TextButton.styleFrom(
            backgroundColor: primary ? miniRed : null,
            foregroundColor: miniPink,
            disabledBackgroundColor: primary
                ? miniRed.withValues(alpha: .35)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: const RoundedRectangleBorder(borderRadius: miniButtonRadius),
          ),
          child: Text(
            text,
            style: miniStyle(
              14,
              FontWeight.w600,
              primary ? (action == null ? miniSecondary : miniWhite) : miniPink,
            ),
          ),
        );
  Widget _input(
    TextEditingController controller,
    String hint, {
    int limit = 500,
    int maxLines = 4,
  }) => TextField(
    controller: controller,
    maxLength: limit,
    minLines: 1,
    maxLines: maxLines,
    style: miniStyle(14),
    onChanged: (_) => _update(() {}),
    decoration: InputDecoration(
      hintText: hint,
      counterText: '',
      isDense: true,
      hintStyle: miniStyle(14, FontWeight.w400, miniPlaceholder),
      filled: true,
      fillColor: GenesisColors.darkFaintFill,
      border: const OutlineInputBorder(
        borderRadius: miniInputRadius,
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: miniInputRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: miniInputRadius,
        borderSide: BorderSide.none,
      ),
    ),
  );
  Widget _sendButton(VoidCallback? action) => IconButton(
    tooltip: 'Send',
    onPressed: action,
    style: IconButton.styleFrom(
      backgroundColor: miniRed,
      disabledBackgroundColor: miniRed.withValues(alpha: .35),
    ),
    icon: MiniIcon(
      'send',
      size: 16,
      color: action == null ? miniSecondary : miniWhite,
    ),
  );
}
