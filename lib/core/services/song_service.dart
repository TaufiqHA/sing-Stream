import '../../models/song_model.dart';

abstract class SongService {
  Future<List<SongModel>> getSongs({String? search, int? categoryId});
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
