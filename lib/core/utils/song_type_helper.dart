/// Deteksi jenis lagu berdasarkan judul dan nama penyanyi.
class SongTypeHelper {
  static const List<String> karaokeKeywords = <String>[
    'karaoke',
    'instrumental',
    'minus one',
    'minusone',
    'tanpa vokal',
    'no vocal',
    'backing track',
  ];

  static bool isKaraokeText(String title, String singer) {
    final text = '$title $singer'.toLowerCase();
    return karaokeKeywords.any(text.contains);
  }
}
