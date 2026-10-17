import 'mini_phone_store.dart';
import 'mini_phone_post_draft.dart';
import 'mini_phone_post_feed.dart';
import 'mini_phone_post_thumbnail.dart';
import 'mini_phone_photo_thumbnail.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../utils/image_upload_processing.dart';
import '../../utils/upload_image_byte_limit.dart';
import 'mini_phone_live_chat.dart';
import '../../network/mini_phone/mini_phone_models.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../utils/display_name_formatter.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/animations/app_launch_transition/app_launch_transition.dart';
import '../../ui/navigation/genesis_dark_page_route.dart';
import 'mini_phone_demo_store.dart';
import 'mini_phone_music_service.dart';
import 'mini_phone_music_progress.dart';
import '../../platform/system_image_picker_activity.dart';
import 'mini_phone_music_widgets.dart';
import 'mini_phone_wallpaper_controller.dart';
import 'mini_phone_wallpaper_cache.dart';
import 'mini_phone_wallpaper_background.dart';
import 'mini_phone_wallpaper_image.dart';
import '../../components/auth/login_guard.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_upload_progress_overlay.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../platform/native_image_picker.dart';
import '../../utils/image_format_guards.dart';
import '../../ui/components/genesis_refresh_indicator.dart';
import '../../utils/genesis_image_resource.dart';
import '../../platform/session/memory_user_session_store.dart';
import 'mini_phone_ui.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/gems/memory_model_entry_button.dart';
import '../gems/memory_model_page.dart';
import '../gems/memory_model_page_cache.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/config/genesis_image_config.dart';
import '../../platform/session/user_session_store.dart';
import '../../network/models/gem_model.dart';
import '../../network/models/user_memory_settings.dart';
import '../../network/models/music.dart';
import '../../network/api_exception.dart';

part 'mini_phone_home.dart';
part 'mini_phone_live.dart';
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

/// World-backed MiniPhone; worldless calls retain the explicit style preview.
Future<void> showMiniPhoneDemo(
  BuildContext context, {
  MiniPhoneScreen? initialScreen,
  String worldId = '',
  MemoryModelPageCache? modelCache,
  MiniPhoneSession? session,
}) async {
  final inherited = MiniPhoneSessionScope.read(context);
  final phone =
      session ?? inherited ?? MiniPhoneSession.forWorld(context, worldId);
  if (phone.isDisposed) return;
  final ownsSession = session == null && inherited == null;
  Future<GemModelCatalog> loadCatalog() async {
    final cached = modelCache?.modelCatalog;
    if (cached != null) return cached;
    if (worldId.isEmpty) {
      if (phone._phoneSourceCatalog != null) return phone._phoneSourceCatalog!;
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

  phone._phoneReferenceLoader = loadCatalog;
  phone._phoneReferenceGeneration++;
  if (phone._phoneReferenceWorldId != worldId) {
    phone._phoneSourceCatalog = null;
    phone._phoneSourceInitialized = false;
    phone._phoneReferenceWorldId = worldId;
  }
  phone._phoneSourceCatalog =
      modelCache?.modelCatalog ?? phone._phoneSourceCatalog;
  phone._phoneReferencePending = null;
  try {
    await phone.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'debug/mini-phone-demo'),
        builder: (_) => MiniPhonePage(
          worldId: worldId,
          session: phone,
          initialScreen: initialScreen ?? phone._resume.screen,
        ),
      ),
    );
  } finally {
    if (ownsSession) phone.dispose();
  }
}

/// Owned by a World route, shared by its map, location chats and MiniPhone route.
class MiniPhoneSession {
  MiniPhoneSession({
    this.worldId = '',
    this.data,
    MiniPhoneMusicService? music,
    MiniPhoneDemoStore? store,
    Future<MusicCatalog> Function()? musicLoader,
  }) : music = music ?? MiniPhoneMusicService(),
       store = store ?? MiniPhoneDemoStore(),
       _musicLoader = musicLoader;

