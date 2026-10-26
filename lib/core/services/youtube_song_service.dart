import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/song_model.dart';
import '../utils/song_type_helper.dart';
import 'song_service.dart';

/// Layanan lagu yang terhubung langsung ke YouTube untuk pencarian lagu karaoke tanpa API backend.
class YoutubeSongService implements SongService {
  final YoutubeExplode _yt;
  final bool isTestMode;
  final List<SongModel>? initialSongs;

  YoutubeSongService({
    YoutubeExplode? yt,
    this.isTestMode = false,
    this.initialSongs,
  }) : _yt = yt ?? YoutubeExplode();

  static final List<SongModel> defaultPopularSongs = [
    const SongModel(
      songid: 101,
      songtitle: 'Hampa - Ari Lasso (Karaoke)',
      songsinger: 'Ari Lasso',
      songurl: 'https://www.youtube.com/watch?v=kXYiU_JCYtU',
      songcategory: 1,
      songduration: '04:30',
      songnada: '-',
    ),
    const SongModel(
      songid: 102,
      songtitle: 'Kemesraan - Iwan Fals (Karaoke)',
      songsinger: 'Iwan Fals',
      songurl: 'https://www.youtube.com/watch?v=3JZ_D3ELwOQ',
      songcategory: 1,
      songduration: '04:15',
      songnada: '-',
    ),
    const SongModel(
      songid: 103,
      songtitle: 'Dan - Sheila On 7 (Karaoke)',
      songsinger: 'Sheila On 7',
      songurl: 'https://www.youtube.com/watch?v=2Vv-BfVoq4g',
      songcategory: 1,
      songduration: '04:40',
      songnada: '-',
    ),
    const SongModel(
      songid: 104,
      songtitle: 'Kangen - Dewa 19 (Karaoke)',
      songsinger: 'Dewa 19',
      songurl: 'https://www.youtube.com/watch?v=fJ9rUzIMcZQ',
      songcategory: 1,
      songduration: '05:00',
      songnada: '-',
    ),
  ];

  /// Memastikan kueri pencarian selalu menyertakan kata 'karaoke'
  static String formatKaraokeQuery(String? search) {
    if (search == null || search.trim().isEmpty) {
      return 'karaoke hits indonesia';
    }
    final clean = search.trim();
    if (!clean.toLowerCase().contains('karaoke')) {
      return '$clean karaoke';
    }
    return clean;
  }

  /// Memastikan kueri pencarian lagu non-karaoke tidak menyertakan kata 'karaoke'.
  static String formatNonKaraokeQuery(String? search) {
    if (search == null || search.trim().isEmpty) {
      return 'lagu indonesia terbaru';
    }
    return search.trim();
  }

  /// Memeriksa apakah video mengandung indikator karaoke
  static bool isKaraokeVideo(Video video) {
    return SongTypeHelper.isKaraokeText(video.title, video.author);
  }

  /// Cursor pencarian YouTube yang sedang aktif, dipakai untuk pagination.
  VideoSearchList? _activeSearchList;
  String? _activeSearchKey;

  static const int _maxBatchesPerPage = 5;

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Mengubah daftar video menjadi model lagu sesuai filter jenis lagu.
  List<SongModel> _convertVideos(
    Iterable<Video> videos, {
    int? categoryId,
    bool? isKaraoke,
  }) {
    final results = <SongModel>[];
    final nonKaraokeFallback = <SongModel>[];

    for (final video in videos) {
      final dur = video.duration;
      String? durationStr;
      if (dur != null) {
        final minutes = dur.inMinutes.toString().padLeft(2, '0');
        final seconds = (dur.inSeconds % 60).toString().padLeft(2, '0');
        durationStr = '$minutes:$seconds';
      }

      final bool videoIsKaraoke = isKaraokeVideo(video);
      final model = SongModel(
        songid: video.id.value.hashCode.abs(),
        songtitle: video.title,
        songsinger: video.author,
        songurl: 'https://www.youtube.com/watch?v=${video.id.value}',
        songcategory: categoryId ?? 1,
        songduration: durationStr ?? '03:30',
        songnada: '-',
        karaokeFlag: videoIsKaraoke,
      );

      if (isKaraoke == null) {
        if (videoIsKaraoke) {
          results.add(model);
        } else {
          nonKaraokeFallback.add(model);
        }
      } else if (videoIsKaraoke == isKaraoke) {
        results.add(model);
      }
    }

    // Fallback lintas jenis hanya dipakai saat tidak ada filter aktif.
    if (results.isEmpty && isKaraoke == null) {
      return nonKaraokeFallback;
    }
    return results;
  }

