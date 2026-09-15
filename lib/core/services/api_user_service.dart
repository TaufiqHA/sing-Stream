import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../../models/user_account_model.dart';
import 'storage_service.dart';
import 'user_service.dart';

class ApiUserService implements UserService {
  final http.Client _client;
  final StorageService? storageService;
  final String? _customBaseUrl;

  ApiUserService({
    http.Client? client,
    this.storageService,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _customBaseUrl = baseUrl;

  String get baseUrl {
    final custom = _customBaseUrl;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return ApiConfig.baseUrl;
  }

  Future<StorageService> _getStorage() async {
    return storageService ?? await StorageService.getInstance();
  }

  Future<String?> _getToken() async {
    final storage = await _getStorage();
    return await storage.getToken();
  }

  @override
  Future<List<UserAccountModel>> getUsers({String? search, String? role}) async {
    final params = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (role != null && role.trim().isNotEmpty) {
      params['role'] = role.trim();
    }

    final query = params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
    final url = Uri.parse('$baseUrl/admin/users$query');

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final http.Response response;
    try {
      response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat pengguna.');
    } catch (e) {
      throw Exception('Gagal menghubungi server.');
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = _parseResponseBody(response.body);
      final rawList = data['data'];
      if (rawList is List) {
        return rawList
            .map((item) => UserAccountModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } else if (response.statusCode == 403) {
      throw Exception('Akses ditolak. Diperlukan hak akses administrator.');
    } else if (response.statusCode == 401) {
      throw Exception('Sesi login telah kedaluwarsa.');
    } else {
      throw Exception('Gagal memuat pengguna (Status: ${response.statusCode}).');
    }
  }

  @override
  Future<UserAccountModel> createUser({
    required String username,
    required String password,
    required String role,
    String? name,
    String? email,
  }) async {
    final trimmedUsername = username.trim();
    final trimmedPassword = password.trim();
    final trimmedRole = role.trim().toLowerCase() == 'admin' ? 'admin' : 'user';
    final trimmedName = (name != null && name.trim().isNotEmpty) ? name.trim() : trimmedUsername;
    final trimmedEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : '${trimmedUsername.toLowerCase()}@karaoke.local';

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/admin/users');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'name': trimmedName,
      'username': trimmedUsername,
      'email': trimmedEmail,
      'password': trimmedPassword,
      'role': trimmedRole,
    });

    final http.Response response;
    try {
      response = await _client
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menambahkan pengguna.');
    } catch (e) {
      throw Exception('Gagal menghubungi server.');
    }

    final Map<String, dynamic> data = _parseResponseBody(response.body);

    if (response.statusCode == 201) {
      return UserAccountModel.fromJson(data['data'] as Map<String, dynamic>);
    } else if (response.statusCode == 422) {
      final err = _extractErrorMessage(data) ?? 'Validasi gagal.';
      throw Exception(err);
    } else if (response.statusCode == 403) {
      throw Exception('Akses ditolak. Diperlukan hak akses administrator.');
    } else if (response.statusCode == 401) {
      throw Exception('Sesi login telah kedaluwarsa.');
    } else {
      throw Exception('Gagal menambahkan pengguna (Status: ${response.statusCode}).');
    }
  }

  @override
  Future<UserAccountModel> updateUser(UserAccountModel user) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/admin/users/${user.userid}');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final Map<String, dynamic> payload = {
      'name': (user.name != null && user.name!.trim().isNotEmpty) ? user.name!.trim() : user.username.trim(),
      'username': user.username.trim(),
      'role': user.role.trim().toLowerCase() == 'admin' ? 'admin' : 'user',
    };

    if (user.email != null && user.email!.trim().isNotEmpty) {
      payload['email'] = user.email!.trim();
    }
    if (user.password.trim().isNotEmpty) {
      payload['password'] = user.password.trim();
    }

    final http.Response response;
    try {
      response = await _client
          .put(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memperbarui pengguna.');
    } catch (e) {
      throw Exception('Gagal menghubungi server.');
    }

    final Map<String, dynamic> data = _parseResponseBody(response.body);

    if (response.statusCode == 200) {
      return UserAccountModel.fromJson(data['data'] as Map<String, dynamic>);
    } else if (response.statusCode == 422) {
      final err = _extractErrorMessage(data) ?? 'Validasi gagal.';
      throw Exception(err);
    } else if (response.statusCode == 404) {
      throw Exception('Pengguna tidak ditemukan.');
    } else if (response.statusCode == 403) {
      throw Exception('Akses ditolak. Diperlukan hak akses administrator.');
    } else if (response.statusCode == 401) {
      throw Exception('Sesi login telah kedaluwarsa.');
    } else {
      throw Exception('Gagal memperbarui pengguna (Status: ${response.statusCode}).');
    }
  }

  @override
  Future<void> deleteUser(int userid) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/admin/users/$userid');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final http.Response response;
    try {
      response = await _client
          .delete(url, headers: headers)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menghapus pengguna.');
    } catch (e) {
      throw Exception('Gagal menghubungi server.');
    }

    if (response.statusCode == 200) {
      return;
    }

    final Map<String, dynamic> data = _parseResponseBody(response.body);

    if (response.statusCode == 403) {
      final msg = data['message'] as String? ?? 'Anda tidak dapat menghapus akun Anda sendiri.';
      throw Exception(msg);
    } else if (response.statusCode == 404) {
      throw Exception('Pengguna tidak ditemukan.');
    } else if (response.statusCode == 401) {
      throw Exception('Sesi login telah kedaluwarsa.');
    } else {
      throw Exception('Gagal menghapus pengguna (Status: ${response.statusCode}).');
    }
  }

  @override
  Future<bool> isUsernameExists(String username, {int? excludeUserId}) async {
    final users = await getUsers(search: username);
    final normalized = username.trim().toLowerCase();
    return users.any((u) =>
        u.username.trim().toLowerCase() == normalized &&
        (excludeUserId == null || u.userid != excludeUserId));
  }

  @override
  Future<bool> changePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    throw UnimplementedError('Gunakan ApiAuthService.updatePassword untuk mengubah kata sandi.');
  }

  Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String? _extractErrorMessage(Map<String, dynamic> data) {
    if (data.containsKey('errors') && data['errors'] is Map) {
      final errors = data['errors'] as Map<String, dynamic>;
      for (final key in errors.keys) {
        final val = errors[key];
        if (val is List && val.isNotEmpty) {
          return val.first.toString();
        } else if (val is String) {
          return val;
        }
      }
    }
    if (data.containsKey('message') && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
