import 'dart:typed_data';
import '../../../platform/session/user_session_store.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/bootstrap/app_services_scope.dart';
import '../../../network/models/music.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../music/mini_phone_music_service.dart';
import '../music/mini_phone_music_progress.dart';
import '../posts/mini_phone_post_draft.dart';
import '../preview/mini_phone_demo_store.dart';
import '../preview/mini_phone_preview_photo.dart';
import '../settings/mini_phone_model_settings.dart';
import '../state/mini_phone_store.dart';
import 'mini_phone_screen.dart';

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
  final resume = MiniPhoneResume();
  final _routes = <Route<dynamic>, NavigatorState>{};
  bool _disposed = false;
  bool get isDisposed => _disposed;
  MiniPhoneScreen modelReturnScreen = MiniPhoneScreen.chat;
  final modelSettings = MiniPhoneModelSettings();

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
    modelSettings.dispose();
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

class MiniPhoneResume {
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
  List<MiniPhonePreviewPhoto>? viewerPhotos;
  int viewerIndex = 0;
}
