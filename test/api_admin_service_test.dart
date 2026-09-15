import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karaoke_app/core/services/api_admin_service.dart';
import 'package:karaoke_app/core/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'dummy_jwt_token',
    });
    storageService = await StorageService.getInstance();
    await storageService.saveToken('dummy_jwt_token');
  });

  group('ApiAdminService getStats Tests', () {
    test('getStats succeeds and parses paginated songs and users', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/songs') {
          return http.Response(
            jsonEncode({
              'total': 88,
              'data': [
                {
                  'songid': 10,
                  'songtitle': 'Separuh Nafas',
                  'songsinger': 'Dewa 19',
                  'songurl': 'https://example.com/audio.mp3',
                  'songcategory': 1,
                  'songduration': '04:12',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/admin/users') {
          expect(request.headers['Authorization'], 'Bearer dummy_jwt_token');
          return http.Response(
            jsonEncode({
              'total': 42,
              'data': [
                {
                  'id': 5,
                  'name': 'Ahmad Dhani',
                  'username': 'ahmaddhani',
                  'email': 'dhani@dewa19.com',
                  'role': 'admin',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ApiAdminService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final stats = await service.getStats();
      expect(stats.totalSongs, 88);
      expect(stats.totalUsers, 42);
      expect(stats.recentSongs.length, 1);
      expect(stats.recentSongs.first.songtitle, 'Separuh Nafas');
      expect(stats.recentUsers.length, 1);
      expect(stats.recentUsers.first.username, 'ahmaddhani');
    });

    test('getStats succeeds with non-paginated response structure', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/songs') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'songid': 1,
                  'songtitle': 'Song 1',
                  'songsinger': 'Singer 1',
                  'songurl': 'url1',
                  'songcategory': 1,
                },
                {
                  'songid': 2,
                  'songtitle': 'Song 2',
                  'songsinger': 'Singer 2',
                  'songurl': 'url2',
                  'songcategory': 1,
                },
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/admin/users') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 1,
                  'username': 'user1',
                  'role': 'user',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ApiAdminService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final stats = await service.getStats();
      expect(stats.totalSongs, 2);
      expect(stats.totalUsers, 1);
      expect(stats.recentSongs.length, 2);
      expect(stats.recentUsers.length, 1);
    });

    test('getStats throws Exception on server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = ApiAdminService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(() => service.getStats(), throwsA(isA<Exception>()));
    });
  });
}
