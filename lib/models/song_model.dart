import '../core/utils/song_type_helper.dart';
import 'category_model.dart';

class SongModel {
  final int songid;
  final String songtitle;
  final String songsinger;
  final String songurl;
  final int songcategory;
  final String? songnada;
  final String? songduration;
  final bool? karaokeFlag;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final CategoryModel? category;

  const SongModel({
    required this.songid,
    required this.songtitle,
    required this.songsinger,
    required this.songurl,
    required this.songcategory,
    this.songnada,
    this.songduration,
    this.karaokeFlag,
    this.createdAt,
    this.updatedAt,
    this.category,
  });

  bool get isKaraoke =>
      karaokeFlag ?? SongTypeHelper.isKaraokeText(songtitle, songsinger);

  SongModel copyWith({
    int? songid,
    String? songtitle,
    String? songsinger,
    String? songurl,
    int? songcategory,
    String? songnada,
    String? songduration,
    bool? karaokeFlag,
    DateTime? createdAt,
    DateTime? updatedAt,
    CategoryModel? category,
  }) {
    return SongModel(
      songid: songid ?? this.songid,
      songtitle: songtitle ?? this.songtitle,
      songsinger: songsinger ?? this.songsinger,
      songurl: songurl ?? this.songurl,
      songcategory: songcategory ?? this.songcategory,
      songnada: songnada ?? this.songnada,
      songduration: songduration ?? this.songduration,
      karaokeFlag: karaokeFlag ?? this.karaokeFlag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    CategoryModel? parsedCategory;
    if (json['category'] != null && json['category'] is Map<String, dynamic>) {
      parsedCategory = CategoryModel.fromJson(
        json['category'] as Map<String, dynamic>,
      );
    }

    DateTime? parsedCreatedAt;
    if (json['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['created_at'].toString());
    }

    DateTime? parsedUpdatedAt;
    if (json['updated_at'] != null) {
      parsedUpdatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    final dynamic rawKaraoke =
        json['is_karaoke'] ?? json['iskaraoke'] ?? json['karaoke'];
    bool? parsedKaraoke;
    if (rawKaraoke is bool) {
      parsedKaraoke = rawKaraoke;
    } else if (rawKaraoke != null) {
      parsedKaraoke = const [
        '1',
        'true',
        'karaoke',
      ].contains(rawKaraoke.toString().toLowerCase());
    }

    return SongModel(
      songid: json['songid'] is int
          ? json['songid'] as int
          : int.tryParse(json['songid']?.toString() ?? '0') ?? 0,
      songtitle: json['songtitle'] as String? ?? '',
      songsinger: json['songsinger'] as String? ?? '',
      songurl: json['songurl'] as String? ?? '',
      songcategory: json['songcategory'] is int
          ? json['songcategory'] as int
          : int.tryParse(json['songcategory']?.toString() ?? '1') ?? 1,
      songnada: json['songnada'] as String?,
      songduration: json['songduration'] as String?,
      karaokeFlag: parsedKaraoke,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      category: parsedCategory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songid': songid,
      'songtitle': songtitle,
      'songsinger': songsinger,
      'songurl': songurl,
      'songcategory': songcategory,
      'songnada': songnada,
      'songduration': songduration,
      if (karaokeFlag != null) 'is_karaoke': karaokeFlag,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
      if (category != null) 'category': category?.toJson(),
    };
  }
}
