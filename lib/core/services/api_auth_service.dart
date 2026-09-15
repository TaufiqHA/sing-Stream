import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../../models/user_model.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class ApiAuthService implements AuthService {
  final http.Client _client;
  final StorageService? storageService;
  final String? _customBaseUrl;

  static String? get defaultCustomBaseUrl => ApiConfig.customBaseUrl;
  static set defaultCustomBaseUrl(String? value) => ApiConfig.customBaseUrl = value;

  ApiAuthService({http.Client? client, this.storageService, String? baseUrl})
    : _client = client ?? http.Client(),
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

  @override
  Future<String?> getToken() async {
    final storage = await _getStorage();
    return await storage.getToken();
  }

  @override
  Future<AuthResponse> login(String username, String password) async {
    final trimmedUser = username.trim();
    final trimmedPass = password;

    if (trimmedUser.isEmpty || trimmedPass.isEmpty) {
      return AuthResponse.failed(message: 'Username dan Password wajib diisi');
    }

    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': trimmedUser,
              'password': trimmedPass,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final Map<String, dynamic> data = _parseResponseBody(response.body);

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(data);
        final storage = await _getStorage();

        if (authResponse.token != null && authResponse.user != null) {
          await storage.saveAuthSession(
            token: authResponse.token!,
            user: authResponse.user!,
          );
        }

        return authResponse;
      } else if (response.statusCode == 401) {
        final message =
            data['message'] as String? ?? 'Username atau password salah.';
        return AuthResponse.failed(message: message);
      } else if (response.statusCode == 422) {
        String errorMsg = data['message'] as String? ?? 'Validasi gagal.';
        if (data['errors'] is Map<String, dynamic>) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty &&
              errors.values.first is List &&
              (errors.values.first as List).isNotEmpty) {
            errorMsg = (errors.values.first as List).first.toString();
          }
        }
        return AuthResponse.failed(message: errorMsg);
      } else {
        final message =
            data['message'] as String? ??
            'Terjadi kesalahan pada server (${response.statusCode}).';
        return AuthResponse.failed(message: message);
      }
    } on TimeoutException {
      return AuthResponse.failed(
        message:
            'Waktu koneksi habis ($baseUrl). Pastikan backend aktif dengan php artisan serve --host=0.0.0.0.',
      );
    } catch (_) {
      return AuthResponse.failed(
        message:
            'Gagal terhubung ke server ($baseUrl). Pastikan backend berjalan dan perangkat berada di Wi-Fi yang sama.',
      );
    }
  }

  @override
  Future<UserModel?> getProfile() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final url = Uri.parse('$baseUrl/me');

    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 4));

      final Map<String, dynamic> data = _parseResponseBody(response.body);

      if (response.statusCode == 200) {
        final userJson = data['user'];
        if (userJson != null && userJson is Map<String, dynamic>) {
          final user = UserModel.fromJson(userJson);
          final storage = await _getStorage();
          await storage.saveUser(user);
          return user;
        }
        throw Exception('Format data user tidak valid.');
      } else if (response.statusCode == 401) {
        final storage = await _getStorage();
        await storage.clearSession();
        throw Exception('Sesi login telah kedaluwarsa.');
      } else {
        throw Exception(
          data['message'] as String? ??
              'Gagal mengambil data profil (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memeriksa profil pengguna.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server untuk mengambil data profil.');
    }
  }

  @override
  Future<void> logout() async {
    final token = await getToken();
    final storage = await _getStorage();

    if (token != null && token.isNotEmpty) {
      try {
        final url = Uri.parse('$baseUrl/logout');
        await _client
            .post(
              url,
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Abaikan kegagalan jaringan saat logout agar sesi lokal tetap dibersihkan
      }
    }

    await storage.clearSession();
  }

  @override
  Future<UserModel> updateProfile({
    required String name,
    required String username,
    required String email,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final url = Uri.parse('$baseUrl/profile');
    try {
      final response = await _client
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name': name,
              'username': username,
              'email': email,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final Map<String, dynamic> data = _parseResponseBody(response.body);

      if (response.statusCode == 200) {
        final userJson = data['user'];
        if (userJson != null && userJson is Map<String, dynamic>) {
          final updatedUser = UserModel.fromJson(userJson);
          final storage = await _getStorage();
          await storage.saveUser(updatedUser);
          return updatedUser;
        }
        throw Exception('Format respons server tidak valid.');
      } else if (response.statusCode == 422) {
        String errorMsg = data['message'] as String? ?? 'Validasi gagal.';
        if (data['errors'] is Map<String, dynamic>) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty &&
              errors.values.first is List &&
              (errors.values.first as List).isNotEmpty) {
            errorMsg = (errors.values.first as List).first.toString();
          }
        }
        throw Exception(errorMsg);
      } else if (response.statusCode == 401) {
        final storage = await _getStorage();
        await storage.clearSession();
        throw Exception('Sesi login telah kedaluwarsa.');
      } else {
        throw Exception(
          data['message'] as String? ??
              'Gagal memperbarui profil (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memperbarui profil.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server untuk memperbarui profil.');
    }
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final url = Uri.parse('$baseUrl/profile/password');
    try {
      final response = await _client
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'password': newPassword,
              'password_confirmation': newPasswordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final Map<String, dynamic> data = _parseResponseBody(response.body);

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 422) {
        String errorMsg = data['message'] as String? ??
            'Password lama salah atau konfirmasi tidak cocok.';
        if (data['errors'] is Map<String, dynamic>) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty &&
              errors.values.first is List &&
              (errors.values.first as List).isNotEmpty) {
            errorMsg = (errors.values.first as List).first.toString();
          }
        }
        throw Exception(errorMsg);
      } else if (response.statusCode == 401) {
        final storage = await _getStorage();
        await storage.clearSession();
        throw Exception('Sesi login telah kedaluwarsa.');
      } else {
        throw Exception(
          data['message'] as String? ??
              'Gagal mengubah password (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memperbarui kata sandi.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server untuk memperbarui kata sandi.');
    }
  }

  Map<String, dynamic> _parseResponseBody(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return {};
  }
}
