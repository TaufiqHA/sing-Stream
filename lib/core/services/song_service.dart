import '../../models/song_model.dart';

/// Hasil satu halaman daftar lagu.
class SongPage {
  final List<SongModel> songs;
  final bool hasMore;

  const SongPage({required this.songs, required this.hasMore});
}

/// Memotong daftar lagu menjadi satu halaman secara lokal.
///
/// Dipakai oleh service yang belum memiliki pagination dari sumber datanya.
SongPage pageSongs(List<SongModel> songs, {int page = 1, int pageSize = 20}) {
  final safePage = page < 1 ? 1 : page;
  final safePageSize = pageSize < 1 ? 1 : pageSize;
  final start = (safePage - 1) * safePageSize;
  if (start >= songs.length) {
    return const SongPage(songs: [], hasMore: false);
  }
  final end = (start + safePageSize).clamp(0, songs.length);
  return SongPage(
    songs: songs.sublist(start, end),
    hasMore: end < songs.length,
  );
}

abstract class SongService {
  Future<List<SongModel>> getSongs({
    String? search,
    int? categoryId,
    bool? isKaraoke,
  });

  /// Mengambil satu halaman lagu.
  Future<SongPage> getSongsPage({
    String? search,
    int? categoryId,
    bool? isKaraoke,
    int page = 1,
    int pageSize = 20,
  });

  Future<SongModel> getSong(int id);
  Future<SongModel> createSong({
    required String songtitle,
    required String songsinger,
    required String songurl,
    required int songcategory,
    String? songnada,
    String? songduration,
  });
  Future<SongModel> updateSong(SongModel song);
  Future<bool> deleteSong(int songid);
}
