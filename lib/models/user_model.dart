class UserModel {
  final dynamic id;
  final String? _name;
  final String? _displayName;
  final String username;
  final String? email;
  final String role; // 'admin' atau 'user'
  final DateTime? emailVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    String? name,
    String? displayName,
    required this.username,
    this.email,
    this.role = 'user',
    this.emailVerifiedAt,
    this.createdAt,
    this.updatedAt,
    this.avatarUrl,
  })  : _name = name, // ignore: prefer_initializing_formals
        _displayName = displayName; // ignore: prefer_initializing_formals

  String get name => _name ?? _displayName ?? username;
  String get displayName => _displayName ?? _name ?? username;

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isUser => role.toLowerCase() == 'user';
  int get idAsInt => id is int ? id as int : (int.tryParse(id.toString()) ?? 0);

  UserModel copyWith({
    dynamic id,
    String? name,
    String? displayName,
    String? username,
    String? email,
    String? role,
    DateTime? emailVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? _name,
      displayName: displayName ?? _displayName,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    dynamic parsedId = json['id'];
    if (parsedId is String) {
      final parsedInt = int.tryParse(parsedId);
      if (parsedInt != null) {
        parsedId = parsedInt;
      }
    }

    final rawName = json['name'] as String?;
    final rawDisplayName = json['displayName'] as String?;
    final username = json['username'] as String? ?? '';
    final email = json['email'] as String?;
    final role = json['role'] as String? ?? 'user';

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return UserModel(
      id: parsedId ?? 0,
      name: rawName,
      displayName: rawDisplayName,
      username: username,
      email: email,
      role: role,
      emailVerifiedAt: parseDate(json['email_verified_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'username': username,
      if (email != null) 'email': email,
      'role': role,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }
}

class AuthResponse {
  final bool success;
  final String message;
  final String accessToken;
  final String tokenType;
  final UserModel? user;

  const AuthResponse({
    required this.success,
    required this.message,
    this.accessToken = '',
    this.tokenType = 'Bearer',
    this.user,
  });

  String? get token => accessToken.isNotEmpty ? accessToken : null;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthResponse(
      success: true,
      message: json['message'] as String? ?? 'Login successful',
      accessToken: json['access_token'] as String? ??
          json['token'] as String? ??
          '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      user: userJson != null && userJson is Map<String, dynamic>
          ? UserModel.fromJson(userJson)
          : null,
    );
  }

  factory AuthResponse.success({
    required String token,
    required UserModel user,
    String message = 'Login berhasil',
    String tokenType = 'Bearer',
  }) {
    return AuthResponse(
      success: true,
      message: message,
      accessToken: token,
      tokenType: tokenType,
      user: user,
    );
  }

  factory AuthResponse.failed({required String message}) {
    return AuthResponse(
      success: false,
      message: message,
      accessToken: '',
      tokenType: 'Bearer',
      user: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'access_token': accessToken,
      'token_type': tokenType,
      if (user != null) 'user': user!.toJson(),
    };
  }
}
