import 'dart:async';
import '../../models/admin_stats_model.dart';
import 'admin_service.dart';
import 'dummy_song_service.dart';
import 'dummy_user_service.dart';

export 'admin_service.dart';

class DummyAdminService implements AdminService {
  final DummySongService _songService;
  final DummyUserService _userService;

  DummyAdminService({
    DummySongService? songService,
    DummyUserService? userService,
  })  : _songService = songService ?? DummySongService(),
        _userService = userService ?? DummyUserService();

  @override
  Future<AdminStatsModel> getStats() async {
    // Simulasi delay request data API (500 ms)
    await Future.delayed(const Duration(milliseconds: 500));

    final songs = await _songService.getSongs();
    final users = await _userService.getUsers();

    return AdminStatsModel(
      totalSongs: 1250,
      totalUsers: 348,
      recentSongs: songs.take(5).toList(),
      recentUsers: users.take(5).toList(),
    );
  }
}
