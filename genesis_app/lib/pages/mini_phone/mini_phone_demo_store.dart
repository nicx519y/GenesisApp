import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

const miniPhoneAssets = 'assets/mini_phone/';
const miniSolidWallpaper = 'solid-dark';

class MiniDemoPerson {
  const MiniDemoPerson(
    this.id,
    this.name,
    this.short,
    this.image,
    this.role,
    this.preview,
    this.time,
    this.initialUnread,
  );
  final String id, name, short, image, role, preview, time;
  final int initialUnread;
}

const miniDemoPeople = [
  MiniDemoPerson(
    'mini-demo-vivienne',
    'Vivienne Ashford',
    'Vivienne',
    'char_1.jpg',
    'Heir to the Ashford estate',
    'Meet me in the library. Come alone.',
    'now',
    2,
  ),
  MiniDemoPerson(
    'mini-demo-sebastian',
    'Sebastian Wilder',
    'Sebastian',
    'char_3.jpg',
    'A familiar face in the ballroom',
    'I found something you should see.',
    '2m',
    1,
  ),
  MiniDemoPerson(
    'mini-demo-dorian',
    'Dorian Ash',
    'Dorian',
    'char_4.jpg',
    'The guest without an invitation',
    "You: I'll meet you on the terrace.",
    '1h',
    0,
  ),
  MiniDemoPerson(
    'mini-demo-noah',
    'Noah Reed',
    'Noah',
    'char_5.jpg',
    'The outsider with nothing to prove',
    'The gardens are quieter tonight.',
    'Day 1',
    0,
  ),
];
const miniDemoMe = MiniDemoPerson(
  'mini-demo-adrian',
  'Adrian',
  'You',
  'char_2.jpg',
  '',
  '',
  '',
  0,
);
const miniDemoPhotos = [
  'loc_1_1_1.jpg',
  'loc_1_1_2.jpg',
  'loc_1_1_3.jpg',
  'loc_1_1_4.jpg',
  'loc_1_2_1.jpg',
  'loc_1_2_2.jpg',
  'loc_1_6_1.jpg',
];
final miniDemoPhotoAuthors = [
  miniDemoPeople[0],
  miniDemoPeople[1],
  miniDemoPeople[2],
  miniDemoPeople[0],
  miniDemoPeople[3],
  miniDemoPeople[1],
  miniDemoPeople[3],
];
const miniDemoWallpapers = {
  'wallpaper-01.png': 'Mist Forest',
  'wallpaper-02.png': 'Moonlit Town',
  'wallpaper-04.png': 'Night City',
};

class MiniDemoMessage {
  const MiniDemoMessage(this.text, {this.mine = false, this.time = '01:04'});
  final String text, time;
  final bool mine;
}

class MiniDemoComment {
  const MiniDemoComment(this.person, this.text, this.time, {this.replyTo});
  final MiniDemoPerson person;
  final MiniDemoPerson? replyTo;
  final String text, time;
}

class MiniDemoPost {
  MiniDemoPost(
    this.id,
    this.person,
    this.text,
    this.time,
    this.likes, {
    this.asset,
    this.photo,
    List<MiniDemoComment>? comments,
  }) : comments = comments ?? [];
  final String id, text, time;
  final MiniDemoPerson person;
  final int likes;
  final String? asset;
  final Uint8List? photo;
  final List<MiniDemoComment> comments;
  bool liked = false;
}

/// Standalone UI fixtures: deliberately has no API, account or database dependency.
class MiniPhoneDemoStore extends ChangeNotifier {
  MiniPhoneDemoStore() {
    _seed();
  }
  final chats = <String, List<MiniDemoMessage>>{};
  final read = <String>{};
  final posts = <MiniDemoPost>[];
  final readPosts = <String>{};
  List<MiniDemoPost> get unreadPosts => posts
      .where(
        (p) =>
            const {'mini-demo-p1', 'mini-demo-p2'}.contains(p.id) &&
            !readPosts.contains(p.id),
      )
      .toList();
  void markPostsRead() {
    readPosts.addAll(unreadPosts.map((p) => p.id));
    notifyListeners();
  }

  void markPostRead(MiniDemoPost p) {
    readPosts.add(p.id);
    notifyListeners();
  }

  String wallpaper = 'wallpaper-01.png';
  Uint8List? wallpaperPhoto;
  int _sequence = 0;
  int unread(MiniDemoPerson p) => read.contains(p.id) ? 0 : p.initialUnread;
  int get totalUnread => miniDemoPeople.fold(0, (n, p) => n + unread(p));
  void markRead(MiniDemoPerson p) {
    read.add(p.id);
    notifyListeners();
  }

  void send(MiniDemoPerson p, String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    chats[p.id]!.add(MiniDemoMessage(value, mine: true));
    notifyListeners();
  }

  void reply(MiniDemoPerson p) {
    final index = miniDemoPeople.indexOf(p);
    const replies = [
      "I'll leave the door open. Please be careful.",
      'Find me in the library. I can explain there.',
      'Good. Keep this between us.',
      "I'll wait by the gardens.",
    ];
    chats[p.id]!.add(MiniDemoMessage(replies[index]));
    notifyListeners();
  }

