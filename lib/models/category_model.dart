class CategoryModel {
  final int songcategoryid;
  final String songcategoryname;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Backward-compatible getters
  String get id => songcategoryid.toString();
  String get name => songcategoryname;

  CategoryModel({
    dynamic id,
    int? songcategoryid,
    dynamic name,
    String? songcategoryname,
    this.createdAt,
    this.updatedAt,
  })  : songcategoryid = songcategoryid ??
            (id is int ? id : (int.tryParse(id?.toString() ?? '0') ?? 0)),
        songcategoryname =
            (songcategoryname ?? name ?? '').toString();

  CategoryModel copyWith({
    int? songcategoryid,
    String? songcategoryname,
    dynamic id,
    dynamic name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      songcategoryid: songcategoryid ??
          (id != null
              ? (id is int ? id : (int.tryParse(id.toString()) ?? this.songcategoryid))
              : this.songcategoryid),
      songcategoryname: songcategoryname ?? (name?.toString() ?? this.songcategoryname),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['songcategoryid'] != null) {
      parsedId = json['songcategoryid'] is int
          ? json['songcategoryid'] as int
          : (int.tryParse(json['songcategoryid'].toString()) ?? 0);
    } else if (json['id'] != null) {
      parsedId = json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id'].toString()) ?? 0);
    }

    final parsedName = (json['songcategoryname'] ?? json['name'] ?? '').toString();

    DateTime? parsedCreatedAt;
    if (json['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['created_at'].toString());
    } else if (json['createdAt'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['createdAt'].toString());
    }

    DateTime? parsedUpdatedAt;
    if (json['updated_at'] != null) {
      parsedUpdatedAt = DateTime.tryParse(json['updated_at'].toString());
    } else if (json['updatedAt'] != null) {
      parsedUpdatedAt = DateTime.tryParse(json['updatedAt'].toString());
    }

    return CategoryModel(
      songcategoryid: parsedId,
      songcategoryname: parsedName,
      createdAt: parsedCreatedAt ?? DateTime.now(),
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songcategoryid': songcategoryid,
      'songcategoryname': songcategoryname,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      // Backward-compatible properties
      'id': id,
      'name': name,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          songcategoryid == other.songcategoryid &&
          songcategoryname == other.songcategoryname;

  @override
  int get hashCode => songcategoryid.hashCode ^ songcategoryname.hashCode;
}
