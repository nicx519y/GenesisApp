part of 'mini_phone_page.dart';

extension _MiniPhoneHome on _MiniPhonePageState {
  Widget _home() => Stack(
    fit: StackFit.expand,
    children: [
      _wallpaperBackground(store.wallpaper, store.wallpaperPhoto),
      if (store.wallpaper != miniSolidWallpaper || store.wallpaperPhoto != null)
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
        child: LayoutBuilder(
          builder: (context, bounds) {
            final compact = bounds.maxHeight < 700;
            final narrow = bounds.maxWidth < 350;
            final messages =
                <({MiniDemoPerson person, String text, String time})>[];
            for (final p in miniDemoPeople) {
              for (var i = 0; i < store.unread(p); i++) {
                messages.add((
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
            final posts = store.unreadPosts;
            final kinds = <String>[
              if (messages.isNotEmpty) 'Messages',
              if (posts.isNotEmpty) 'Posts',
            ];
            final allExpanded =
                kinds.isNotEmpty &&
                kinds.any(expandedNotificationGroups.contains);
            return Column(
              children: [
                const SizedBox(height: 56),
                Expanded(
                  child: PageView(
                    controller: homePages,
                    reverse: false,
                    onPageChanged: (value) =>
                        _update(() => homePagerPosition = value),
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Text(
                              'Day 2 · Ashford Estate',
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
                          Expanded(
                            child: Align(
                              alignment: allExpanded
                                  ? Alignment.topCenter
                                  : Alignment.bottomCenter,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  allExpanded ? 12 : 24,
                                  18,
                                  12,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: allExpanded
                                        ? double.infinity
                                        : bounds.maxHeight *
                                              (compact ? .38 : .44),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (kinds.isNotEmpty) ...[
                                          if (messages.isNotEmpty)
                                            _noticeGroup(
                                              'Messages',
                                              messages.length,
                                              [
                                                for (final n in messages)
                                                  _homeNotice(
                                                    n.person,
                                                    n.text,
                                                    n.time,
                                                    () => _openChat(n.person),
                                                  ),
                                              ],
                                              allExpanded: allExpanded,
                                              toggleAll: () => _update(() {
                                                if (allExpanded) {
                                                  expandedNotificationGroups
                                                      .clear();
                                                } else {
                                                  expandedNotificationGroups
                                                      .addAll(kinds);
                                                }
                                              }),
                                            ),
                                          if (posts.isNotEmpty)
                                            _noticeGroup(
                                              'Posts',
                                              posts.length,
                                              [
                                                for (final p in posts)
                                                  _homeNotice(
                                                    p.person,
                                                    p.text,
                                                    p.time,
                                                    () => _openComments(p),
                                                  ),
                                              ],
                                              allExpanded: allExpanded,
                                              toggleAll: messages.isEmpty
                                                  ? () => _update(() {
                                                      if (allExpanded) {
                                                        expandedNotificationGroups
                                                            .clear();
                                                      } else {
                                                        expandedNotificationGroups
                                                            .addAll(kinds);
                                                      }
                                                    })
                                                  : null,
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _lockedHomeApps(narrow ? 56 : 62),
                    ],
                  ),
                ),
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
                  padding: EdgeInsets.fromLTRB(16, 0, 16, compact ? 14 : 18),
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
                          badge: store.totalUnread,
                        ),
                        _homeApp(
                          'posts',
                          'Posts',
                          MiniPhoneScreen.posts,
                          size: narrow ? 56 : 62,
                          badge: posts.length,
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
        child: Text('01:04', style: style.copyWith(color: Colors.white)),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: expanded
            ? 15
            : count > 1
            ? 25
            : 15,
      ),
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
          if (expanded) ...[
            for (final card in cards)
              Padding(padding: const EdgeInsets.only(bottom: 7), child: card),
          ] else
            GestureDetector(
              onTap: count > 1
                  ? () => _update(() => expandedNotificationGroups.add(kind))
                  : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (count > 2)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 14,
                      bottom: -14,
                      child: _stackStrip(.18),
                    ),
                  if (count > 1)
                    Positioned(
                      left: 6,
                      right: 6,
                      top: 8,
                      bottom: -8,
                      child: _stackStrip(.28),
                    ),
                  IgnorePointer(ignoring: count > 1, child: cards.first),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stackStrip(double opacity) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(21),
    ),
  );

  Widget _homeNotice(
    MiniDemoPerson person,
    String text,
    String time,
    VoidCallback action,
  ) => GestureDetector(
    onTap: action,
    child: MiniGlass(
      light: true,
      outlined: false,
      opacity: .36,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Row(
          children: [
            MiniAvatar(person, size: 36),
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
      onTap: () => _go(target),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
