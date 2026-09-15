import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/admin_stats_model.dart';
import '../../models/song_model.dart';
import '../../models/user_account_model.dart';
import '../config/api_config.dart';
import 'admin_service.dart';
import 'storage_service.dart';

class ApiAdminService implements AdminService {
  final http.Client _client;
  final StorageService? storageService;
  final String? _customBaseUrl;

  ApiAdminService({
    http.Client? client,
    this.storageService,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _customBaseUrl = baseUrl;

  String get baseUrl => _customBaseUrl ?? ApiConfig.baseUrl;

  Future<StorageService> _getStorage() async {
    return storageService ?? await StorageService.getInstance();
  }

  Future<String?> _getToken() async {
    final storage = await _getStorage();
    return await storage.getToken();
  }

  @override
  Future<AdminStatsModel> getStats() async {
    final token = await _getToken();

    final headers = {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final songUrl = Uri.parse('$baseUrl/songs?page=1&per_page=5');
    final userUrl = Uri.parse('$baseUrl/admin/users?page=1&per_page=5');

    try {
      final futures = await Future.wait([
        _client.get(songUrl, headers: headers).timeout(const Duration(seconds: 5)),
        _client.get(userUrl, headers: headers).timeout(const Duration(seconds: 5)),
      ]);

      final songResp = futures[0];
      final userResp = futures[1];

      int totalSongs = 0;
      List<SongModel> recentSongs = [];
      if (songResp.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(songResp.body);
        if (data.containsKey('total') && data['total'] is int) {
          totalSongs = data['total'] as int;
        } else if (data['data'] is List) {
          totalSongs = (data['data'] as List).length;
        }
        if (data['data'] is List) {
          recentSongs = (data['data'] as List)
              .map((e) => SongModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      int totalUsers = 0;
      List<UserAccountModel> recentUsers = [];
      if (userResp.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(userResp.body);
        if (data.containsKey('total') && data['total'] is int) {
          totalUsers = data['total'] as int;
        } else if (data['data'] is List) {
          totalUsers = (data['data'] as List).length;
        }
        if (data['data'] is List) {
          recentUsers = (data['data'] as List)
              .map((e) => UserAccountModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      // Jika kedua request gagal
      if (songResp.statusCode != 200 && userResp.statusCode != 200) {
        throw Exception('Gagal memuat statistik admin (${songResp.statusCode}, ${userResp.statusCode}).');
      }

      return AdminStatsModel(
        totalSongs: totalSongs,
        totalUsers: totalUsers,
        recentSongs: recentSongs,
        recentUsers: recentUsers,
      );
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat statistik.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
