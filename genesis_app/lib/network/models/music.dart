class MusicLikeStatus {
  const MusicLikeStatus({required this.file, required this.isLiked});

  factory MusicLikeStatus.fromJson(Map<String, dynamic> json) {
    final file = _requiredString(json, 'file');
    final isLiked = json['is_liked'];
    if (isLiked is! bool) {
      throw const FormatException('is_liked must be a boolean');
    }
    return MusicLikeStatus(file: file, isLiked: isLiked);
  }

  final String file;
  final bool isLiked;
}

class MusicCatalog {
  const MusicCatalog({required this.preUrl, required this.tracks});

  factory MusicCatalog.fromJson(Map<String, dynamic> json) {
    final preUrl = _requiredString(json, 'pre_url');
    final base = Uri.tryParse(preUrl);
    if (base == null ||
        !base.hasAuthority ||
        (base.scheme != 'https' && base.scheme != 'http')) {
      throw const FormatException('pre_url must be an HTTP URL');
    }
    final list = json['list'];
    if (list is! List) throw const FormatException('list must be an array');
    return MusicCatalog(
      preUrl: preUrl,
      tracks: List.unmodifiable(
        list.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('music item must be an object');
          }
          return MusicTrack.fromJson(item, preUrl: preUrl);
        }),
      ),
    );
  }

  final String preUrl;
  final List<MusicTrack> tracks;
}

class MusicTrack {
  const MusicTrack({
    required this.file,
    required this.audioUrl,
    required this.sourceWorldoId,
    required this.sourceWorldoName,
    required this.artist,
    required this.title,
    required this.coverUrl,
    required this.likeCount,
    required this.isLiked,
  });

  factory MusicTrack.fromJson(
    Map<String, dynamic> json, {
    required String preUrl,
  }) {
    final file = _requiredString(json, 'file');
    final audioUrl = '$preUrl$file';
    final likeCount = json['like_cnt'];
    final isLiked = json['is_liked'];
    if (likeCount is! int || likeCount < 0) {
      throw const FormatException('like_cnt must be a nonnegative integer');
    }
    if (isLiked is! bool) {
      throw const FormatException('is_liked must be a boolean');
    }
    return MusicTrack(
      file: file,
      audioUrl: audioUrl,
      sourceWorldoId: _requiredString(json, 'source_worldo_id'),
      sourceWorldoName: _requiredString(json, 'source_worldo_name'),
      artist: _requiredString(json, 'artist'),
      title: _requiredString(json, 'title'),
      coverUrl: _requiredString(json, 'cover_url').split('?').first,
      likeCount: likeCount,
      isLiked: isLiked,
    );
  }

  final String file, audioUrl, sourceWorldoId, sourceWorldoName;
  final String artist, title, coverUrl;
  final int likeCount;
  final bool isLiked;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}