  @override
  Future<List<SongModel>> getSongs({
    String? search,
    int? categoryId,
    bool? isKaraoke,
  }) async {
    if (isTestMode || _isTestEnvironment) {
      final list = initialSongs ?? defaultPopularSongs;
      Iterable<SongModel> result = list;
      if (isKaraoke != null) {
        result = result.where((s) => s.isKaraoke == isKaraoke);
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        result = result.where(
          (s) =>
              s.songtitle.toLowerCase().contains(q) ||
              s.songsinger.toLowerCase().contains(q),
        );
      }
      return result.toList();
    }

    final bool karaokeOnly = isKaraoke ?? true;
    final query = karaokeOnly
        ? formatKaraokeQuery(search)
        : formatNonKaraokeQuery(search);

    try {
      final searchList = await _yt.search
          .search(query)
          .timeout(const Duration(seconds: 8));

      final results = _convertVideos(
        searchList,
        categoryId: categoryId,
        isKaraoke: isKaraoke,
      );

      if (results.isNotEmpty) {
        return results;
      }

      if (isKaraoke == null &&
          (initialSongs != null || defaultPopularSongs.isNotEmpty)) {
        return initialSongs ?? defaultPopularSongs;
      }

      return results;
    } catch (e) {
      debugPrint('YouTube search error: $e');
      final fallback = initialSongs ?? defaultPopularSongs;
      if (isKaraoke == null) return fallback;
      return fallback.where((s) => s.isKaraoke == isKaraoke).toList();
    }
  }

  @override
  Future<SongPage> getSongsPage({
    String? search,
    int? categoryId,
    bool? isKaraoke,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (isTestMode || _isTestEnvironment) {
      final songs = await getSongs(
        search: search,
        categoryId: categoryId,
        isKaraoke: isKaraoke,
      );
      return pageSongs(songs, page: page, pageSize: pageSize);
    }

    final bool karaokeOnly = isKaraoke ?? true;
    final query = karaokeOnly
        ? formatKaraokeQuery(search)
        : formatNonKaraokeQuery(search);
    final searchKey = '$query|${isKaraoke ?? 'all'}';
    final safePageSize = pageSize < 1 ? 1 : pageSize;

    try {
      VideoSearchList? list;
      if (page <= 1 ||
          _activeSearchList == null ||
          _activeSearchKey != searchKey) {
        list = await _yt.search
            .search(query)
            .timeout(const Duration(seconds: 8));
        _activeSearchKey = searchKey;
      } else {
        list = await _activeSearchList!.nextPage().timeout(
          const Duration(seconds: 8),
        );
      }
      _activeSearchList = list;

      final results = <SongModel>[];
      final seenIds = <int>{};
      var exhausted = list == null;
      var batches = 0;

      // Filter karaoke dapat membuang sebagian hasil, jadi ambil beberapa batch
      // tambahan sampai target satu halaman terpenuhi.
      while (list != null &&
          results.length < safePageSize &&
          batches < _maxBatchesPerPage) {
        final mapped = _convertVideos(
          list,
          categoryId: categoryId,
          isKaraoke: isKaraoke,
        );
        for (final song in mapped) {
          if (seenIds.add(song.songid)) {
            results.add(song);
          }
        }
        batches++;

        if (results.length >= safePageSize) break;

        final next = await list.nextPage().timeout(const Duration(seconds: 8));
        if (next == null) {
          exhausted = true;
          break;
        }
        list = next;
        _activeSearchList = next;
      }

      return SongPage(songs: results, hasMore: !exhausted);
    } catch (e) {
      debugPrint('YouTube search page error: $e');
      _activeSearchList = null;
      _activeSearchKey = null;
      if (page > 1) return const SongPage(songs: [], hasMore: false);
      final fallback = initialSongs ?? defaultPopularSongs;
      final filtered = isKaraoke == null
          ? fallback
          : fallback.where((s) => s.isKaraoke == isKaraoke).toList();
      return SongPage(
        songs: filtered.take(safePageSize).toList(),
        hasMore: filtered.length > safePageSize,
      );
    }
  }

  @override
  Future<SongModel> getSong(int id) async {
    final songs = initialSongs ?? defaultPopularSongs;
    return songs.firstWhere((s) => s.songid == id, orElse: () => songs.first);
  }

  @override
  Future<SongModel> createSong({
    required String songtitle,
    required String songsinger,
    required String songurl,
    required int songcategory,
    String? songnada,
    String? songduration,
  }) async {
    return SongModel(
      songid: DateTime.now().millisecondsSinceEpoch,
      songtitle: songtitle,
      songsinger: songsinger,
      songurl: songurl,
      songcategory: songcategory,
      songnada: songnada ?? '-',
      songduration: songduration ?? '03:30',
    );
  }

  @override
  Future<SongModel> updateSong(SongModel song) async {
    return song;
  }

  @override
  Future<bool> deleteSong(int songid) async {
    return true;
  }

  void dispose() {
    try {
      _yt.close();
    } catch (_) {}
  }
}
