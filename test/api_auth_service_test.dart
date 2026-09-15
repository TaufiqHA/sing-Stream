import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaoke_app/core/services/api_auth_service.dart';
import 'package:karaoke_app/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await StorageService.getInstance();
    await storageService.clearSession();
  });

  group('ApiAuthService Base URL Tests', () {
    test('uses custom base URL when supplied in constructor', () {
      final service = ApiAuthService(baseUrl: 'http://192.168.1.50:8000/api');
      expect(service.baseUrl, 'http://192.168.1.50:8000/api');
    });

    test('uses defaultCustomBaseUrl when static property set', () {
      ApiAuthService.defaultCustomBaseUrl = 'http://api.example.com/api';
      final service = ApiAuthService();
      expect(service.baseUrl, 'http://api.example.com/api');
      ApiAuthService.defaultCustomBaseUrl = null;
    });
  });

  group('ApiAuthService Login Tests', () {
    test('login succeeds with 200 OK and saves token/user to storage', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/login');
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body);
        expect(body['username'], 'testuser');
        expect(body['password'], 'secret123');

        return http.Response(
          jsonEncode({
            'message': 'Login successful',
            'access_token': '1|mock_token_abc123',
            'token_type': 'Bearer',
            'user': {
              'id': 1,
              'name': 'Test User',
              'username': 'testuser',
              'email': 'test@example.com',
              'role': 'user',
              'email_verified_at': '2026-08-30T07:28:55.000000Z',
              'created_at': '2026-08-30T07:28:55.000000Z',
              'updated_at': '2026-08-30T07:28:55.000000Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final result = await service.login('testuser', 'secret123');

      expect(result.success, isTrue);
      expect(result.accessToken, '1|mock_token_abc123');
      expect(result.user, isNotNull);
      expect(result.user!.username, 'testuser');
      expect(result.user!.name, 'Test User');
      expect(result.user!.isAdmin, isFalse);
      expect(result.user!.isUser, isTrue);

      // Verify stored in storage
      final storedToken = await storageService.getToken();
      expect(storedToken, '1|mock_token_abc123');
      final storedUser = await storageService.getUser();
      expect(storedUser?.username, 'testuser');
      expect(await storageService.isLoggedIn(), isTrue);
    });

    test('login fails with 401 Invalid credentials', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Invalid credentials',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final result = await service.login('wronguser', 'wrongpass');

      expect(result.success, isFalse);
      expect(result.message, 'Invalid credentials');
      expect(await storageService.isLoggedIn(), isFalse);
    });

    test('login handles 422 Validation error response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The username field is required. (and 1 more error)',
            'errors': {
              'username': ['The username field is required.'],
              'password': ['The password field is required.'],
            }
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final result = await service.login('user', 'pass');

      expect(result.success, isFalse);
      expect(result.message, 'The username field is required.');
    });

    test('login validation fails locally if empty username or password', () async {
      final service = ApiAuthService(
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final result = await service.login('  ', '');
      expect(result.success, isFalse);
      expect(result.message, contains('wajib diisi'));
    });
  });

  group('ApiAuthService Get Profile (Me) Tests', () {
    test('getProfile succeeds with 200 and Bearer token header', () async {
      await storageService.saveToken('valid_bearer_token');

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/me');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer valid_bearer_token');

        return http.Response(
          jsonEncode({
            'user': {
              'id': 99,
              'name': 'Admin Super',
              'username': 'admin',
              'email': 'admin@karaoke.com',
              'role': 'admin',
              'created_at': '2026-08-30T07:28:55.000000Z',
              'updated_at': '2026-08-30T07:28:55.000000Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final user = await service.getProfile();
      expect(user, isNotNull);
      expect(user!.id, 99);
      expect(user.isAdmin, isTrue);
      expect(user.displayName, 'Admin Super');

      // Verify user saved to storage
      final storedUser = await storageService.getUser();
      expect(storedUser?.username, 'admin');
    });

    test('getProfile with expired token (401) clears storage session', () async {
      await storageService.saveToken('expired_token');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Unauthenticated.'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(() => service.getProfile(), throwsException);
      // Let async complete and check storage
      try {
        await service.getProfile();
      } catch (_) {}
      expect(await storageService.getToken(), isNull);
    });
  });

  group('ApiAuthService Logout Tests', () {
    test('logout calls POST /api/logout and removes token & session', () async {
      await storageService.saveToken('active_token');

      bool logoutEndpointCalled = false;
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/logout');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer active_token');
        logoutEndpointCalled = true;

        return http.Response(
          jsonEncode({'message': 'Successfully logged out'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      await service.logout();

      expect(logoutEndpointCalled, isTrue);
      expect(await storageService.getToken(), isNull);
      expect(await storageService.isLoggedIn(), isFalse);
    });
  });

  group('ApiAuthService Update Profile Tests', () {
    test('updateProfile succeeds with 200 and updates storage', () async {
      await storageService.saveToken('user_token_123');

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/profile');
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer user_token_123');

        final body = jsonDecode(request.body);
        expect(body['name'], 'Nama Baru');
        expect(body['username'], 'user_baru');
        expect(body['email'], 'baru@mail.com');

        return http.Response(
          jsonEncode({
            'message': 'Profile updated successfully',
            'user': {
              'id': 1,
              'name': 'Nama Baru',
              'username': 'user_baru',
              'email': 'baru@mail.com',
              'role': 'user',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final updated = await service.updateProfile(
        name: 'Nama Baru',
        username: 'user_baru',
        email: 'baru@mail.com',
      );

      expect(updated.name, 'Nama Baru');
      expect(updated.username, 'user_baru');
      expect(updated.email, 'baru@mail.com');

      final stored = await storageService.getUser();
      expect(stored?.name, 'Nama Baru');
    });

    test('updateProfile throws on 422 validation error', () async {
      await storageService.saveToken('user_token_123');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The email has already been taken.',
            'errors': {
              'email': ['The email has already been taken.']
            }
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.updateProfile(
          name: 'Nama',
          username: 'user',
          email: 'duplicate@mail.com',
        ),
        throwsA(predicate((e) => e.toString().contains('The email has already been taken'))),
      );
    });
  });

  group('ApiAuthService Update Password Tests', () {
    test('updatePassword succeeds with 200', () async {
      await storageService.saveToken('user_token_123');

      bool endpointCalled = false;
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/profile/password');
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer user_token_123');

        final body = jsonDecode(request.body);
        expect(body['current_password'], 'oldPass123');
        expect(body['password'], 'newPass123');
        expect(body['password_confirmation'], 'newPass123');
        endpointCalled = true;

        return http.Response(
          jsonEncode({'message': 'Password updated successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      await service.updatePassword(
        currentPassword: 'oldPass123',
        newPassword: 'newPass123',
        newPasswordConfirmation: 'newPass123',
      );

      expect(endpointCalled, isTrue);
    });

    test('updatePassword throws on 422 incorrect current password', () async {
      await storageService.saveToken('user_token_123');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The password field confirmation does not match.',
            'errors': {
              'current_password': ['The current password is incorrect.']
            }
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiAuthService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.updatePassword(
          currentPassword: 'wrongPassword',
          newPassword: 'newPassword123',
          newPasswordConfirmation: 'newPassword123',
        ),
        throwsA(predicate((e) => e.toString().contains('The current password is incorrect.'))),
      );
    });
  });
}
