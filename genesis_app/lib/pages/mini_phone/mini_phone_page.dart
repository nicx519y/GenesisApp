import '../../l10n/genesis_localizations.dart';
import 'settings/mini_phone_settings_page.dart';
import 'home/mini_phone_home.dart';
import 'messages/mini_phone_messages_page.dart';
import 'photos/mini_phone_photos_page.dart';
import 'posts/mini_phone_posts_page.dart';
import 'shared/mini_phone_panel.dart';
import 'state/mini_phone_store.dart';
import 'posts/mini_phone_post_draft.dart';
import 'messages/mini_phone_live_chat.dart';
import '../../network/mini_phone/mini_phone_models.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/animations/app_launch_transition/app_launch_transition.dart';
import '../../ui/navigation/genesis_dark_page_route.dart';
import 'music/mini_phone_music_service.dart';
import 'settings/wallpaper/mini_phone_wallpaper_controller.dart';
import 'settings/wallpaper/mini_phone_wallpaper_cache.dart';
import 'shared/mini_phone_toast.dart';
import '../../utils/genesis_image_resource.dart';
import '../../platform/session/memory_user_session_store.dart';
import 'shared/mini_phone_ui.dart';
import '../../components/gems/memory_model_entry_button.dart';
import '../gems/memory_model_page_cache.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../platform/session/user_session_store.dart';
import '../../network/models/gem_model.dart';
import 'music/mini_phone_music.dart';
import 'settings/mini_phone_model_settings_page.dart';
import 'session/mini_phone_session.dart';
import 'session/mini_phone_screen.dart';
import 'camera/mini_phone_camera.dart';
import 'camera_l10n.dart';
import 'camera_moment_confirmation.dart';
import 'photos/mini_phone_photo_projection.dart';

/// Opens the MiniPhone attached to a live World session.
Future<void> showMiniPhone(
  BuildContext context, {
  MiniPhoneScreen? initialScreen,
  PhonePerson? initialContact,
  String worldId = '',
  String entrySource = 'unknown',
  String initialCameraPrompt = '',
  MemoryModelPageCache? modelCache,
  MiniPhoneSession? session,
}) async {
  final inherited = MiniPhoneSessionScope.read(context);
  final phone =
      session ?? inherited ?? MiniPhoneSession.forWorld(context, worldId);
  if (phone.isDisposed) return;
  final ownsSession = session == null && inherited == null;
  if (phone.data == null) {
    if (ownsSession) phone.dispose();
    return;
  }
  Future<GemModelCatalog> loadCatalog() async {
    // Phone DM has its own business catalogue; the supplied World cache must
    // neither satisfy nor coalesce this request with LocationChat.
    if (worldId.isEmpty) {
      if (phone.modelSettings.sourceCatalog != null) {
        return phone.modelSettings.sourceCatalog!;
      }
      throw StateError('Open Mini phone from a World to view its models.');
    }
    final services = AppServicesScope.read(context);
    final session = await services.sessionStore.readCompleteSession();
    if (session == null) throw StateError('Sign in to view models.');
    return services.api.v1.gem.models(worldId: worldId, biz: 'phone_dm');
  }

  phone.modelSettings.configure(worldId: worldId, loader: loadCatalog);
  try {
    if (initialContact != null && phone.data != null) {
      // Resolve the account before its initial notification can clear the target.
      await phone.data!.localReady;
      if (!context.mounted || phone.isDisposed) return;
    }
    await phone.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'mini-phone'),
        builder: (_) => MiniPhonePage(
          worldId: worldId,
          session: phone,
          initialScreen: initialScreen ?? phone.resume.screen,
          initialContact: initialContact,
          entrySource: entrySource,
          initialCameraPrompt: initialCameraPrompt,
          isRestored:
              initialScreen == null &&
              initialContact == null &&
              phone.resume.accountGeneration != null,
        ),
      ),
    );
  } finally {
    if (ownsSession) phone.dispose();
  }
}

/// Uses the same platform route transitions as the rest of the app.
class _MiniPhoneRoutePage extends Page<void> {
  const _MiniPhoneRoutePage({
    required this.screen,
    required this.child,
    this.launchBackGesture = false,
    required super.key,
  });
  final MiniPhoneScreen screen;
  final Widget child;
  final bool launchBackGesture;

