import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'mini_phone_demo_store.dart';
import 'mini_phone_ui.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/gems/memory_model_entry_button.dart';
import '../gems/memory_model_page.dart';
import '../gems/memory_model_page_cache.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../platform/session/user_session_store.dart';
import '../../network/models/gem_model.dart';
import '../../network/models/user_memory_settings.dart';

part 'mini_phone_home.dart';
part 'mini_phone_notifications.dart';
part 'mini_phone_conversations.dart';
part 'mini_phone_posts.dart';
part 'mini_phone_media.dart';
part 'mini_phone_music.dart';
part 'mini_phone_models.dart';

enum MiniPhoneScreen {
  home,
  messages,
  chat,
  posts,
  comments,
  create,
  photos,
  settings,
  music,
  models,
}

/// Debug UI prototype with local content/settings and a read-only model catalogue.
Future<void> showMiniPhoneDemo(
  BuildContext context, {
  MiniPhoneScreen? initialScreen,
  String worldId = '',
  MemoryModelPageCache? modelCache,
}) async {
  if (!kDebugMode) return;
  Future<GemModelCatalog> loadCatalog() async {
    final cached = modelCache?.modelCatalog;
    if (cached != null) return cached;
    if (worldId.isEmpty) {
      if (_phoneSourceCatalog != null) return _phoneSourceCatalog!;
      throw StateError('Open Mini phone from a World to view its models.');
    }
    final services = AppServicesScope.read(context);
    final session = await services.sessionStore.readCompleteSession();
    if (session == null) throw StateError('Sign in to view models.');
    final catalog = modelCache == null
        ? await services.api.v1.gem.models(worldId: worldId)
        : await modelCache.loadModelCatalog(
            uid: session.uid,
            worldId: worldId,
            loader: () => services.api.v1.gem.models(worldId: worldId),
          );
    if (catalog == null) {
      throw StateError('Models are unavailable in this World.');
    }
    modelCache?.storeModelCatalog(catalog);
    return catalog;
  }

  _phoneReferenceLoader = loadCatalog;
  _phoneReferenceGeneration++;
  if (_phoneReferenceWorldId != worldId) {
    _phoneSourceCatalog = null;
    _phoneSourceInitialized = false;
    _phoneReferenceWorldId = worldId;
  }
  _phoneSourceCatalog = modelCache?.modelCatalog ?? _phoneSourceCatalog;
  _phoneReferencePending = null;
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'debug/mini-phone-demo'),
      builder: (_) =>
          MiniPhonePage(initialScreen: initialScreen ?? _miniResume.screen),
    ),
  );
}

final _miniResume = _MiniPhoneResume();

class _MiniPhoneResume {
  MiniPhoneScreen screen = MiniPhoneScreen.home;
  MiniDemoPerson contact = miniDemoPeople.first;
  MiniDemoPost? post;
  String? filter;
  int homePage = 0;
  String draft = '';
  Uint8List? photo;
  List<_MiniPhotoItem>? viewerPhotos;
  int viewerIndex = 0;
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
  final expandedNotificationGroups = <String>{};
  int homePagerPosition = _miniResume.homePage;
  final homePages = PageController(initialPage: _miniResume.homePage);
  final homeNoticeScroll = ScrollController(keepScrollOffset: false);
  double? _homeNoticeDragProgress;
  double _homeNoticeDragDistance = 0;
  bool _homeNoticeDragActive = false;
  double _homeNoticeDragInitialProgress = 0;
  final _homeNoticeDragInitialGroups = <String>{};
  bool _closing = false;
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
  String draftWallpaper = miniSolidWallpaper;
  String feedback = '';
  final _replyTimers = <Timer>[];

  @override
  void initState() {
    super.initState();
    screen = widget.initialScreen;
    contact = _miniResume.contact;
    activePost = _miniResume.post;
    authorFilter = _miniResume.filter;
    postInput.text = _miniResume.draft;
    draftPhoto = _miniResume.photo;
    store.addListener(_changed);
    messageInput.addListener(_changed);
    _prepareSettings();
    unawaited(
      _ensurePhoneModels()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object _) {}),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _miniResume.viewerPhotos != null) {
        _openPhotoGallery(_miniResume.viewerPhotos!, _miniResume.viewerIndex);
      }
    });
  }

  @override
  void dispose() {
    _miniResume.screen = screen;
    _miniResume.contact = contact;
    _miniResume.post = activePost;
    _miniResume.filter = authorFilter;
    _miniResume.homePage = homePagerPosition;
    _miniResume.draft = postInput.text;
    _miniResume.photo = draftPhoto;
    store.removeListener(_changed);
    messageInput.removeListener(_changed);
    for (final t in _replyTimers) {
      t.cancel();
    }
    homePages.dispose();
    homeNoticeScroll.dispose();
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
    if (next == MiniPhoneScreen.models) _miniModelReturnScreen = screen;
    _update(() {
      screen = next;
      feedback = '';
      if (next == MiniPhoneScreen.settings) _prepareSettings();
    });
    if (next == MiniPhoneScreen.posts) store.markPostsRead();
    if (next == MiniPhoneScreen.chat) _scrollToEnd(chatScroll);
  }

  Widget _wallpaperBackground(String asset, Uint8List? photo) {
    if (photo != null) {
      return Image.memory(
        photo,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }
    if (asset == miniSolidWallpaper) {
      return const ColoredBox(color: miniBackground);
    }
    return Image.asset('$miniPhoneAssets$asset', fit: BoxFit.cover);
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

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _back() {
    switch (screen) {
      case MiniPhoneScreen.home:
        Navigator.of(context).pop();
      case MiniPhoneScreen.models:
        _go(_miniModelReturnScreen);
      case MiniPhoneScreen.chat:
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
      canPop: _closing || screen == MiniPhoneScreen.home,
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
          body: Stack(
            children: [
              Positioned.fill(
                child: DefaultTextStyle(style: miniStyle(), child: _screen()),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 14,
                right: miniPageInset,
                child: MiniIconButton('close', 'Close mini phone', _close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _screen() => switch (screen) {
    MiniPhoneScreen.home => _home(),
    MiniPhoneScreen.messages => _messages(),
    MiniPhoneScreen.chat => _chat(),
    MiniPhoneScreen.posts => _posts(),
    MiniPhoneScreen.comments => _comments(),
    MiniPhoneScreen.create => _create(),
    MiniPhoneScreen.photos => _photos(),
    MiniPhoneScreen.settings => _settings(),
    MiniPhoneScreen.music => _panel('Music', const _MiniMusicPlayer()),
    MiniPhoneScreen.models => _models(),
  };

  Widget _navigation(String title) => Padding(
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
          if (screen == MiniPhoneScreen.chat) ...[
            MemoryModelEntryButton(
              modelLabel: _miniPhoneModelLabel,
              variant: MemoryModelEntryButtonVariant.roomHeader,
              onTap: () => _go(MiniPhoneScreen.models),
            ),
            const SizedBox(width: 8),
          ],
          const SizedBox.square(dimension: 28),
        ],
      ),
    ),
  );

  Widget _panel(
    String title,
    Widget body, {
    String? subtitle,
    Widget? footer,
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
      ],
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
