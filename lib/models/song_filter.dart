/// Jenis lagu yang dapat dipilih pada filter pencarian user.
enum SongFilter {
  karaoke,
  nonKaraoke;

  bool get isKaraoke => this == SongFilter.karaoke;

  String get label => this == SongFilter.karaoke ? 'Karaoke' : 'Non Karaoke';
}