  @override
  Route<void> createRoute(BuildContext context) => launchBackGesture
      ? _MiniPhoneAppRootRoute(
          settings: this,
          builder: (context) =>
              (ModalRoute.of(context)!.settings as _MiniPhoneRoutePage).child,
        )
      : GenesisDarkPageRoute<void>(
          settings: this,
          builder: (context) =>
              (ModalRoute.of(context)!.settings as _MiniPhoneRoutePage).child,
        );
}

/// The launch host owns root-app edge drags. Never run a second Cupertino
/// slide on the same gesture; subpages keep GenesisDarkPageRoute unchanged.
class _MiniPhoneAppRootRoute extends GenesisDarkPageRoute<void> {
  _MiniPhoneAppRootRoute({required super.settings, required super.builder});
  @override
  bool get popGestureEnabled => false;
}

class _MiniPhoneNavigatorObserver extends NavigatorObserver {
  _MiniPhoneNavigatorObserver(this.onPopped);
  final void Function(MiniPhoneScreen) onPopped;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final page = route.settings;
    if (page is! _MiniPhoneRoutePage || route is! TransitionRoute<dynamic>) {
      return;
    }
    // Do not tear down the launch surface halfway through a Cupertino pop or
    // start a second reverse animation after the interactive gesture finishes.
    unawaited(route.completed.then((_) => onPopped(page.screen)));
  }
}

class MiniPhonePage extends StatefulWidget {
  const MiniPhonePage({
    super.key,
    this.initialScreen = MiniPhoneScreen.home,
    this.initialContact,
    this.initialCameraPrompt = '',
    this.entrySource = 'unknown',
    this.isRestored = false,
    this.worldId = '',
    this.wallpaperController,
    this.session,
  });
  final MiniPhoneSession? session;

  /// Route-local observation only; no private messages enter the World stream.
  final MiniPhoneScreen initialScreen;
  final PhonePerson? initialContact;
  final String initialCameraPrompt;
  final String entrySource;
  final bool isRestored;
  final String worldId;
  final MiniPhoneWallpaperController? wallpaperController;
  @override
  State<MiniPhonePage> createState() => _MiniPhonePageState();
}

class _MiniPhonePageState extends State<MiniPhonePage> {
  late final MiniPhoneSession _session;
  late final bool _ownsSession;
  MiniPhoneStore? get phone => _session.data;
  PhonePerson? liveContact;
  int? livePostId;
  MiniPhonePostDraft get postDraft => _session.postDraft!;
  String? _phoneOwner;
  bool _cameraSeedApplied = false;
  final _cameraAlbumProjection = MiniPhonePhotoProjection();

  MiniPhoneMusicService get _music => _session.music;
  MiniPhoneResume get _miniResume => _session.resume;
  MiniPhoneScreen get _miniModelReturnScreen => _session.modelReturnScreen;
  set _miniModelReturnScreen(MiniPhoneScreen value) =>
      _session.modelReturnScreen = value;
  String get _miniPhoneModelLabel => _session.modelSettings.label;
  late MiniPhoneScreen screen;
  final _pageNavigatorKey = GlobalKey<NavigatorState>();
  late final _pageNavigatorObserver = _MiniPhoneNavigatorObserver(
    _internalPagePopped,
  );
  late final AppLaunchTransitionController _launchTransition;
  MiniPhoneScreen? _launchApp;
  bool _closing = false;
  bool _readPostNotificationsOnEntry = false;
  String? _analyticsOpenId;
  bool _openTracked = false;
  Object? _trackedPage;
  String? _launchSource;
  int _pageTrackRevision = 0;

