import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karaoke_app/core/services/api_song_service.dart';
import 'package:karaoke_app/core/services/storage_service.dart';
import 'package:karaoke_app/models/song_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await StorageService.getInstance();
  });

  group('ApiSongService getSongs Tests', () {
    test('getSongs succeeds with 200 without query params', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/songs');
        expect(request.method, 'GET');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'songid': 1,
                'songtitle': 'Separuh Nafas',
                'songsinger': 'Dewa 19',
                'songurl': 'https://example.com/separuh-nafas.mp4',
                'songcategory': 1,
                'songnada': 'Pria',
                'songduration': '4:30',
                'category': {
                  'songcategoryid': 1,
                  'songcategoryname': 'Pop',
                }
              },
              {
                'songid': 2,
                'songtitle': 'Hati-Hati di Jalan',
                'songsinger': 'Tulus',
                'songurl': 'https://example.com/hati-hati.mp4',
                'songcategory': 1,
                'songnada': 'Pria',
                'songduration': '4:02',
                'category': {
                  'songcategoryid': 1,
                  'songcategoryname': 'Pop',
                }
              },
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final list = await service.getSongs();
      expect(list.length, 2);
      expect(list[0].songid, 1);
      expect(list[0].songtitle, 'Separuh Nafas');
      expect(list[0].category?.name, 'Pop');
      expect(list[1].songid, 2);
      expect(list[1].songsinger, 'Tulus');
    });

    test('getSongs appends search and categoryId query parameters', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/songs');
        expect(request.url.queryParameters['search'], 'Separuh');
        expect(request.url.queryParameters['songcategory'], '1');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'songid': 1,
                'songtitle': 'Separuh Nafas',
                'songsinger': 'Dewa 19',
                'songurl': 'https://example.com/separuh-nafas.mp4',
                'songcategory': 1,
              },
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final list = await service.getSongs(search: 'Separuh', categoryId: 1);
      expect(list.length, 1);
      expect(list.first.songtitle, 'Separuh Nafas');
    });

    test('getSongs throws Exception on network failure', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(() => service.getSongs(), throwsA(isA<Exception>()));
    });
  });

  group('ApiSongService getSong (Detail) Tests', () {
    test('getSong succeeds with 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/songs/1');
        expect(request.method, 'GET');

        return http.Response(
          jsonEncode({
            'data': {
              'songid': 1,
              'songtitle': 'Separuh Nafas',
              'songsinger': 'Dewa 19',
              'songurl': 'https://example.com/separuh-nafas.mp4',
              'songcategory': 1,
              'category': {
                'songcategoryid': 1,
                'songcategoryname': 'Pop',
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final song = await service.getSong(1);
      expect(song.songid, 1);
      expect(song.songtitle, 'Separuh Nafas');
      expect(song.category?.name, 'Pop');
    });

    test('getSong throws on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Not Found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.getSong(999),
        throwsA(predicate((e) => e.toString().contains('Lagu tidak ditemukan'))),
      );
    });
  });

  group('ApiSongService createSong Tests', () {
    test('createSong sends POST with Bearer token and returns created song', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/songs');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer admin_token_xyz');

        final body = jsonDecode(request.body);
        expect(body['songtitle'], 'Hati-Hati di Jalan');
        expect(body['songsinger'], 'Tulus');
        expect(body['songcategory'], 1);
        expect(body['songnada'], 'Pria');

        return http.Response(
          jsonEncode({
            'message': 'Song created successfully',
            'data': {
              'songid': 10,
              'songtitle': 'Hati-Hati di Jalan',
              'songsinger': 'Tulus',
              'songurl': 'https://example.com/hati-hati.mp4',
              'songcategory': 1,
              'songnada': 'Pria',
              'songduration': '4:02',
              'category': {
                'songcategoryid': 1,
                'songcategoryname': 'Pop',
              }
            }
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final created = await service.createSong(
        songtitle: 'Hati-Hati di Jalan',
        songsinger: 'Tulus',
        songurl: 'https://example.com/hati-hati.mp4',
        songcategory: 1,
        songnada: 'Pria',
        songduration: '4:02',
      );

      expect(created.songid, 10);
      expect(created.songtitle, 'Hati-Hati di Jalan');
      expect(created.songsinger, 'Tulus');
      expect(created.category?.name, 'Pop');
    });

    test('createSong throws on 422 validation error', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The songcategory field is required.',
            'errors': {
              'songcategory': ['The selected songcategory is invalid.']
            }
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.createSong(
          songtitle: 'Invalid Song',
          songsinger: 'Unknown',
          songurl: 'https://example.com/song.mp3',
          songcategory: 999,
        ),
        throwsA(predicate((e) => e.toString().contains('The selected songcategory is invalid'))),
      );
    });
  });

  group('ApiSongService updateSong Tests', () {
    test('updateSong sends PUT with Bearer token and returns updated song', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/songs/10');
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer admin_token_xyz');

        final body = jsonDecode(request.body);
        expect(body['songtitle'], 'Hati-Hati di Jalan (Remix)');

        return http.Response(
          jsonEncode({
            'message': 'Song updated successfully',
            'data': {
              'songid': 10,
              'songtitle': 'Hati-Hati di Jalan (Remix)',
              'songsinger': 'Tulus',
              'songurl': 'https://example.com/hati-hati.mp4',
              'songcategory': 1,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      const songToUpdate = SongModel(
        songid: 10,
        songtitle: 'Hati-Hati di Jalan (Remix)',
        songsinger: 'Tulus',
        songurl: 'https://example.com/hati-hati.mp4',
        songcategory: 1,
      );

      final updated = await service.updateSong(songToUpdate);
      expect(updated.songid, 10);
      expect(updated.songtitle, 'Hati-Hati di Jalan (Remix)');
    });

    test('updateSong throws on 404 not found', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Not Found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      const nonExistent = SongModel(
        songid: 999,
        songtitle: 'Ghost',
        songsinger: 'Nobody',
        songurl: 'https://example.com/ghost.mp3',
        songcategory: 1,
      );

      expect(
        () => service.updateSong(nonExistent),
        throwsA(predicate((e) => e.toString().contains('Lagu tidak ditemukan'))),
      );
    });
  });

  group('ApiSongService deleteSong Tests', () {
    test('deleteSong sends DELETE with Bearer token and returns true', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/songs/10');
        expect(request.method, 'DELETE');
        expect(request.headers['Authorization'], 'Bearer admin_token_xyz');

        return http.Response(
          jsonEncode({'message': 'Song deleted successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final result = await service.deleteSong(10);
      expect(result, isTrue);
    });

    test('deleteSong throws on 404 not found', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Not Found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiSongService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.deleteSong(999),
        throwsA(predicate((e) => e.toString().contains('Lagu tidak ditemukan'))),
      );
    });
  });
}
