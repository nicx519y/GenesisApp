import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../../network/genesis_http_transport_pool.dart';
import '../../../network/http_transport.dart';
import '../../../network/models/music.dart';

abstract interface class MiniPhoneMusicCache {
  Future<Uri?> find(MusicTrack track);
  Future<void> remember(MusicTrack track);
}

/// Device-local, complete audio files. No expiry or periodic cleanup; only a
/// successful new download evicts the oldest insertion when all 10 slots fill.
class LocalMiniPhoneMusicCache implements MiniPhoneMusicCache {
  LocalMiniPhoneMusicCache({
    Future<Directory> Function()? directory,
    Future<List<int>> Function(String url)? download,
  }) : _directory = directory ?? _defaultDirectory,
       _download = download ?? _downloadAudio;

  static final shared = LocalMiniPhoneMusicCache();
  static const maxTracks = 10;
  final Future<Directory> Function() _directory;
  final Future<List<int>> Function(String url) _download;
  final _pending = <String, Future<void>>{};
  Future<void> _files = Future.value();
  Future<void> _downloads = Future.value();

  static Future<Directory> _defaultDirectory() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/miniphone_music_audio_v1',
  );

  static Future<List<int>> _downloadAudio(String url) async {
    final response = await GenesisHttpTransportRegistry.current.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 120000,
        decodeResponseBody: false,
      ),
    );
    if (response.statusCode != HttpStatus.ok || response.bodyBytes.isEmpty) {
      throw HttpException('Audio download failed', uri: Uri.parse(url));
    }
    return response.bodyBytes;
  }

  String _key(MusicTrack track) =>
      sha256.convert(utf8.encode(track.audioUrl)).toString();

  String _name(MusicTrack track) {
    final extension =
        RegExp(
          r'\.[a-zA-Z0-9]{1,5}$',
        ).firstMatch(Uri.parse(track.audioUrl).path)?.group(0) ??
        '.mp3';
    return '${_key(track)}$extension';
  }

  static final _completeName = RegExp(r'^[a-f0-9]{64}\.[a-zA-Z0-9]{1,5}$');

  Future<T> _withFiles<T>(Future<T> Function() action) {
    final result = _files.then((_) => action());
    _files = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<Uri?> find(MusicTrack track) => _withFiles(() async {
    try {
      final directory = await _directory();
      final file = File('${directory.path}/${_name(track)}');
      return await file.exists() && await file.length() > 0 ? file.uri : null;
    } catch (_) {
      // Storage availability must never prevent streaming playback.
      return null;
    }
  });

  @override
  Future<void> remember(MusicTrack track) {
    final key = _key(track);
    return _pending[key] ??= _enqueue(track).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<void> _enqueue(MusicTrack track) {
    final result = _downloads
        .then((_) async {
          if (await find(track) != null) return;
          // Check storage before spending bandwidth. Downloads are serial, while
          // disk lookups remain independent so cached playback never waits on HTTP.
          final directory = await _directory();
          await directory.create(recursive: true);
          final bytes = await _download(track.audioUrl);
          if (bytes.isEmpty) return;
          await _withFiles(() async {
            final file = File('${directory.path}/${_name(track)}');
            final temporary = File('${file.path}.part');
            try {
              await temporary.writeAsBytes(bytes, flush: true);
              final cached = await directory
                  .list()
                  .where(
                    (entry) =>
                        entry is File &&
                        _completeName.hasMatch(entry.uri.pathSegments.last),
                  )
                  .cast<File>()
                  .toList();
              final entries = [
                for (final entry in cached)
                  (file: entry, stat: await entry.stat()),
              ]..sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
              while (entries.length >= maxTracks) {
                await entries.removeAt(0).file.delete();
              }
              await temporary.rename(file.path);
            } finally {
              if (await temporary.exists()) await temporary.delete();
            }
          });
        })
        .catchError((Object _) {
          // A failed download leaves existing complete entries untouched.
        });
    _downloads = result;
    return result;
  }
}
