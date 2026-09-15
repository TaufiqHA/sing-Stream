import '../../models/user_model.dart';

abstract class AuthService {
  Future<AuthResponse> login(String username, String password);
  Future<UserModel?> getProfile();
  Future<void> logout();
  Future<String?> getToken();

  Future<UserModel> updateProfile({
    required String name,
    required String username,
    required String email,
  });

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  });
}
