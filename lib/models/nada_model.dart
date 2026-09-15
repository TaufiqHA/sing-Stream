class NadaModel {
  final int id;
  final String nada;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NadaModel({
    required this.id,
    required this.nada,
    this.createdAt,
    this.updatedAt,
  });

  NadaModel copyWith({
    int? id,
    String? nada,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NadaModel(
      id: id ?? this.id,
      nada: nada ?? this.nada,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NadaModel.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['id'] != null) {
      parsedId = json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id'].toString()) ?? 0);
    }

    final parsedNada = (json['nada'] ?? '').toString();

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

    return NadaModel(
      id: parsedId,
      nada: parsedNada,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nada': nada,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NadaModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nada == other.nada;

  @override
  int get hashCode => id.hashCode ^ nada.hashCode;

  @override
  String toString() => 'NadaModel(id: $id, nada: $nada)';
}
