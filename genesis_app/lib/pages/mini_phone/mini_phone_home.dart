part of 'mini_phone_page.dart';

extension _MiniPhoneHome on _MiniPhonePageState {
  Widget _home() => ListenableBuilder(
    listenable: _music,
    builder: (context, _) => _homeContent(),
  );

  Widget _homeContent() => Stack(
    fit: StackFit.expand,
    children: [
      _homeWallpaper(),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x52151517),
              Color(0x0A151517),
              Color(0x14151517),
              Color(0x33151517),
            ],
            stops: [0, .37, .68, 1],
          ),
        ),
      ),
      SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final homeTopSpace = MediaQuery.paddingOf(context).top + 56;
            final compact = bounds.maxHeight < 700;
            final narrow = bounds.maxWidth < 350;
            final messages =
                <
                  ({
                    Object sourceId,
                    MiniDemoPerson person,
                    String text,
                    String time,
                  })
                >[];
            final posts = <MiniDemoPost>[];
            if (phone != null) {
              for (final m in phone!.home.messages) {
                final p = phone!.person(m.senderId);
                messages.add((
                  sourceId: ('message', m.id),
                  person: _livePersonPresentation(p),
                  text: m.content,
                  time: m.currentTime,
                ));
              }
              for (var i = 0; i < phone!.home.notifications.length; i++) {
                final n = phone!.home.notifications[i];
                posts.add(
                  MiniDemoPost(
                    '${n.postId}:$i',
                    _livePersonPresentation(
                      phone!.person(n.actorId, type: n.actorType),
                    ),
                    _notificationText(n),
                    n.currentTime,
                    0,
                  ),
                );
              }
            } else {
              for (final p in miniDemoPeople) {
                for (var i = 0; i < store.unread(p); i++) {
                  messages.add((
                    sourceId: ('message', p.id, i),
                    person: p,
                    text: i == 0
                        ? p.preview
                        : 'You slipped away before the last song.',
                    time: i == 0 ? p.time : '4m',
                  ));
                }
              }
              messages.sort(
                (a, b) =>
                    (a.time == 'now'
                            ? 0
                            : a.time == '2m'
                            ? 1
                            : 2)
                        .compareTo(
                          b.time == 'now'
                              ? 0
                              : b.time == '2m'
                              ? 1
                              : 2,
                        ),
              );

              posts.addAll(store.unreadPosts);
            }
            final kinds = <String>[
              if (messages.isNotEmpty) 'Messages',
              if (posts.isNotEmpty) 'Posts',
            ];
            final allExpanded =
                kinds.isNotEmpty &&
                kinds.any(expandedNotificationGroups.contains);
            final homeClock = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    phone == null
                        ? 'Day 2 · Ashford Estate'
                        : [
                            phone!.worldDay,
                            phone!.worldName,
                          ].where((part) => part.isNotEmpty).join(' · '),
                    style: miniStyle(
                      compact ? 18 : 20,
                      FontWeight.w500,
                    ).copyWith(height: 1.25, letterSpacing: -.6),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _glassClock(
                    narrow
                        ? 96
                        : compact
                        ? 99
                        : 110,
                  ),
                ),
              ],
            );
            final homeNotices = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_music.activated) ...[
                  AppLaunchSource(
                    id: 'home-music-card',
                    borderRadius: 21,
                    child: _MiniHomeMusicCard(
                      music: _music,
                      onOpen: () => _launchFrom(
                        'home-music-card',
                        MiniPhoneScreen.music,
                        () => _go(MiniPhoneScreen.music),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (phone != null && phone!.errors['home'] != null)
                  _liveStatus('home', phone!.refreshSummary),
                if (kinds.isNotEmpty) ...[
                  if (messages.isNotEmpty)
                    _noticeGroup(
                      'Messages',
                      phone?.home.dmUnread ?? messages.length,
                      [
                        for (final n in messages)
                          _homeNotice(
                            n.person,
                            n.text,
                            n.time,
                            () => _openChat(n.person),
                            sourceId: n.sourceId,
                            app: MiniPhoneScreen.messages,
                            squareAvatar: true,
                          ),
                      ],
                      allExpanded: allExpanded,
                      toggleAll: () => _update(() {
                        if (allExpanded) {
                          expandedNotificationGroups.clear();
                        } else {
                          expandedNotificationGroups.addAll(kinds);
                        }
                      }),
                    ),
                  if (posts.isNotEmpty)
                    _noticeGroup(
                      'Posts',
                      phone?.home.postUnread ?? posts.length,
                      [
                        for (final p in posts)
                          _homeNotice(
                            p.person,
                            p.text,
                            p.time,
                            () => _openComments(p),
                            sourceId: ('post', p.id),
                            app: MiniPhoneScreen.posts,
                          ),
                      ],
                      allExpanded: allExpanded,
                      toggleAll: messages.isEmpty
                          ? () => _update(() {
                              if (allExpanded) {
                                expandedNotificationGroups.clear();
                              } else {
                                expandedNotificationGroups.addAll(kinds);
                              }
                            })
                          : null,
                    ),
                ],
                if (phone != null && kinds.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (phone!.home.dmUnread > 0)
                        TextButton(
                          onPressed: () {
                            phone!.unreadSessionsOnly = true;
                            _go(MiniPhoneScreen.messages);
                          },
                          child: const Text('More messages'),
                        ),
                      if (phone!.home.postUnread > 0)
                        TextButton(
                          onPressed: () => _go(MiniPhoneScreen.notifications),
                          child: const Text('More notifications'),
                        ),
                    ],
                  ),
              ],
            );
            // Reserve space in scroll content, rather than clipping it above the dock.
            final dockSpace =
                (narrow ? 56.0 : 62.0) +
                36 +
                (compact ? 14 : 18) +
                28 +
                (compact ? 14 : 16) +
                12;
            return Stack(
              children: [
                Positioned.fill(
                  child: PageView(
                    controller: homePages,
                    reverse: false,
                    onPageChanged: (value) =>
                        _update(() => homePagerPosition = value),
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: kinds.isEmpty
                            ? null
                            : (_) {
                                _homeNoticeDragActive = true;
                                _homeNoticeDragDistance = 0;
                                _homeNoticeDragInitialProgress = allExpanded
                                    ? 1
                                    : 0;
                                _homeNoticeDragInitialGroups
                                  ..clear()
                                  ..addAll(expandedNotificationGroups);
                              },
                        onVerticalDragUpdate: kinds.isEmpty
                            ? null
                            : (details) {
                                if (!_homeNoticeDragActive) return;
                                _homeNoticeDragDistance += details.delta.dy;
                                if (_homeNoticeDragDistance.abs() < 12) return;
                                _update(() {
                                  final progress =
                                      (_homeNoticeDragInitialProgress -
                                              _homeNoticeDragDistance / 180)
                                          .clamp(0.0, 1.0);
                                  if (_homeNoticeDragInitialProgress == 0 &&
                                      progress > 0) {
                                    expandedNotificationGroups.addAll(kinds);
                                  }
                                  _homeNoticeDragProgress = progress;
                                });
                              },
                        onVerticalDragEnd: kinds.isEmpty
                            ? null
                            : (details) {
                                if (!_homeNoticeDragActive) return;
                                _homeNoticeDragActive = false;
                                final velocity = details.primaryVelocity ?? 0;
                                final progress =
                                    _homeNoticeDragProgress ??
                                    _homeNoticeDragInitialProgress;
                                final expand =
                                    velocity.abs() > 500 &&
                                        _homeNoticeDragDistance.abs() >= 24
                                    ? velocity < 0
                                    : progress >=
                                          (_homeNoticeDragInitialProgress > .5
                                              ? .65
                                              : .35);
                                _update(() {
                                  if (expand) {
                                    expandedNotificationGroups.addAll(kinds);
                                  } else {
                                    expandedNotificationGroups.clear();
                                  }
                                  _homeNoticeDragProgress = null;
                                });
                              },
                        onVerticalDragCancel: kinds.isEmpty
                            ? null
                            : () {
                                if (!_homeNoticeDragActive) return;
                                _homeNoticeDragActive = false;
                                _update(() {
                                  expandedNotificationGroups
                                    ..clear()
                                    ..addAll(_homeNoticeDragInitialGroups);
                                  _homeNoticeDragProgress = null;
                                });
                              },
                        child: CustomScrollView(
                          controller: homeNoticeScroll,
                          physics: const NeverScrollableScrollPhysics(),
                          key: const PageStorageKey(
                            'mini-home-bottom-anchored-notices',
                          ),
                          reverse: true,
                          slivers: [
                            SliverToBoxAdapter(
                              child: SizedBox(height: dockSpace),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  12,
                                  18,
                                  0,
                                ),
                                child: homeNotices,
                              ),
                            ),
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Column(
                                children: [
                                  SizedBox(height: homeTopSpace),
                                  homeClock,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: homeTopSpace),
                        child: _lockedHomeApps(narrow ? 56 : 62),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: compact ? 14 : 16),
                        child: GestureDetector(
                          onHorizontalDragEnd: (details) => _selectHomePage(
                            (details.primaryVelocity ?? 0) < 0 ? 1 : 0,
                          ),
                          child: MiniGlass(
                            radius: 18,
                            opacity: .094,
                            light: true,
                            outlined: false,
                            child: SizedBox(
                              width: 68,
                              height: 28,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < 2; i++)
                                    Semantics(
                                      label: 'Home position ${i + 1}',
                                      selected: homePagerPosition == i,
                                      button: true,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _selectHomePage(i),
                                        child: SizedBox(
                                          width: 16,
                                          height: 28,
                                          child: Center(
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withValues(
                                                  alpha: homePagerPosition == i
                                                      ? .95
                                                      : .4,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          compact ? 14 : 18,
                        ),
                        child: MiniGlass(
                          light: true,
                          outlined: false,
                          radius: 36,
                          opacity: .20,
                          padding: EdgeInsets.symmetric(
                            horizontal: narrow ? 12 : 16,
                            vertical: 18,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _homeApp(
                                'messages',
                                'Messages',
                                MiniPhoneScreen.messages,
                                size: narrow ? 56 : 62,
                                badge:
                                    phone?.home.dmUnread ?? store.totalUnread,
                              ),
                              _homeApp(
                                'posts',
                                'Posts',
                                MiniPhoneScreen.posts,
                                size: narrow ? 56 : 62,
                                badge: phone?.home.postUnread ?? posts.length,
                              ),
                              _homeApp(
                                'photos',
                                'Photos',
                                MiniPhoneScreen.photos,
                                size: narrow ? 56 : 62,
                              ),
                              _homeApp(
                                'settings',
                                'Settings',
                                MiniPhoneScreen.settings,
                                size: narrow ? 56 : 62,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _glassClock(double size) {
    final style = miniStyle(
      size,
      FontWeight.w600,
    ).copyWith(height: 1.08, letterSpacing: -size * .065);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xA6FFFFFF),
            Color(0x85FFFFFF),
            Color(0x66FFFFFF),
            Color(0x99FFFFFF),
          ],
          stops: [0, .3, .58, 1],
        ).createShader(rect),
        child: Text(
          phone == null ? '01:04' : phone!.clockTime,
          style: style.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _noticeAction(String text, VoidCallback action) => TextButton(
    onPressed: action,
    style: TextButton.styleFrom(
      foregroundColor: miniWhite,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      minimumSize: const Size(0, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(text, style: miniStyle(12)),
  );

  Widget _noticeGroup(
    String kind,
    int count,
    List<Widget> cards, {
    bool allExpanded = false,
    VoidCallback? toggleAll,
  }) {
    final expanded = expandedNotificationGroups.contains(kind);
    final target = expanded ? (_homeNoticeDragProgress ?? 1.0) : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration:
          _homeNoticeDragProgress != null ||
              MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => Padding(
        // Keep the bottom edge independent of the expansion fraction.
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$kind · $count',
                      style: miniStyle(16, FontWeight.w500),
                    ),
                  ),
                  if (toggleAll != null)
                    _noticeAction(
                      allExpanded ? 'Show less' : 'Show all',
                      toggleAll,
                    ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: !expanded && count > 1
                  ? () => _update(() => expandedNotificationGroups.add(kind))
                  : null,
              child: _MiniNoticeLayout(
                progress: progress,
                children: [
                  for (var i = 0; i < cards.length; i++)
                    IgnorePointer(
                      ignoring: !expanded && count > 1,
                      child: Opacity(
                        opacity: i == 0 ? 1 : progress,
                        child: cards[i],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeNotice(
    MiniDemoPerson person,
    String text,
    String time,
    VoidCallback action, {
    required Object sourceId,
    required MiniPhoneScreen app,
    bool squareAvatar = false,
  }) => AppLaunchSource(
    key: ValueKey(sourceId),
    id: sourceId,
    borderRadius: 21,
    child: GestureDetector(
      onTap: () => _launchFrom(sourceId, app, action),
      child: MiniGlass(
        light: true,
        outlined: false,
        opacity: .36,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Row(
            children: [
              MiniAvatar(
                person,
                size: 36,
                borderRadius: squareAvatar ? 8 : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person.short,
                            style: miniStyle(12, FontWeight.w600),
                          ),
                        ),
                        Text(
                          time,
                          style: miniStyle(10, FontWeight.w400, miniSecondary),
                        ),
                      ],
                    ),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: miniStyle(12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _homeApp(
    String icon,
    String label,
    MiniPhoneScreen target, {
    double size = 62,
    int badge = 0,
  }) => Semantics(
    label: label,
    button: true,
    child: GestureDetector(
      onTap: () => _launchFrom(target, target, () => _go(target)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppLaunchSource(
            id: target,
            borderRadius: 17,
            surfaceColor: const Color(0xFF232228),
            preview: Center(
              child: MiniIcon(
                icon.startsWith('music-') ? icon : 'flat-$icon',
                size: 33,
                color: miniWhite,
              ),
            ),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF232228),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Center(
                child: MiniIcon(
                  icon.startsWith('music-') ? icon : 'flat-$icon',
                  size: 33,
                  color: miniWhite,
                ),
              ),
            ),
          ),
          if (badge > 0)
            Positioned(right: -4, top: -4, child: MiniBadge(badge)),
        ],
      ),
    ),
  );

  Widget _lockedHomeApps(double size) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lockedApp('Camera', Icons.camera_alt_rounded, size),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _homeApp(
              'music-musical-note',
              'Music',
              MiniPhoneScreen.music,
              size: size,
            ),
            const SizedBox(height: 7),
            Text('Music', style: miniStyle(12)),
          ],
        ),
        _lockedApp('Maps', Icons.map_rounded, size),
        _lockedApp('Calendar', Icons.calendar_month_rounded, size),
      ],
    ),
  );
  Widget _lockedApp(String label, IconData icon, double size) => Semantics(
    label: '$label, locked',
    button: true,
    enabled: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF232228),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Center(child: Icon(icon, size: 33, color: miniWhite)),
            ),
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF36343B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: miniWhite,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(label, style: miniStyle(12)),
      ],
    ),
  );
}