  void toggleLike(MiniDemoPost post) {
    post.liked = !post.liked;
    notifyListeners();
  }

  void comment(MiniDemoPost post, String text) {
    if (text.trim().isEmpty) return;
    post.comments.add(MiniDemoComment(miniDemoMe, text.trim(), 'now'));
    notifyListeners();
  }

  void publish(String text, Uint8List? photo) {
    if (text.trim().isEmpty && photo == null) return;
    posts.insert(
      0,
      MiniDemoPost(
        'mini-demo-local-${++_sequence}',
        miniDemoMe,
        text.trim(),
        'Just now',
        0,
        photo: photo,
      ),
    );
    notifyListeners();
  }

  void applyWallpaper(String asset, Uint8List? photo) {
    wallpaper = asset;
    wallpaperPhoto = photo;
    notifyListeners();
  }

  void reset() {
    _seed();
    notifyListeners();
  }

  void _seed() {
    read.clear();
    readPosts.clear();
    chats.clear();
    posts.clear();
    wallpaper = 'wallpaper-01.png';
    wallpaperPhoto = null;
    _sequence = 0;
    for (final p in miniDemoPeople) {
      chats[p.id] = p == miniDemoPeople.first
          ? [
              const MiniDemoMessage(
                'You slipped away before the last song.',
                time: '01:00',
              ),
              const MiniDemoMessage(
                'I needed some air. Was it worth staying?',
                mine: true,
                time: '01:01',
              ),
              const MiniDemoMessage(
                'Sebastian counted every glance tonight.',
                time: '01:02',
              ),
              MiniDemoMessage(p.preview),
            ]
          : [
              MiniDemoMessage(
                p.preview.replaceFirst('You: ', ''),
                time: '01:02',
              ),
            ];
    }
    posts.addAll([
      MiniDemoPost(
        'mini-demo-p1',
        miniDemoPeople[0],
        'Some evenings are better left unexplained.',
        'Just now',
        12,
        asset: 'sq/char_1.jpg',
        comments: [
          MiniDemoComment(
            miniDemoPeople[1],
            'An evening worth remembering.',
            '2m',
          ),
          MiniDemoComment(
            miniDemoPeople[3],
            'The light in here is something else.',
            '3m',
            replyTo: miniDemoPeople[1],
          ),
          MiniDemoComment(
            miniDemoPeople[2],
            'Some stories never leave the ballroom.',
            '4m',
          ),
          MiniDemoComment(
            miniDemoPeople[0],
            'Especially this one.',
            '5m',
            replyTo: miniDemoPeople[2],
          ),
        ],
      ),
      MiniDemoPost(
        'mini-demo-p2',
        miniDemoPeople[1],
        'Funny how the quietest room in the house has the most to say.',
        '8m ago',
        8,
        comments: [
          MiniDemoComment(
            miniDemoPeople[0],
            'Then perhaps you should listen.',
            '5m',
          ),
        ],
      ),
      MiniDemoPost(
        'mini-demo-p3',
        miniDemoPeople[2],
        'A party is only as interesting as the person who was not invited.',
        '12m ago',
        24,
        asset: 'loc_1_1_1.jpg',
        comments: [
          MiniDemoComment(
            miniDemoPeople[0],
            'You always know how to make an entrance.',
            '7m',
          ),
          MiniDemoComment(miniDemoPeople[3], 'I thought the same.', '9m'),
        ],
      ),
      MiniDemoPost(
        'mini-demo-p4',
        miniDemoPeople[3],
        'Found a corner nobody else has claimed.',
        '20m ago',
        6,
        asset: 'loc_1_2_2.jpg',
        comments: [
          MiniDemoComment(miniDemoPeople[2], 'Keep that one a secret.', '12m'),
        ],
      ),
    ]);
  }
}

/// Retained only during the debug process; independent of every production store.

// Device-local debug UI preference, separate from fixtures and account data.
final miniPhoneDockPosition = MiniPhoneDockPosition();
final miniPhoneMapDockPosition = MiniPhoneDockPosition(
  'worldo.debug.mini_phone.map_dock_position.v1',
);

class MiniPhoneDockPosition {
  MiniPhoneDockPosition([
    this._key = 'worldo.debug.mini_phone.dock_position.v1',
  ]);
  final String _key;
  bool right = true;
  double vertical = 1;
  int _revision = 0;
  Future<void>? _loading;
  Future<void> _writing = Future.value();
  Future<void> load() => _loading ??= _read();
  Future<void> _read() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || revision != _revision) return;
      final value = jsonDecode(raw);
      if (value is List &&
          value.length == 2 &&
          value[0] is bool &&
          value[1] is num) {
        final height = (value[1] as num).toDouble();
        if (height.isFinite) {
          right = value[0] as bool;
          vertical = height.clamp(0.0, 1.0);
        }
      }
    } catch (_) {
      debugPrint('Mini phone position could not be restored.');
    }
  }

  Future<void> save(bool side, double height) {
    right = side;
    vertical = height.clamp(0.0, 1.0);
    _revision++;
    final raw = jsonEncode([right, vertical]);
    return _writing = _writing.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, raw);
      } catch (_) {
        debugPrint('Mini phone position could not be saved.');
      }
    });
  }
}
