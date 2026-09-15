class UserAccountModel {
  final int userid;
  final String username;
  final String password;
  final String role; // 'admin' atau 'user'
  final String? name;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserAccountModel({
    required this.userid,
    required this.username,
    required this.password,
    this.role = 'user',
    this.name,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  String get displayName => (name != null && name!.trim().isNotEmpty) ? name!.trim() : username;

  UserAccountModel copyWith({
    int? userid,
    String? username,
    String? password,
    String? role,
    String? name,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAccountModel(
      userid: userid ?? this.userid,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserAccountModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    final rawId = json['id'] ?? json['userid'];
    final parsedId = rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '0') ?? 0);

    return UserAccountModel(
      userid: parsedId,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      name: json['name'] as String?,
      email: json['email'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': userid,
      'userid': userid,
      'username': username,
      'password': password,
      'role': role,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAccountModel &&
          runtimeType == other.runtimeType &&
          userid == other.userid &&
          username == other.username &&
          password == other.password &&
          role == other.role &&
          name == other.name &&
          email == other.email;

  @override
  int get hashCode =>
      userid.hashCode ^
      username.hashCode ^
      password.hashCode ^
      role.hashCode ^
      name.hashCode ^
      email.hashCode;
}
