import 'dart:async';
import '../../models/song_model.dart';
import 'song_service.dart';

class DummySongService implements SongService {
  late final List<SongModel> _songs;

  final List<SongModel> _defaultSongs = const [
    SongModel(
      songid: 1,
      songtitle: 'Sial',
      songsinger: 'Mahalini',
      songurl: 'https://www.youtube.com/watch?v=0kFh_0l33rM',
      songcategory: 1,
      songnada: 'Wanita',
      songduration: '04:03',
    ),
    SongModel(
      songid: 2,
      songtitle: 'Rungkad',
      songsinger: 'Happy Asmara',
      songurl: 'https://www.youtube.com/watch?v=4E-l_P4_pYQ',
      songcategory: 2,
      songnada: 'Wanita',
      songduration: '04:15',
    ),
    SongModel(
      songid: 3,
      songtitle: 'Separuh Nafas',
      songsinger: 'Dewa 19',
      songurl: 'https://www.youtube.com/watch?v=vVj44t-j3tA',
      songcategory: 3,
      songnada: 'Pria',
      songduration: '03:45',
    ),
    SongModel(
      songid: 4,
      songtitle: 'Perfect',
      songsinger: 'Ed Sheeran',
      songurl: 'https://www.youtube.com/watch?v=2Vv-BfVoq4g',
      songcategory: 4,
      songnada: 'Pria',
      songduration: '04:23',
    ),
    SongModel(
      songid: 5,
      songtitle: 'Komang',
      songsinger: 'Raim Laode',
      songurl: 'https://www.youtube.com/watch?v=UqNZZq3KzM4',
      songcategory: 1,
      songnada: 'Pria',
      songduration: '03:42',
    ),
    SongModel(
      songid: 6,
      songtitle: 'Nemen',
      songsinger: 'Gildcoustic',
      songurl: 'https://www.youtube.com/watch?v=fM87R5-G5x8',
      songcategory: 2,
      songnada: 'Pria',
      songduration: '04:50',
    ),
    SongModel(
      songid: 7,
      songtitle: 'Dynamite',
      songsinger: 'BTS',
      songurl: 'https://www.youtube.com/watch?v=gdZLi9oWNZg',
      songcategory: 5,
      songnada: 'Pria',
      songduration: '03:19',
    ),
  ];

  DummySongService([List<SongModel>? initialSongs]) {
    _songs = initialSongs != null ? List.from(initialSongs) : List.from(_defaultSongs);
  }

  @override
  Future<List<SongModel>> getSongs({String? search, int? categoryId}) async {
    List<SongModel> result = List.from(_songs);

    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      result = result.where((s) {
        return s.songtitle.toLowerCase().contains(query) ||
            s.songsinger.toLowerCase().contains(query);
      }).toList();
    }

    if (categoryId != null) {
      result = result.where((s) => s.songcategory == categoryId).toList();
    }

    return result;
  }

  @override
  Future<SongModel> getSong(int id) async {
    try {
      return _songs.firstWhere((s) => s.songid == id);
    } catch (_) {
      throw Exception('Lagu tidak ditemukan.');
    }
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
    int nextId = 1;
    if (_songs.isNotEmpty) {
      final maxId = _songs.map((s) => s.songid).reduce((a, b) => a > b ? a : b);
      nextId = maxId + 1;
    }

    final newSong = SongModel(
      songid: nextId,
      songtitle: songtitle.trim(),
      songsinger: songsinger.trim(),
      songurl: songurl.trim(),
      songcategory: songcategory,
      songnada: songnada?.trim().isNotEmpty == true ? songnada!.trim() : null,
      songduration: songduration?.trim().isNotEmpty == true ? songduration!.trim() : null,
    );

    _songs.insert(0, newSong);
    return newSong;
  }

  @override
  Future<SongModel> updateSong(SongModel song) async {
    final index = _songs.indexWhere((s) => s.songid == song.songid);

    if (index == -1) {
      throw Exception('Lagu tidak ditemukan');
    }

    _songs[index] = song;
    return song;
  }

  @override
  Future<bool> deleteSong(int songid) async {
    final initialLength = _songs.length;
    _songs.removeWhere((s) => s.songid == songid);
    return _songs.length < initialLength;
  }
}
