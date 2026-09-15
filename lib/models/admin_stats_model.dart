import 'song_model.dart';
import 'user_account_model.dart';

class AdminStatsModel {
  final int totalSongs;
  final int totalUsers;
  final List<SongModel> recentSongs;
  final List<UserAccountModel> recentUsers;

  const AdminStatsModel({
    required this.totalSongs,
    required this.totalUsers,
    this.recentSongs = const [],
    this.recentUsers = const [],
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalSongs: json['totalSongs'] as int? ?? 0,
      totalUsers: json['totalUsers'] as int? ?? 0,
      recentSongs: (json['recentSongs'] as List<dynamic>?)
              ?.map((e) => SongModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recentUsers: (json['recentUsers'] as List<dynamic>?)
              ?.map((e) => UserAccountModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSongs': totalSongs,
      'totalUsers': totalUsers,
      'recentSongs': recentSongs.map((e) => e.toJson()).toList(),
      'recentUsers': recentUsers.map((e) => e.toJson()).toList(),
    };
  }
}
