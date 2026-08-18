import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../components/me/signed_out_me_view.dart';
import '../../components/me/user_profile_content.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/origin.dart';
import '../../platform/auth/auth_cancelled_exception.dart';
import '../../platform/auth/auth_session.dart';
import '../../platform/session/user_session_store.dart';
import '../../platform/session/user_info_cache.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/image_format_guards.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/genesis_page_title.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/text/genesis_text_input_formatters.dart';
import 'settings_page.dart';

part 'me_page_data.dart';
part 'me_page_actions.dart';
part 'me_page_models.dart';
part 'me_page_nickname.dart';

@visibleForTesting
const Size meProfileAvatarUploadSize = Size.square(1080);

class MePage extends StatefulWidget {
  const MePage({
    super.key,
    this.onLoggedOut,
    this.onLogin,
    this.onLoginCompleted,
    this.activationListenable,
    this.isActiveListenable,
  });

  final VoidCallback? onLoggedOut;
  final Future<bool> Function(IdentityProvider provider)? onLogin;
  final Future<void> Function()? onLoginCompleted;
  final ValueListenable<int>? activationListenable;
  final ValueListenable<bool>? isActiveListenable;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  static final Uri _discordUri = Uri.parse('https://discord.gg/wuKHk7cyX7');

  late Future<_MePageContent> _future;
  final ValueNotifier<bool> _isUpdatingProfile = ValueNotifier<bool>(false);
  final ValueNotifier<String> _avatarUrl = ValueNotifier<String>('');
  final ValueNotifier<String> _displayName = ValueNotifier<String>('');
  IdentityProvider? _loggingInProvider;
  final ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>>
  _originsState =
      ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>>(
        const UserProfileCollectionState<UserProfileOriginItem>(
          items: <UserProfileOriginItem>[],
          isLoading: false,
        ),
      );
  final ValueNotifier<UserProfileCollectionState<UserProfileWorldItem>>
  _worldsState =
      ValueNotifier<UserProfileCollectionState<UserProfileWorldItem>>(
        const UserProfileCollectionState<UserProfileWorldItem>(
          items: <UserProfileWorldItem>[],
          isLoading: false,
        ),
      );
  int _loadGeneration = 0;
  bool _profileCollapsed = false;
  bool _isActivationRefreshing = false;
  bool _hasPendingActivationRefresh = false;
  int _selectedCollectionTabIndex = 0;
  ValueListenable<int>? _sessionRevisionListenable;
  // Extension method tear-offs are not equal across reads, so listener
  // registration and removal must reuse these stable callback objects.
  late final VoidCallback _tabActivatedListener;
  late final VoidCallback _recentChatChangedListener;
  late final VoidCallback _sessionChangedListener;
  bool _isDisposed = false;
  String _recentChatUid = '';
  String _recentChatWorldId = '';

  @override
  void initState() {
    super.initState();
    _tabActivatedListener = _handleTabActivated;
    _recentChatChangedListener = _handleRecentChatChanged;
    _sessionChangedListener = _handleSessionChanged;
    _future = _loadData();
    widget.activationListenable?.addListener(_tabActivatedListener);
    recentWorldChatStore.listenable.addListener(_recentChatChangedListener);
  }

  @override
  void didUpdateWidget(covariant MePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationListenable != widget.activationListenable) {
      oldWidget.activationListenable?.removeListener(_tabActivatedListener);
      widget.activationListenable?.addListener(_tabActivatedListener);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionRevision = AppServicesScope.of(context).sessionRevision;
    if (identical(_sessionRevisionListenable, sessionRevision)) return;
    _sessionRevisionListenable?.removeListener(_sessionChangedListener);
    _sessionRevisionListenable = sessionRevision;
    sessionRevision.addListener(_sessionChangedListener);
    unawaited(_loadRecentChatMarker());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _loadGeneration += 1;
    _sessionRevisionListenable?.removeListener(_sessionChangedListener);
    recentWorldChatStore.listenable.removeListener(_recentChatChangedListener);
    widget.activationListenable?.removeListener(_tabActivatedListener);
    _isUpdatingProfile.dispose();
    _avatarUrl.dispose();
    _displayName.dispose();
    _originsState.dispose();
    _worldsState.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback callback) => setState(callback);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MePageContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Load failed'),
                const SizedBox(height: 8),
                GenesisButton(
                  label: 'Retry',
                  onPressed: _refresh,
                  size: GenesisButtonSize.compact,
                  fullWidth: false,
                ),
              ],
            ),
          );
        }

        final content = snapshot.data;
        if (content == null) {
          return const SizedBox.shrink();
        }
        if (!content.isSignedIn) {
          return SignedOutMeView(
            loggingInProvider: _loggingInProvider,
            onLogin: _login,
          );
        }
        final data = content.data!;
        final gemWalletState = AppServicesScope.of(context).gemWallet.state;

        return GenesisTopSafeArea(
          backgroundColor: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: _profileCollapsed ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: const GenesisPageTitle(text: 'Me'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _openDiscord,
                            icon: SvgPicture.asset(
                              'assets/custom-icons/svg/discord-svgrepo-com.svg',
                              width: 30,
                              height: 30,
                            ),
                          ),
                          IconButton(
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings, size: 24),
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UserProfileContent(
                  data: data,
                  originsListenable: _originsState,
                  worldsListenable: _worldsState,
                  avatarUrlListenable: _avatarUrl,
                  displayNameListenable: _displayName,
                  isUpdatingProfileListenable: _isUpdatingProfile,
                  gemWalletStateListenable: gemWalletState,
                  onEditAvatar: _editAvatar,
                  onEditDisplayName: _editNickName,
                  onRefreshOrigins: _refreshOrigins,
                  onRefreshWorlds: _refreshWorlds,
                  onWorldDeleted: _handleWorldDeleted,
                  onCollectionTabChanged: _handleCollectionTabChanged,
                  onCollapsedChanged: _handleProfileCollapsedChanged,
                  recentChatWorldId: _recentChatWorldId,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleWorldDeleted(UserProfileWorldItem item) {
    final worldId = item.wid.trim();
    if (worldId.isEmpty) return;
    final current = _worldsState.value;
    final nextItems = current.items
        .where((world) => world.wid.trim() != worldId)
        .toList(growable: false);
    _setWorldsState(nextItems, isLoading: current.isLoading);
  }
}