  factory MiniPhoneSession.forWorld(BuildContext context, String worldId) {
    final services = AppServicesScope.read(context);
    return MiniPhoneSession(
      worldId: worldId,
      data: worldId.isEmpty
          ? null
          : MiniPhoneStore(
              api: services.api.miniPhone,
              worldId: worldId,
              namespace: services.config.chatroomHttpBaseUrl,
              readUid: services.sessionStore.readLoginUid,
              loadWorld: () => services.api.getWorld(worldId),
              loadUser: services.api.getUser,
              accountRevision: services.sessionRevision,
            ),
      music: MiniPhoneMusicService(
        progressStore: worldId.isEmpty
            ? null
            : LocalMiniPhoneMusicProgressStore(
                namespace: services.platformConfig.apiBaseUrl,
                worldId: worldId,
                owner: services.sessionStore.readLoginUid().catchError(
                  (Object _) => null,
                ),
              ),
      ),
      musicLoader: services.api.fetchMusicCatalog,
    );
  }
  final String worldId;
  final MiniPhoneMusicService music;
  final MiniPhoneStore? data;
  late final MiniPhonePostDraft? postDraft = data == null
      ? null
      : MiniPhonePostDraft(data!);
  final MiniPhoneDemoStore store;
  final Future<MusicCatalog> Function()? _musicLoader;
  final _resume = _MiniPhoneResume();
  final _routes = <Route<dynamic>, NavigatorState>{};
  bool _disposed = false;
  bool get isDisposed => _disposed;
  MiniPhoneScreen _miniModelReturnScreen = MiniPhoneScreen.chat;
  GemModelCatalog? _phoneSourceCatalog;
  String _phoneReferenceWorldId = '';
  int _phoneReferenceGeneration = 0;
  Future<GemModelCatalog> Function()? _phoneReferenceLoader;
  Future<void>? _phoneReferencePending;
  bool _phoneSourceInitialized = false;
  String _miniPhoneModelCode = '';
  int _miniPhoneTokens = 8000;

  void ensureMusicCatalog() {
    if (!_disposed && _musicLoader != null) {
      unawaited(music.loadCatalog(_musicLoader));
    }
  }

  Future<T?> push<T>(BuildContext context, Route<T> route) async {
    if (_disposed) return null;
    final navigator = Navigator.of(context, rootNavigator: true);
    _routes[route] = navigator;
    try {
      return await navigator.push(route);
    } finally {
      _routes.remove(route);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _phoneReferenceGeneration++;
    _phoneReferenceLoader = null;
    _phoneSourceCatalog = null;
    music.dispose();
    postDraft?.dispose();
    data?.dispose();
    store.dispose();
    final routes = _routes.entries.toList().reversed.toList();
    _routes.clear();
    scheduleMicrotask(() {
      for (final entry in routes) {
        if (entry.value.mounted && entry.key.isActive) {
          entry.value.removeRoute(entry.key);
        }
      }
    });
  }
}

class MiniPhoneSessionScope extends InheritedWidget {
  const MiniPhoneSessionScope({
    super.key,
    required this.session,
    required super.child,
  });
  final MiniPhoneSession session;
  static MiniPhoneSession? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MiniPhoneSessionScope>()?.session;
  @override
  bool updateShouldNotify(MiniPhoneSessionScope oldWidget) =>
      oldWidget.session != session;
}

class _MiniPhoneResume {
  int? accountGeneration;
  MiniPhoneScreen screen = MiniPhoneScreen.home;
  MiniDemoPerson contact = miniDemoPeople.first;
  MiniDemoPost? post;
  String? filter;
  int homePage = 0;
  String draft = '';
  PhonePerson? liveContact;
  int? livePostId;
  Uint8List? photo;
  List<_MiniPhotoItem>? viewerPhotos;
  int viewerIndex = 0;
}

/// Uses the same platform route transitions as the rest of the app.
class _MiniPhoneRoutePage extends Page<void> {
  const _MiniPhoneRoutePage({
    required this.screen,
    required this.child,
    required super.key,
  });
  final MiniPhoneScreen screen;
  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => GenesisDarkPageRoute<void>(
    settings: this,
    builder: (context) =>
        (ModalRoute.of(context)!.settings as _MiniPhoneRoutePage).child,
  );
}

class MiniPhonePage extends StatefulWidget {
  const MiniPhonePage({
    super.key,
    this.initialScreen = MiniPhoneScreen.home,
    this.worldId = '',
    this.wallpaperController,
    this.session,
  });
  final MiniPhoneSession? session;
  final MiniPhoneScreen initialScreen;
  final String worldId;
  final MiniPhoneWallpaperController? wallpaperController;
  @override
  State<MiniPhonePage> createState() => _MiniPhonePageState();
}

class _MiniPhonePageState extends State<MiniPhonePage> {
  late final MiniPhoneSession _session;
  late final bool _ownsSession;
  MiniPhoneDemoStore get store => _session.store;
  MiniPhoneStore? get phone => _session.data;
  PhonePerson? liveContact;
  int? livePostId;
  PhoneComment? replyToComment;
  MiniPhonePostDraft get postDraft => _session.postDraft!;
  String? _phoneOwner;

