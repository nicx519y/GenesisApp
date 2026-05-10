import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/me/profile_collection_list.dart';
import '../../network/genesis_api.dart';
import '../../routers/app_router.dart';
import 'settings_page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key, this.onLoggedOut});

  final VoidCallback? onLoggedOut;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> with SingleTickerProviderStateMixin {
  static const _nicknameKey = 'me_nickname_override_v1';

  late final TabController _tabController;
  late Future<_MeDataVm> _future;
  final GenesisApi _api = GenesisApi();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_MeDataVm> _loadData() async {
    final profile = await _api.bindDevice();
    final code = await _api.getDisplayUserCode();
    final prefs = await SharedPreferences.getInstance();
    final nicknameOverride = (prefs.getString(_nicknameKey) ?? '').trim();
    final displayName = nicknameOverride.isNotEmpty
        ? nicknameOverride
        : (profile.nickname.trim().isEmpty ? 'User' : profile.nickname.trim());

    final originPage = await _api.getMyLaunchedOrigins(limit: 30, offset: 0);
    final worlds = await _api.getMyWorlds(limit: 30, offset: 0);

    final origins = originPage.data
        .map(
          (item) => _OriginListItemVm(
            originId: item.id,
            oid: item.oid,
            title: item.name.trim().isEmpty ? item.oid : item.name.trim(),
            subtitle: item.description.trim().isEmpty
                ? 'No description'
                : item.description.trim(),
            imageUrl: resolveAssetUrl(item.mapImage),
          ),
        )
        .toList(growable: false);

    final worldItems = worlds
        .map(
          (item) => _WorldListItemVm(
            wid: item.wid,
            title: item.name.trim().isEmpty ? item.wid : item.name.trim(),
            subtitle: 'Updated: ${item.updatedAtText}',
            imageUrl: resolveAssetUrl(item.snapshotCoverUrl),
          ),
        )
        .toList(growable: false);

    return _MeDataVm(
      avatarUrl: profile.avatar.trim(),
      displayName: displayName,
      uid: code.trim().isEmpty ? profile.uid : code,
      origins: origins,
      worlds: worldItems,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  Future<void> _editName(_MeDataVm current) async {
    final controller = TextEditingController(text: current.displayName);
    final next = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit username'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Username'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (next == null) return;
    if (next.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Username cannot be empty')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, next.trim());
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _copyUid(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('UID copied')));
  }

  Future<void> _openSettings() async {
    final loggedOut = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const SettingsPage()));
    if (loggedOut == true) {
      widget.onLoggedOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MeDataVm>(
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
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings, size: 34),
                      color: Colors.black,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(url: data.avatarUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _editName(data),
                                icon: const Icon(Icons.edit, size: 22),
                                color: const Color(0xFF595959),
                                splashRadius: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'UID: ${data.uid}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF6F6F6F),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _copyUid(data.uid),
                                icon: const Icon(Icons.copy, size: 24),
                                color: const Color(0xFF6F6F6F),
                                splashRadius: 22,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.black,
                    unselectedLabelColor: const Color(0xFF6F6F6F),
                    labelStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    indicatorColor: const Color(0xFFFF4D4F),
                    indicatorWeight: 4,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Origin'),
                      Tab(text: 'World'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ProfileCollectionList(
                        items: data.origins
                            .map(
                              (item) => ProfileCollectionItemVm(
                                imageUrl: item.imageUrl,
                                title: item.title,
                                subtitle: item.subtitle,
                                onTap: () => Navigator.of(context).pushNamed(
                                  RouteNames.originWorld,
                                  arguments: {
                                    'originId': item.originId,
                                    'oid': item.oid,
                                  },
                                ),
                              ),
                            )
                            .toList(growable: false),
                        emptyText: 'No Origins you created yet.',
                      ),
                      ProfileCollectionList(
                        items: data.worlds
                            .map(
                              (item) => ProfileCollectionItemVm(
                                imageUrl: item.imageUrl,
                                title: item.title,
                                subtitle: item.subtitle,
                                onTap: () => Navigator.of(context).pushNamed(
                                  RouteNames.world,
                                  arguments: {'wid': item.wid},
                                ),
                              ),
                            )
                            .toList(growable: false),
                        emptyText: 'No Worlds you created yet.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _AvatarImage(url: url),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.open_in_full,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isNotEmpty) {
      return Image.network(
        url,
        width: 112,
        height: 112,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 112,
      height: 112,
      color: const Color(0xFFE6E6E6),
      alignment: Alignment.center,
      child: const Icon(Icons.person, size: 50, color: Color(0xFF9C9C9C)),
    );
  }
}

class _MeDataVm {
  const _MeDataVm({
    required this.avatarUrl,
    required this.displayName,
    required this.uid,
    required this.origins,
    required this.worlds,
  });

  final String avatarUrl;
  final String displayName;
  final String uid;
  final List<_OriginListItemVm> origins;
  final List<_WorldListItemVm> worlds;
}

class _OriginListItemVm {
  const _OriginListItemVm({
    required this.originId,
    required this.oid,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final int originId;
  final String oid;
  final String title;
  final String subtitle;
  final String imageUrl;
}

class _WorldListItemVm {
  const _WorldListItemVm({
    required this.wid,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String wid;
  final String title;
  final String subtitle;
  final String imageUrl;
}