  void _trackPage({
    required String source,
    String from = '',
    String navigation = 'push',
  }) {
    final revision = ++_pageTrackRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final data = phone;
      if (data == null) return;
      await data.localReady;
      if (!mounted ||
          _closing ||
          revision != _pageTrackRevision ||
          data.requests.disposed ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      final identity = (
        screen,
        screen == MiniPhoneScreen.chat ? liveContact?.id : null,
        screen == MiniPhoneScreen.comments ? livePostId : null,
      );
      if (identity == _trackedPage || data.uid == null) return;
      _trackedPage = identity;
      final analytics = data.analytics;
      _analyticsOpenId ??= analytics.beginOpen();
      if (!_openTracked) {
        _openTracked = true;
        analytics.event(
          'open',
          target: screen.name,
          stage: 'open',
          data: {
            ...analytics.context(widget.entrySource),
            'is_restored': widget.isRestored,
          },
        );
        source = widget.entrySource;
        from = '';
        navigation = 'initial';
      }
      analytics.event(
        'page',
        type: 'pageview',
        target: screen.name,
        stage: 'view',
        data: {
          ...analytics.context(source),
          'from_page': from,
          'navigation_type': navigation,
          if (screen == MiniPhoneScreen.chat && liveContact != null)
            'char_id': liveContact!.id,
          if (screen == MiniPhoneScreen.comments && livePostId != null)
            'post_id': '$livePostId',
        },
      );
    });
  }

  late final MiniPhoneWallpaperController wallpaper;
  final _shownPhoneErrors = <String, String>{};
  bool _phoneErrorToastScheduled = false;

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
    }
    screen = widget.initialContact != null
        ? MiniPhoneScreen.chat
        : widget.initialScreen;
    if (accountChanged &&
        widget.initialContact == null &&
        (screen == MiniPhoneScreen.chat ||
            screen == MiniPhoneScreen.comments ||
            screen == MiniPhoneScreen.create)) {
      screen = MiniPhoneScreen.home;
    }
    _launchTransition = AppLaunchTransitionController(
      initiallyOpen: screen != MiniPhoneScreen.home,
    );
    liveContact = widget.initialContact ?? _miniResume.liveContact;
    livePostId = _miniResume.livePostId;
    _phoneOwner = phone?.uid;
    phone?.addListener(_changed);
    _session.postDraft?.addListener(_changed);
    if (phone != null) {
      phone!.phoneVisible = true;
      unawaited(phone!.retryInitialization());
      phone!.localReady.then((_) {
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
    wallpaper.analytics = phone?.analytics;
    wallpaper.addListener(_changed);
    _trackPage(source: widget.entrySource, navigation: 'initial');
    unawaited(wallpaper.refresh());
    unawaited(_ensureModelsLoaded(showFailure: false));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshMusicLikes());
    });
  }

  Future<void> _ensureModelsLoaded({bool showFailure = true}) async {
    final generation = phone?.accountGeneration;
    try {
      await _session.modelSettings.ensureLoaded();
      if (mounted &&
          !_session.isDisposed &&
          generation == phone?.accountGeneration) {
        setState(() {});
      }
    } catch (error) {
      if (showFailure &&
          mounted &&
          !_session.isDisposed &&
          generation == phone?.accountGeneration &&
          screen == MiniPhoneScreen.chat) {
        showMiniPhoneToast(context, MiniPhoneStore.errorText(error));
      }
    }
  }

  Future<void> _refreshMusicLikes() async {
    final api = AppServicesScope.read(context).api;
    await _music.refreshLikes(api.fetchMusicCatalog);
    if (!mounted || screen == MiniPhoneScreen.music) return;
    final error = _music.catalogError;
    if (error != null) showMiniPhoneToast(context, error);
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
    phone?.analytics.endOpen(_analyticsOpenId);
    _launchTransition.dispose();
    _miniResume.accountGeneration = phone?.accountGeneration;
    _miniResume.screen = screen;
    _miniResume.liveContact = liveContact;
    _miniResume.livePostId = livePostId;
    phone?.removeListener(_changed);
    _session.postDraft?.removeListener(_changed);
    _session.camera?.close();
    if (phone != null) {
      phone!.phoneVisible = false;
      phone!.activeCharId = null;
      phone!.activePostId = null;
      phone!.postsVisible = false;
      phone!.notificationsVisible = false;
    }
    wallpaper.removeListener(_changed);
    if (widget.wallpaperController == null) wallpaper.dispose();
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  void _update(VoidCallback action) {
    if (mounted && !_session.isDisposed) setState(action);
  }

  void _changed() {
    final identityChanged = phone != null && _phoneOwner != phone!.uid;
    if (identityChanged) {
      if (_phoneOwner != null) {
        _session.modelSettings.clear();
        phone!.analytics.endOpen(_analyticsOpenId);
        _analyticsOpenId = null;
        _openTracked = false;
        _trackedPage = null;
      }
      _phoneOwner = phone!.uid;
      liveContact = null;
      livePostId = null;
      _readPostNotificationsOnEntry = false;
    }
    if (mounted) {
      _notifyPhoneErrors();
      if (identityChanged) {
        _update(() {});
        _trackPage(source: 'restore', navigation: 'replace');
      }
    }
  }

  void _go(MiniPhoneScreen next, {String? source, String navigation = 'push'}) {
    final from = screen.name;
    final origin = _launchSource ?? source ?? 'header';
    if (next == screen) {
      _trackPage(source: origin, from: from, navigation: 'replace');
      return;
    }
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
    });
    _trackPage(source: origin, from: from, navigation: navigation);
    if (next == MiniPhoneScreen.settings) _prepareSettings();
    if (phone != null) {
      _loadLiveScreen(next);
    }
  }

  void _launchFrom(Object sourceId, MiniPhoneScreen app, VoidCallback open) {
    if (screen != MiniPhoneScreen.home ||
        !_launchTransition.open(sourceId: sourceId)) {
      return;
    }
    _launchApp = app;
    _launchSource = sourceId is MiniPhoneScreen
        ? 'home_icon'
        : sourceId == 'home-music-card'
        ? 'home_music_card'
        : 'home_notification';
    try {
      open();
    } finally {
      _launchSource = null;
    }
  }

  void _launchDismissed() {
    if (!mounted) return;
    final from = screen.name;
    _update(() {
      screen = MiniPhoneScreen.home;
      if (phone != null) _loadLiveScreen(MiniPhoneScreen.home);
      _launchApp = null;
    });
    _trackPage(source: 'back', from: from, navigation: 'back');
  }

  void _prepareSettings() {
    unawaited(wallpaper.beginEditing());
  }

  void _close() {
    if (!mounted || _closing) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    final navigator = Navigator.of(context);
    setState(() => _closing = true);
    FocusManager.instance.primaryFocus?.unfocus();
    _launchTransition.finish();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route.isCurrent) {
        navigator.pop();
      } else if (route.isActive) {
        setState(() => _closing = false);
      }
    });
  }

  void _back() {
    if (!mounted || _closing) return;
    if (_launchTransition.isAnimating) {
      _launchTransition.close(fallbackSourceId: _launchApp);
      return;
    }
    switch (screen) {
      case MiniPhoneScreen.home:
        _close();
      case MiniPhoneScreen.models:
        _go(_miniModelReturnScreen, source: 'back', navigation: 'back');
      case MiniPhoneScreen.chat:
        if (widget.initialContact != null) {
          _close();
        } else {
          _go(MiniPhoneScreen.messages, source: 'back', navigation: 'back');
        }
      case MiniPhoneScreen.comments:
      case MiniPhoneScreen.create:
        _go(MiniPhoneScreen.posts, source: 'back', navigation: 'back');
      default:
        _go(MiniPhoneScreen.home, source: 'back', navigation: 'back');
    }
  }

  void _internalPagePopped(MiniPhoneScreen poppedScreen) {
    if (!mounted || _closing || screen != poppedScreen) return;
    if (_pageStack(screen).length == 1 && widget.initialContact == null) {
      // The route already supplied the complete interactive return animation.
      _launchTransition.close(fallbackSourceId: _launchApp);
      _launchTransition.finish();
    } else {
      _back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          _closing ||
          screen == MiniPhoneScreen.home ||
          (widget.initialContact != null && screen == MiniPhoneScreen.chat),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _closing = true;
        } else {
          _back();
        }
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
              !(screen == MiniPhoneScreen.camera ||
                  (phone != null && screen == MiniPhoneScreen.chat)),
          body: Stack(
            children: [
              Positioned.fill(
                child: DefaultTextStyle(
                  style: miniStyle(),
                  child: AppLaunchTransitionHost(
                    controller: _launchTransition,
                    surfaceColor: miniBackground,
                    onDismissed: _launchDismissed,
                    pageHasTransparentBackground: widget.initialContact == null,
                    enableCloseGesture:
                        Theme.of(context).platform == TargetPlatform.iOS &&
                        widget.initialContact == null &&
                        !_closing &&
                        _pageStack(screen).length == 1,
                    closeGestureFallbackSourceId: _launchApp,
                    home: _home(),
                    page: screen == MiniPhoneScreen.home
                        ? null
                        : Navigator(
                            key: _pageNavigatorKey,
                            observers: [_pageNavigatorObserver],
                            pages: [
                              // This is the desktop's navigation position, not
                              // a second Home widget. The launch host paints
                              // the existing desktop below this empty route.
                              if (widget.initialContact == null)
                                const _MiniPhoneRoutePage(
                                  key: ValueKey('mini-phone-desktop-route'),
                                  screen: MiniPhoneScreen.home,
                                  child: SizedBox.expand(),
                                ),
                              for (final destination in _pageStack(screen))
                                _MiniPhoneRoutePage(
                                  key: ValueKey((
                                    destination,
                                    destination == MiniPhoneScreen.chat
                                        ? liveContact?.id
                                        : null,
                                  )),
                                  screen: destination,
                                  launchBackGesture:
                                      Theme.of(context).platform ==
                                          TargetPlatform.iOS &&
                                      widget.initialContact == null &&
                                      destination == _pageStack(screen).first,
                                  child: ColoredBox(
                                    color: miniBackground,
                                    child: _screen(destination),
                                  ),
                                ),
                            ],
                            // didPop above waits for the platform transition.
                            // Declarative removals already update `screen`.
                            onDidRemovePage: (_) {},
                          ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 14,
                right: miniPageInset,
                child: MiniIconButton(
                  'close',
                  context.l10n.miniPhoneClose,
                  _closing ? null : _close,
                ),
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
          if (widget.initialContact == null) MiniPhoneScreen.messages,
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

  Widget _home() => MiniPhoneHome(
    session: _session,
    wallpaper: wallpaper,
    onNavigate: _go,
    onLaunch: _launchFrom,
    onOpenLiveChat: _openLiveChat,
    onOpenComments: (id) => _openLivePost(id, fromNotification: true),
  );

  Widget _screen(MiniPhoneScreen destination) => switch (destination) {
    MiniPhoneScreen.home => _home(),
    MiniPhoneScreen.messages =>
      phone == null
          ? _emptyApp(destination)
          : MiniPhoneMessagesPage(
              store: phone!,
              header: _navigation(context.l10n.miniPhoneMessages),
              onOpenChat: _openLiveChat,
            ),
    MiniPhoneScreen.chat =>
      phone == null
          ? _emptyApp(destination)
          : liveContact == null
          ? MiniPhoneMessagesPage(
              store: phone!,
              header: _navigation(context.l10n.miniPhoneMessages),
              onOpenChat: _openLiveChat,
            )
          : MiniPhoneLiveChat(
              key: ValueKey(liveContact!.id),
              store: phone!,
              person: liveContact!,
              header: _navigation(liveContact!.name, showModel: true),
            ),
    MiniPhoneScreen.posts =>
      phone == null ? _emptyApp(destination) : _postsPage(destination),
    MiniPhoneScreen.comments =>
      phone == null ? _emptyApp(destination) : _postsPage(destination),
    MiniPhoneScreen.create =>
      phone == null ? _emptyApp(destination) : _postsPage(destination),
    MiniPhoneScreen.photos =>
      phone == null
          ? _emptyApp(destination)
          : MiniPhonePhotosPage(
              store: phone!,
              header: _navigation(context.l10n.miniPhonePhotos),
            ),
    MiniPhoneScreen.camera => _cameraPage(),
    MiniPhoneScreen.settings => MiniPhoneSettingsPage(
      session: _session,
      wallpaper: wallpaper,
      header: _navigation(context.l10n.miniPhoneSettings),
      active: screen == MiniPhoneScreen.settings,
      onApplied: () {
        if (!mounted ||
            _closing ||
            screen != MiniPhoneScreen.settings ||
            ModalRoute.isCurrentOf(context) == false) {
          return;
        }
        _go(MiniPhoneScreen.home, source: 'settings', navigation: 'back');
      },
    ),
    MiniPhoneScreen.music => _panel(
      context.l10n.miniPhoneMusic,
      MiniPhoneMusicPlayer(music: _music),
    ),
    MiniPhoneScreen.models => MiniPhoneModelSettingsPage(
      settings: _session.modelSettings,
      analytics: phone?.analytics,
      onBack: _back,
    ),
  };

  Widget _cameraPage() {
    final data = phone;
    final controller = _session.camera;
    if (data == null || controller == null) {
      return _panel(context.l10n.miniPhoneCamera, const SizedBox.shrink());
    }
    // Refresh camera inputs without rebuilding the phone's Navigator or routes.
    return ListenableBuilder(
      listenable: data,
      builder: (_, _) => _cameraSnapshot(data, controller),
    );
  }

  Widget _cameraSnapshot(
    MiniPhoneStore data,
    MiniPhoneCameraController controller,
  ) {
    controller.bindScope(
      MiniPhoneCameraScope(
        environment: data.namespace,
        accountId: data.uid ?? '',
        worldId: widget.worldId,
      ),
      // The rebuilt page receives the new scope; do not notify during build.
      notify: false,
    );
    final initialPrompt = !_cameraSeedApplied && data.uid != null
        ? widget.initialCameraPrompt
        : '';
    if (data.uid != null) _cameraSeedApplied = true;
    final album = _cameraAlbumProjection.resolve(
      data.album,
      data.worldCoverImageKeys,
    );
    return MiniPhoneCameraPage(
      key: ValueKey(('camera', data.accountGeneration)),
      header: _navigation(context.l10n.miniPhoneCamera),
      people: data.people.values.toList(growable: false),
      strings: miniPhoneCameraStrings(context),
      controller: controller,
      coverImageUrl: GenesisImageResourceRegistry.resolve(
        data.cameraWorldDetail?.cover ?? '',
      ).displayUrl,
      initialPrompt: initialPrompt,
      onOpenAlbum: () => _go(MiniPhoneScreen.photos, source: 'camera'),
      albumLabel: context.l10n.miniPhonePhotos,
      albumThumbnailUrl: album.firstOrNull?.thumbnail.trim().isNotEmpty == true
          ? album.first.thumbnail
          : album.firstOrNull?.image,
      onCaptureRequested: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        final revision = data.accountGeneration;
        final uid = data.uid;
        if (uid == null) return;
        final confirmed = await confirmCameraMoment(
          context,
          preferenceScope:
              '${Uri.encodeComponent(data.namespace)}:${Uri.encodeComponent(uid)}',
          // While generation is not wired, this action previews its explanation
          // even if it was remembered from the chat entry.
          forceShow: true,
        );
        if (!mounted ||
            _closing ||
            _session.isDisposed ||
            screen != MiniPhoneScreen.camera ||
            revision != data.accountGeneration ||
            !confirmed) {
          return;
        }
        showMiniPhoneToast(context, context.l10n.miniPhoneComingSoon);
      },
      selfPersonKey: data.people.values
          .where((person) => data.playerCharIds.contains(person.id))
          .firstOrNull
          ?.key,
    );
  }

  Widget _emptyApp(MiniPhoneScreen destination) => _panel(switch (destination) {
    MiniPhoneScreen.messages ||
    MiniPhoneScreen.chat => context.l10n.miniPhoneMessages,
    MiniPhoneScreen.photos => context.l10n.miniPhonePhotos,
    MiniPhoneScreen.comments => context.l10n.miniPhoneComments,
    MiniPhoneScreen.create => context.l10n.miniPhoneCreatePost,
    _ => context.l10n.miniPhonePosts,
  }, const SizedBox.shrink());

  Widget _postsPage(MiniPhoneScreen destination) => MiniPhonePostsPage(
    session: _session,
    screen: destination,
    active: screen == destination,
    postId: livePostId,
    readNotificationsOnEntry: _readPostNotificationsOnEntry,
    header: _navigation(switch (destination) {
      MiniPhoneScreen.comments => context.l10n.miniPhoneComments,
      MiniPhoneScreen.create => context.l10n.miniPhoneCreatePost,
      _ => context.l10n.miniPhonePosts,
    }),
    onBack: _back,
    onCreate: () => _go(MiniPhoneScreen.create),
    onPublished: () =>
        _go(MiniPhoneScreen.posts, source: 'back', navigation: 'back'),
    onOpenPost: _openLivePost,
  );

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
  }) => miniPhonePanel(
    _navigation(title),
    body,
    subtitle: subtitle,
    footer: footer,
  );
  void _loadLiveScreen(MiniPhoneScreen next) {
    final data = phone!;
    data.activeCharId = next == MiniPhoneScreen.chat ? liveContact?.id : null;
    data.activePostId = next == MiniPhoneScreen.comments ? livePostId : null;
    data.postsVisible = next == MiniPhoneScreen.posts;
    data.notificationsVisible = false;
    data.albumVisible = next == MiniPhoneScreen.photos;
    switch (next) {
      case MiniPhoneScreen.home:
        data.scheduleRefresh(recoverChats: false);
      case MiniPhoneScreen.messages:
        data.unreadSessionsOnly = false;
        unawaited(data.refreshSessions());
        unawaited(data.refreshPeople());
      case MiniPhoneScreen.chat:
        // The chat owns its initial history request.
        unawaited(_ensureModelsLoaded());
      case MiniPhoneScreen.posts:
        unawaited(data.refreshPosts(markRead: true));
      case MiniPhoneScreen.comments:
        // The detail page owns entry reads after capturing the feed snapshot.
        break;
      case MiniPhoneScreen.photos:
        unawaited(data.refreshAlbum());
      default:
        break;
    }
  }

  void _openLiveChat(PhonePerson p) {
    liveContact = p;
    _go(MiniPhoneScreen.chat, source: 'messages_list');
  }

  void _openLivePost(int id, {bool fromNotification = false}) {
    livePostId = id;
    _readPostNotificationsOnEntry = fromNotification;
    _go(MiniPhoneScreen.comments, source: 'posts_feed');
  }

  Map<String, String> get _visiblePhoneErrors {
    final data = phone;
    final errors = <String, String>{};
    if (_session.isDisposed ||
        data != null && (!data.phoneVisible || !data.foreground)) {
      return errors;
    }
    final keys = [
      'cache',
      'journal',
      'identity',
      ...switch (screen) {
        MiniPhoneScreen.home => ['home', 'unread', 'people', 'postSummary'],
        MiniPhoneScreen.messages => ['sessions', 'people'],
        MiniPhoneScreen.posts => [
          'posts',
          'postAuthors',
          'postSummary',
          'readPosts',
          for (final p in data?.posts ?? <PhonePost>[]) 'like:${p.id}',
        ],
        MiniPhoneScreen.comments => [
          'readPosts',
          'postSummary',
          'detail:$livePostId',
          'comments:$livePostId',
          'comment:$livePostId',
          'like:$livePostId',
        ],
        MiniPhoneScreen.create => ['post:new'],
        MiniPhoneScreen.photos => ['album'],
        _ => <String>[],
      },
    ];
    if (data != null) {
      // Wait for the two Messages requests so a shared failure is shown once.
      final messagesLoading =
          screen == MiniPhoneScreen.messages &&
          (data.busy.contains('sessions') || data.busy.contains('people'));
      if (!messagesLoading) {
        for (final key in keys) {
          final message = data.errors[key];
          if (message != null && !data.busy.contains(key)) {
            errors['${screen.name}:$key'] = message;
          }
        }
      }
    }
    if (phone != null &&
        screen == MiniPhoneScreen.create &&
        postDraft.error != null) {
      errors['post-photo'] = postDraft.error!;
    }
    if (screen == MiniPhoneScreen.settings &&
        !wallpaper.loading &&
        wallpaper.loadError != null) {
      errors['wallpaper'] = wallpaper.loadError!;
    }
    return errors;
  }

  void _notifyPhoneErrors() {
    final current = _visiblePhoneErrors;
    _shownPhoneErrors.removeWhere((key, value) => current[key] != value);
    if (current.isEmpty || _phoneErrorToastScheduled) return;
    _phoneErrorToastScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneErrorToastScheduled = false;
      if (!mounted || _session.isDisposed) return;
      final errors = _visiblePhoneErrors;
      final shown = _shownPhoneErrors.values.toSet();
      final fresh = errors.entries
          .where(
            (entry) =>
                _shownPhoneErrors[entry.key] != entry.value &&
                !shown.contains(entry.value),
          )
          .map((entry) => miniPhoneToastMessage(entry.value))
          .where((message) => message.trim().isNotEmpty)
          .toSet();
      _shownPhoneErrors.addAll(errors);
      if (fresh.isNotEmpty) showMiniPhoneToast(context, fresh.join('\n'));
    });
  }
}
