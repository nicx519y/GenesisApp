part of 'mini_phone_page.dart';

// UI fixtures only. No audio engine, remote catalogue or production writes.
const _miniMusicTracks = [
  (
    title: 'A Midnight Waltz',
    handle: 'ashfordensemble',
    world: 'Ashford Estate',
    cover: 'loc_1_1_1.jpg',
    duration: 228,
    likes: 128,
  ),
  (
    title: 'After the Ball',
    handle: 'ashfordensemble',
    world: 'Ashford Estate',
    cover: 'loc_1_1_2.jpg',
    duration: 196,
    likes: 76,
  ),
  (
    title: 'The Quiet Garden',
    handle: 'noahreed',
    world: 'Ashford Estate',
    cover: 'loc_1_2_2.jpg',
    duration: 254,
    likes: 43,
  ),
];

class _MiniMusicPlayer extends StatefulWidget {
  const _MiniMusicPlayer();
  @override
  State<_MiniMusicPlayer> createState() => _MiniMusicPlayerState();
}

class _MiniMusicPlayerState extends State<_MiniMusicPlayer> {
  int get _index => miniDemoMusic.index;
  int get _position => miniDemoMusic.position;
  bool get _playing => miniDemoMusic.playing;
  final _liked = <int>{};
  @override
  void initState() {
    super.initState();
    miniDemoMusic.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    miniDemoMusic.removeListener(_changed);
    super.dispose();
  }

  String _time(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  void _next() => miniDemoMusic.next();
  void _previous() => miniDemoMusic.previous();
  void _togglePlay() => miniDemoMusic.toggle();

  @override
  Widget build(BuildContext context) {
    final track = _miniMusicTracks[_index];
    final liked = _liked.contains(_index);
    return LayoutBuilder(
      builder: (context, bounds) {
        final availableWidth = (bounds.maxWidth - 52).clamp(0.0, 320.0);
        final coverWidth = ((bounds.maxHeight - 250) / 1.5)
            .clamp(80.0, 320.0)
            .clamp(0.0, availableWidth);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 4, 26, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      '$miniPhoneAssets${track.cover}',
                      width: coverWidth,
                      height: coverWidth * 1.5,
                      fit: BoxFit.cover,
                      semanticLabel: '${track.title} cover',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: miniStyle(
                                24,
                                FontWeight.w700,
                              ).copyWith(height: 1.2, letterSpacing: -.7),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '@${track.handle}',
                              style: miniStyle(
                                12,
                                FontWeight.w400,
                                miniSecondary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'From ${track.world}',
                              style: miniStyle(
                                12,
                                FontWeight.w400,
                                miniSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Semantics(
                        button: true,
                        toggled: liked,
                        label: '${liked ? 'Unlike' : 'Like'} ${track.title}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            if (liked) {
                              _liked.remove(_index);
                            } else {
                              _liked.add(_index);
                            }
                          }),
                          child: SizedBox(
                            width: 44,
                            height: 54,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                MiniIcon(
                                  'heart',
                                  size: 23,
                                  color: liked ? miniPink : miniWhite,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '${track.likes + (liked ? 1 : 0)}',
                                  style: miniStyle(
                                    12,
                                    FontWeight.w500,
                                    liked ? miniPink : miniSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: miniWhite,
                      inactiveTrackColor: const Color(0x29F4F3F6),
                      thumbColor: miniWhite,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: _position.toDouble(),
                      min: 0,
                      max: track.duration.toDouble(),
                      padding: EdgeInsets.zero,
                      semanticFormatterCallback: (value) =>
                          '${_time(value.toInt())} of ${_time(track.duration)}',
                      onChanged: (value) => miniDemoMusic.seek(value.round()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _time(_position),
                        style: miniStyle(12, FontWeight.w400, miniSecondary),
                      ),
                      Text(
                        '−${_time(track.duration - _position)}',
                        style: miniStyle(12, FontWeight.w400, miniSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _control('music-backward', 'Previous track', _previous),
                      const SizedBox(width: 38),
                      Semantics(
                        toggled: _playing,
                        label: _playing ? 'Pause' : 'Play',
                        button: true,
                        child: IconButton(
                          onPressed: _togglePlay,
                          style: IconButton.styleFrom(
                            backgroundColor: miniRed,
                            minimumSize: const Size(64, 64),
                            maximumSize: const Size(64, 64),
                          ),
                          icon: MiniIcon(
                            _playing ? 'music-pause' : 'music-play',
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 38),
                      _control('music-forward', 'Next track', _next),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _control(String icon, String label, VoidCallback action) => IconButton(
    tooltip: label,
    onPressed: action,
    constraints: const BoxConstraints.tightFor(width: 44, height: 48),
    padding: EdgeInsets.zero,
    icon: MiniIcon(icon, size: 28),
  );
}
