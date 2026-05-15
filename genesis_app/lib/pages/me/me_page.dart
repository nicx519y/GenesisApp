import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/me/profile_collection_list.dart';
import '../../network/genesis_api.dart';
import '../../routers/app_router.dart';
import '../../ui/genesis_ui.dart';
import 'settings_page.dart';
import '../../app/bootstrap/app_services_scope.dart';

class MePage extends StatefulWidget {
  const MePage({super.key, this.onLoggedOut});

  final VoidCallback? onLoggedOut;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_MeDataVm> _future;

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
    final services = AppServicesScope.read(context);
    final api = services.api;
    final profile = services.identityAuth.currentProfile();
    final localUid = (await services.sessionStore.readUid())?.trim() ?? '';
    final displayName = (profile?.displayName ?? '').trim().isNotEmpty
        ? profile!.displayName.trim()
        : ((profile?.email ?? '').trim().isNotEmpty
              ? profile!.email.trim()
              : 'User');
    final avatarUrl = (profile?.photoUrl ?? '').trim();
    final profileUid = (profile?.uid ?? '').trim();
    final uid = localUid.isNotEmpty ? localUid : profileUid;

    List<_OriginListItemVm> origins = const [];
    try {
      final originPage = await api.getMyLaunchedOrigins(limit: 30, offset: 0);
      origins = originPage.data
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
    } catch (_) {}

    List<_WorldListItemVm> worldItems = const [];
    try {
      final worlds = await api.getMyWorlds(limit: 30, offset: 0);
      worldItems = worlds
          .map(
            (item) => _WorldListItemVm(
              wid: item.wid,
              title: item.name.trim().isEmpty ? item.wid : item.name.trim(),
              subtitle: 'Updated: ${item.updatedAtText}',
              imageUrl: resolveAssetUrl(item.snapshotCoverUrl),
            ),
          )
          .toList(growable: false);
    } catch (_) {}

    return _MeDataVm(
      avatarUrl: avatarUrl,
      displayName: displayName,
      uid: uid.isEmpty ? 'Unknown' : uid,
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
                      icon: const Icon(Icons.settings, size: 24),
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
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
                                    fontSize: 13,
                                    color: Color(0xFF6F6F6F),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _copyUid(data.uid),
                                icon: const Icon(Icons.copy, size: 20),
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
                  child: SecendTabs(
                    controller: _tabController,
                    labels: const ['Origin', 'World'],
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

  static const double _size = 84;
  static const double _radius = 12;

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: _AvatarImage(url: url, size: _size),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFE6E6E6),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: size * 0.45,
        color: const Color(0xFF9C9C9C),
      ),
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