  MiniPhoneMusicService get _music => _session.music;
  _MiniPhoneResume get _miniResume => _session._resume;
  MiniPhoneScreen get _miniModelReturnScreen => _session._miniModelReturnScreen;
  set _miniModelReturnScreen(MiniPhoneScreen value) =>
      _session._miniModelReturnScreen = value;
  String get _miniPhoneModelLabel => _session._miniPhoneModelLabel;
  late MiniPhoneScreen screen;
  final _pageNavigatorKey = GlobalKey<NavigatorState>();
  late final AppLaunchTransitionController _launchTransition;
  MiniPhoneScreen? _launchApp;
  MiniDemoPerson contact = miniDemoPeople.first;
  MiniDemoPost? activePost;
  String? authorFilter;
  final expandedNotificationGroups = <String>{};
  late int homePagerPosition;
  late final PageController homePages;
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
  late final MiniPhoneWallpaperController wallpaper;
  bool _authorizingWallpaper = false;
  String feedback = '';
  final _refreshingPhoneLists = <String>{};
  final _shownPhoneErrors = <String, String>{};
  bool _phoneErrorToastScheduled = false;
  final _replyTimers = <Timer>[];

  @override
  void initState() {
    super.initState();
    final inherited = MiniPhoneSessionScope.read(context);
    _ownsSession = widget.session == null && inherited == null;
    _session =
        widget.session ??
        inherited ??
        (widget.worldId.isNotEmpty && widget.wallpaperController == null
            ? MiniPhoneSession.forWorld(context, widget.worldId)
            : MiniPhoneSession(worldId: widget.worldId));
    final accountChanged =
        phone != null &&
        _miniResume.accountGeneration != null &&
        _miniResume.accountGeneration != phone!.accountGeneration;
    if (accountChanged) {
      _miniResume.liveContact = null;
      _miniResume.livePostId = null;
      _miniResume.draft = '';
      _miniResume.photo = null;
      _miniResume.viewerPhotos = null;
      _miniResume.viewerIndex = 0;
    }
    homePagerPosition = _miniResume.homePage;
    homePages = PageController(initialPage: homePagerPosition);
    screen = widget.initialScreen;
    if (accountChanged &&
        (screen == MiniPhoneScreen.chat ||
            screen == MiniPhoneScreen.comments ||
            screen == MiniPhoneScreen.create)) {
      screen = MiniPhoneScreen.home;
    }
    _launchTransition = AppLaunchTransitionController(
      initiallyOpen: screen != MiniPhoneScreen.home,
    );
    contact = _miniResume.contact;
    liveContact = _miniResume.liveContact;
    livePostId = _miniResume.livePostId;
    activePost = _miniResume.post;
    authorFilter = _miniResume.filter;
    postInput.text = phone == null ? _miniResume.draft : postDraft.text;
    draftPhoto = _miniResume.photo;
    store.addListener(_changed);
    _phoneOwner = phone?.uid;
    phone?.addListener(_changed);
    _session.postDraft?.addListener(_changed);
    if (phone != null) {
      phone!.phoneVisible = true;
      phone!.ready.then((_) {
        if (!mounted) return;
        // Warm the other apps without waiting for their network requests.
        // The visible app loads through its normal entry path below.
        if (screen != MiniPhoneScreen.messages) {
          unawaited(phone!.refreshSessions());
        }
        if (screen != MiniPhoneScreen.posts) {
          unawaited(phone!.refreshPosts());
        }
        if (screen != MiniPhoneScreen.photos) {
          unawaited(phone!.refreshAlbum());
        }
        _loadLiveScreen(screen);
      });
    }
    messageInput.addListener(_changed);
    final services =
        widget.worldId.trim().isEmpty || widget.wallpaperController != null
        ? null
        : AppServicesScope.read(context);
    wallpaper =
        widget.wallpaperController ??
        MiniPhoneWallpaperController(
          worldId: widget.worldId,
          sessionStore: services?.sessionStore ?? MemoryUserSessionStore(),
          cache: services == null
              ? null
              : LocalMiniPhoneWallpaperCache(
                  namespace: services.platformConfig.apiBaseUrl,
                ),
          load: () => services!.api.fetchMiniphoneInfo(worldId: widget.worldId),
          save: (url) => services!.api.setMiniphoneBackground(
            worldId: widget.worldId,
            backgroundImage: url,
          ),
          upload: (photo, onProgress) async {
            final uploaded = await services!.api.v1.upload.image(
              bytes: photo.bytes,
              filename: photo.filename,
              contentType: photo.contentType,
              onSendProgress: onProgress,
            );
            return GenesisImageResourceRegistry.resolve(uploaded).displayUrl;
          },
        );
    wallpaper.addListener(_changed);
    unawaited(wallpaper.refresh());
    unawaited(
      _session
          ._ensurePhoneModels()
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (phone != null) {
      phone!.phoneVisible = ModalRoute.isCurrentOf(context) ?? true;
    }
  }

  @override
  void dispose() {
    _launchTransition.dispose();
    _miniResume.accountGeneration = phone?.accountGeneration;
    _miniResume.screen = screen;
    _miniResume.contact = contact;
    _miniResume.liveContact = liveContact;
    _miniResume.livePostId = livePostId;
    _miniResume.post = activePost;
    _miniResume.filter = authorFilter;
    _miniResume.homePage = homePagerPosition;
    _miniResume.draft = postInput.text;
    _miniResume.photo = draftPhoto;
    store.removeListener(_changed);
    phone?.removeListener(_changed);
    _session.postDraft?.removeListener(_changed);
    if (phone != null) {
      phone!.phoneVisible = false;
      phone!.activeCharId = null;
      phone!.activePostId = null;
      phone!.postsVisible = false;
      phone!.notificationsVisible = false;
    }
    wallpaper.removeListener(_changed);
    if (widget.wallpaperController == null) wallpaper.dispose();
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
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  void _update(VoidCallback action) {
    if (mounted && !_session.isDisposed) setState(action);
  }

  void _changed() {
    if (phone != null && _phoneOwner != phone!.uid) {
      _phoneOwner = phone!.uid;
      liveContact = null;
      livePostId = null;
      replyToComment = null;
      draftPhoto = null;
      postInput.clear();
      commentInput.clear();
      messageInput.clear();
    }
    if (phone != null && postInput.text != postDraft.text) {
      postInput.text = postDraft.text;
    }
    if (mounted) {
      _notifyPhoneErrors();
      _update(() {});
    }
  }

  void _go(MiniPhoneScreen next) {
    if (next == screen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (next == MiniPhoneScreen.home && _launchTransition.hasPage) {
      _launchTransition.close(fallbackSourceId: _launchApp);
      return;
    }
    if (screen == MiniPhoneScreen.home && !_launchTransition.hasPage) {
      if (!_launchTransition.open()) return;
    }
    if (next == MiniPhoneScreen.models) _miniModelReturnScreen = screen;
    _update(() {
      screen = next;
      feedback = '';
    });
    if (next == MiniPhoneScreen.settings) _prepareSettings();
    if (phone != null) {
      _loadLiveScreen(next);
    } else {
      if (next == MiniPhoneScreen.posts) store.markPostsRead();
      if (next == MiniPhoneScreen.chat) _scrollToEnd(chatScroll);
    }
  }

  void _launchFrom(Object sourceId, MiniPhoneScreen app, VoidCallback open) {
    if (screen != MiniPhoneScreen.home ||
        !_launchTransition.open(sourceId: sourceId)) {
      return;
    }
    _launchApp = app;
    open();
  }

  void _launchDismissed() {
    if (!mounted) return;
    _update(() {
      screen = MiniPhoneScreen.home;
      if (phone != null) _loadLiveScreen(MiniPhoneScreen.home);
      _launchApp = null;
      feedback = '';
    });
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

  Widget _homeWallpaper() {
    if (wallpaper.cache == null) {
      return _wallpaperBackground(wallpaper.backgroundImage, null);
    }
    if (!wallpaper.cacheReady) return const ColoredBox(color: miniBackground);
    final bytes = wallpaper.displayBytes;
    final ImageProvider source = bytes == null
        ? const AssetImage('${miniPhoneAssets}wallpaper-01.png')
        : MemoryImage(bytes);
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.0, GenesisImageConfig.maxDevicePixelRatio);
    final pixels = (size.longestSide * ratio).ceil();
    return MiniPhoneWallpaperBackground(
      key: ValueKey(wallpaper.identityRevision),
      image: ResizeImage(
        source,
        width: pixels,
        height: pixels,
        policy: ResizeImagePolicy.fit,
      ),
    );
  }

  void _prepareSettings() {
    unawaited(wallpaper.beginEditing());
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
    } finally {
      if (mounted) setState(() => _authorizingWallpaper = false);
    }
  }

  void _openChat(MiniDemoPerson p) {
    if (phone != null) {
      _openLiveChat(phone!.person(p.id));
      return;
    }
    contact = p;
    typing = false;
    messageInput.clear();
    store.markRead(p);
    _go(MiniPhoneScreen.chat);
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    _launchTransition.finish();
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _back() {
    if (_launchTransition.isAnimating) {
      _launchTransition.close(fallbackSourceId: _launchApp);
      return;
    }
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
          resizeToAvoidBottomInset:
              !(phone != null && screen == MiniPhoneScreen.chat),
          body: Stack(
            children: [
              Positioned.fill(
                child: DefaultTextStyle(
                  style: miniStyle(),
                  child: AppLaunchTransitionHost(
                    controller: _launchTransition,
                    surfaceColor: miniBackground,
                    onDismissed: _launchDismissed,
                    home: _home(),
                    page: screen == MiniPhoneScreen.home
                        ? null
                        : Navigator(
                            key: _pageNavigatorKey,
                            pages: [
                              for (final destination in _pageStack(screen))
                                _MiniPhoneRoutePage(
                                  key: ValueKey((
                                    destination,
                                    destination == MiniPhoneScreen.chat
                                        ? (phone == null
                                              ? contact.id
                                              : liveContact?.id)
                                        : null,
                                  )),
                                  screen: destination,
                                  child: ColoredBox(
                                    color: miniBackground,
                                    child: _screen(destination),
                                  ),
                                ),
                            ],
                            onDidRemovePage: (page) {
                              if (page is _MiniPhoneRoutePage &&
                                  page.screen == screen) {
                                _back();
                              }
                            },
                          ),
                  ),
                ),
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

  List<MiniPhoneScreen> _pageStack(MiniPhoneScreen destination) =>
      switch (destination) {
        MiniPhoneScreen.chat => [
          MiniPhoneScreen.messages,
          MiniPhoneScreen.chat,
        ],
        MiniPhoneScreen.models => [
          ..._pageStack(_miniModelReturnScreen),
          MiniPhoneScreen.models,
        ],
        MiniPhoneScreen.comments ||
        MiniPhoneScreen.create => [MiniPhoneScreen.posts, destination],
        _ => [destination],
      };

  Widget _screen(MiniPhoneScreen destination) => switch (destination) {
    MiniPhoneScreen.home => _home(),
    MiniPhoneScreen.messages => phone == null ? _messages() : _liveMessages(),
    MiniPhoneScreen.chat =>
      phone == null
          ? _chat()
          : liveContact == null
          ? _liveMessages()
          : MiniPhoneLiveChat(
              key: ValueKey(liveContact!.id),
              store: phone!,
              person: liveContact!,
              header: _navigation(liveContact!.name, showModel: true),
            ),
    MiniPhoneScreen.posts => phone == null ? _posts() : _livePosts(),
    MiniPhoneScreen.comments => phone == null ? _comments() : _liveComments(),
    MiniPhoneScreen.create => phone == null ? _create() : _liveCreate(),
    MiniPhoneScreen.photos => phone == null ? _photos() : _livePhotos(),
    MiniPhoneScreen.settings => _settings(),
    MiniPhoneScreen.music => _panel('Music', _MiniMusicPlayer(music: _music)),
    MiniPhoneScreen.models => _models(),
  };

  Widget _navigation(String title, {bool showModel = false}) => Padding(
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
          if (showModel) ...[
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
  Widget _button(
    String text,
    VoidCallback? action, {
    bool primary = false,
    bool isLoading = false,
    bool showLoadingIndicator = false,
  }) => primary
      ? GenesisPrimaryButton(
          label: text,
          isLoading: isLoading,
          showLoadingIndicator: showLoadingIndicator,
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
    int? limit = 500,
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
