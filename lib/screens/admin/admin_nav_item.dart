import 'package:flutter/material.dart';
import 'admin_home_screen.dart';
import 'category/admin_category_screen.dart';
import 'setting/admin_setting_screen.dart';
import 'song/admin_song_screen.dart';
import 'user/admin_user_screen.dart';
import '../profile/profile_screen.dart';

class AdminNavItem {
  final String title;
  final IconData icon;
  final Widget page;

  const AdminNavItem({
    required this.title,
    required this.icon,
    required this.page,
  });
}

final List<AdminNavItem> adminNavItems = [
  const AdminNavItem(
    title: 'Beranda',
    icon: Icons.dashboard_rounded,
    page: AdminHomeScreen(),
  ),
  const AdminNavItem(
    title: 'Kategori',
    icon: Icons.category_rounded,
    page: AdminCategoryScreen(),
  ),
  const AdminNavItem(
    title: 'Kelola Lagu',
    icon: Icons.library_music_rounded,
    page: AdminSongScreen(),
  ),
  const AdminNavItem(
    title: 'Kelola User',
    icon: Icons.people_alt_rounded,
    page: AdminUserScreen(),
  ),
  const AdminNavItem(
    title: 'Profil Saya',
    icon: Icons.person_rounded,
    page: ProfileScreen(showBackButton: false),
  ),
  const AdminNavItem(
    title: 'Pengaturan',
    icon: Icons.settings_rounded,
    page: AdminSettingScreen(),
  ),
];
