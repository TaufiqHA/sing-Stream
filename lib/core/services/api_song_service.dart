import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../../models/song_model.dart';
import 'song_service.dart';
import 'storage_service.dart';

class ApiSongService implements SongService {
  final http.Client _client;
  final StorageService? storageService;
  final String? _customBaseUrl;

  ApiSongService({
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
  Future<List<SongModel>> getSongs({String? search, int? categoryId}) async {
    final queryParams = <String>[];
    if (search != null && search.trim().isNotEmpty) {
      queryParams.add('search=${Uri.encodeComponent(search.trim())}');
    }
    if (categoryId != null) {
      queryParams.add('songcategory=$categoryId');
    }

    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final url = Uri.parse('$baseUrl/songs$queryString');

    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        final rawList = data['data'];
        if (rawList is List) {
          return rawList
              .map((item) => SongModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Gagal memuat data lagu (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat lagu.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<SongModel> getSong(int id) async {
    final url = Uri.parse('$baseUrl/songs/$id');
    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        return SongModel.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        throw Exception('Lagu tidak ditemukan.');
      } else {
        throw Exception('Gagal memuat detail lagu (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat detail lagu.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<SongModel> createSong({
    required String songtitle,
    required String songsinger,
    required String songurl,
    required int songcategory,
    String? songnada,
    String? songduration,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/songs');
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'songtitle': songtitle.trim(),
              'songsinger': songsinger.trim(),
              'songurl': songurl.trim(),
              'songcategory': songcategory,
              if (songnada != null && songnada.trim().isNotEmpty)
                'songnada': songnada.trim(),
              if (songduration != null && songduration.trim().isNotEmpty)
                'songduration': songduration.trim(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      final Map<String, dynamic> data = _parseResponseBody(response.body);

      if (response.statusCode == 201) {
        return SongModel.fromJson(data['data'] as Map<String, dynamic>);
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
              'Gagal menambahkan lagu (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menambahkan lagu.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<SongModel> updateSong(SongModel song) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/songs/${song.songid}');
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
              'songtitle': song.songtitle.trim(),
              'songsinger': song.songsinger.trim(),
              'songurl': song.songurl.trim(),
              'songcategory': song.songcategory,
              'songnada': song.songnada?.trim().isNotEmpty == true ? song.songnada!.trim() : null,
              'songduration': song.songduration?.trim().isNotEmpty == true ? song.songduration!.trim() : null,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final Map<String, dynamic> data = _parseResponseBody(response.body);

      if (response.statusCode == 200) {
        return SongModel.fromJson(data['data'] as Map<String, dynamic>);
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
      } else if (response.statusCode == 404) {
        throw Exception('Lagu tidak ditemukan.');
      } else if (response.statusCode == 401) {
        final storage = await _getStorage();
        await storage.clearSession();
        throw Exception('Sesi login telah kedaluwarsa.');
      } else {
        throw Exception(
          data['message'] as String? ??
              'Gagal memperbarui lagu (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memperbarui lagu.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<bool> deleteSong(int songid) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/songs/$songid');
    try {
      final response = await _client
          .delete(
            url,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        throw Exception('Lagu tidak ditemukan.');
      } else if (response.statusCode == 401) {
        final storage = await _getStorage();
        await storage.clearSession();
        throw Exception('Sesi login telah kedaluwarsa.');
      } else {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        throw Exception(
          data['message'] as String? ??
              'Gagal menghapus lagu (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menghapus lagu.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
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
