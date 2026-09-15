import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karaoke_app/core/services/api_nada_service.dart';
import 'package:karaoke_app/core/services/dummy_category_service.dart';
import 'package:karaoke_app/core/services/dummy_nada_service.dart';
import 'package:karaoke_app/core/services/dummy_song_service.dart';
import 'package:karaoke_app/core/services/storage_service.dart';
import 'package:karaoke_app/models/nada_model.dart';
import 'package:karaoke_app/screens/admin/song/admin_song_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'fake_token'});
    storageService = await StorageService.getInstance();
  });

  group('NadaModel Tests', () {
    test('fromJson and toJson should work correctly', () {
      final json = {
        'id': 1,
        'nada': 'Pria',
        'created_at': '2026-09-13T10:00:00.000000Z',
        'updated_at': '2026-09-13T10:00:00.000000Z',
      };

      final model = NadaModel.fromJson(json);
      expect(model.id, 1);
      expect(model.nada, 'Pria');
      expect(model.createdAt, DateTime.parse('2026-09-13T10:00:00.000000Z'));
      expect(model.updatedAt, DateTime.parse('2026-09-13T10:00:00.000000Z'));

      final serialized = model.toJson();
      expect(serialized['id'], 1);
      expect(serialized['nada'], 'Pria');
      expect(serialized['created_at'], '2026-09-13T10:00:00.000Z');
    });

    test('copyWith updates fields correctly', () {
      final model = NadaModel(id: 1, nada: 'Pria');
      final updated = model.copyWith(nada: 'Wanita');
      expect(updated.id, 1);
      expect(updated.nada, 'Wanita');
    });
  });

  group('DummyNadaService Tests', () {
    test('loads initial nadas (Pria, Wanita)', () async {
      final dummy = DummyNadaService();
      final list = await dummy.getNadas();
      expect(list.length, 2);
      expect(list.any((n) => n.nada == 'Pria'), isTrue);
      expect(list.any((n) => n.nada == 'Wanita'), isTrue);
    });

    test('creates and retrieves new nada', () async {
      final dummy = DummyNadaService();
      final created = await dummy.createNada('Duet');
      expect(created.id, isNotNull);
      expect(created.nada, 'Duet');

      final list = await dummy.getNadas();
      expect(list.length, 3);
      expect(list.any((n) => n.nada == 'Duet'), isTrue);
    });

    test('prevents creating duplicate nada case-insensitively', () async {
      final dummy = DummyNadaService();
      expect(
        () => dummy.createNada('pria'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('sudah terdaftar'),
        )),
      );
    });

    test('filters nadas with search', () async {
      final dummy = DummyNadaService();
      final results = await dummy.getNadas(search: 'pri');
      expect(results.length, 1);
      expect(results.first.nada, 'Pria');
    });

    test('updates and deletes nada', () async {
      final dummy = DummyNadaService();
      final updated = await dummy.updateNada(1, 'Pria Tinggi');
      expect(updated.nada, 'Pria Tinggi');

      final deleted = await dummy.deleteNada(1);
      expect(deleted, isTrue);

      final list = await dummy.getNadas();
      expect(list.any((n) => n.id == 1), isFalse);
    });
  });

  group('ApiNadaService Tests', () {
    test('getNadas succeeds with 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/nadas');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer fake_token');

        return http.Response(
          jsonEncode({
            'data': [
              {'id': 1, 'nada': 'Pria'},
              {'id': 2, 'nada': 'Wanita'},
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiNadaService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final nadas = await service.getNadas();
      expect(nadas.length, 2);
      expect(nadas[0].nada, 'Pria');
      expect(nadas[1].nada, 'Wanita');
    });

    test('getNadas supports search query param', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['search'], 'Wanita');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 2, 'nada': 'Wanita'},
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiNadaService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final nadas = await service.getNadas(search: 'Wanita');
      expect(nadas.length, 1);
      expect(nadas.first.nada, 'Wanita');
    });

    test('createNada succeeds with 201', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/nadas');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body);
        expect(body['nada'], 'Anak-anak');

        return http.Response(
          jsonEncode({
            'message': 'Nada created successfully',
            'data': {'id': 3, 'nada': 'Anak-anak'},
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiNadaService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final result = await service.createNada('Anak-anak');
      expect(result.id, 3);
      expect(result.nada, 'Anak-anak');
    });

    test('createNada throws formatted error on 422 validation failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Validation failed',
            'errors': {
              'nada': ['The nada field is already taken.']
            }
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiNadaService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.createNada('Pria'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('The nada field is already taken.'),
        )),
      );
    });

    test('getNada by id succeeds', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/nadas/1');
        return http.Response(
          jsonEncode({
            'data': {'id': 1, 'nada': 'Pria'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiNadaService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final nada = await service.getNada(1);
      expect(nada.id, 1);
      expect(nada.nada, 'Pria');
    });

    test('updateNada and deleteNada work correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'PUT') {
          expect(request.url.path, '/api/admin/nadas/1');
          return http.Response(
            jsonEncode({
              'data': {'id': 1, 'nada': 'Pria Baru'}
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'DELETE') {
          expect(request.url.path, '/api/admin/nadas/1');
          return http.Response(
            jsonEncode({'message': 'Nada deleted successfully'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ApiNadaService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final updated = await service.updateNada(1, 'Pria Baru');
      expect(updated.nada, 'Pria Baru');

      final deleted = await service.deleteNada(1);
      expect(deleted, isTrue);
    });
  });

  group('AdminSongScreen Nada Integration Widget Tests', () {
    testWidgets('renders dynamic nada chips and allows adding new nada via modal button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyNada = DummyNadaService();
      final dummySong = DummySongService();
      final dummyCategory = DummyCategoryService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSongScreen(
              songService: dummySong,
              categoryService: dummyCategory,
              nadaService: dummyNada,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open "Tambah Lagu" dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Lagu'));
      await tester.pumpAndSettle();

      // Check modal title, presence of "Tambah Nada" button and nada dropdown
      expect(find.text('Tambah Lagu Baru'), findsOneWidget);
      expect(find.text('Tambah Nada'), findsOneWidget);
      expect(find.byKey(const Key('nada_dropdown')), findsOneWidget);
      expect(find.text('-'), findsOneWidget);

      // Tap "Tambah Nada" button to open inner dialog
      await tester.tap(find.text('Tambah Nada'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Nada Baru'), findsOneWidget);

      // Enter new nada name in the topmost dialog's TextFormField
      final currentFields = find.byType(TextFormField);
      await tester.enterText(currentFields.last, 'Duet');
      await tester.pumpAndSettle();

      // Tap "Simpan" in the Add Nada dialog (the topmost/last Simpan button)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan').last);
      await tester.pumpAndSettle();

      // Verify the new nada is now in the chips and selected
      expect(find.text('Nada Duet'), findsOneWidget);
      expect(find.text('Nada "Duet" berhasil ditambahkan'), findsOneWidget);

      // Fill remaining song form fields
      final formFields = find.byType(TextFormField);
      await tester.enterText(formFields.at(0), 'Lagu Duet Baru');
      await tester.enterText(formFields.at(1), 'Penyanyi Duet');
      await tester.enterText(formFields.at(2), 'https://example.com/duet.mp3');
      await tester.enterText(formFields.at(3), '03:45');

      // Submit the song (button text is 'Simpan')
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();

      // Verify song is created with Nada Duet
      expect(find.text('Lagu Duet Baru'), findsOneWidget);
      expect(find.text('Nada: Duet'), findsOneWidget);
    });

    testWidgets('defaults nada dropdown to "-" and saves song with "-"', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyNada = DummyNadaService();
      final dummySong = DummySongService();
      final dummyCategory = DummyCategoryService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSongScreen(
              songService: dummySong,
              categoryService: dummyCategory,
              nadaService: dummyNada,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open "Tambah Lagu" dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Lagu'));
      await tester.pumpAndSettle();

      // Verify dropdown shows '-' by default
      expect(find.text('-'), findsOneWidget);

      // Fill song form fields
      final formFields = find.byType(TextFormField);
      await tester.enterText(formFields.at(0), 'Lagu Nada Strip');
      await tester.enterText(formFields.at(1), 'Penyanyi Strip');
      await tester.enterText(formFields.at(2), 'https://example.com/strip.mp3');
      await tester.enterText(formFields.at(3), '03:00');

      // Submit the song without changing nada
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();

      // Verify song is created
      expect(find.text('Lagu Nada Strip'), findsOneWidget);
    });
  });
}


