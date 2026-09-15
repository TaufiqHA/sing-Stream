import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import 'admin_nav_item.dart';
import 'admin_sidebar.dart';

class AdminMainLayout extends StatefulWidget {
  final int initialIndex;

  const AdminMainLayout({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  late int _selectedIndex;
  UserModel? _currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Daftar halaman anak yang di-keep tetap aktif dalam memori (IndexedStack)
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pages = adminNavItems.map((item) => item.page).toList();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final storage = await StorageService.getInstance();
    final user = await storage.getUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  void _onItemSelected(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      _loadUserData();
    }

    // Jika drawer terbuka pada layar kecil, tutup drawer setelah item dipilih
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminName = _currentUser?.displayName ?? 'Admin';
    final adminUsername = _currentUser?.username ?? 'admin';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          // Layout Layar Lebar: Sidebar Permanen di Kiri + Konten di Kanan
          return Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Row(
                children: [
                  // Persistent Sidebar (Tidak pernah di-recreate / re-render saat ganti halaman)
                  AdminSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _onItemSelected,
                    adminName: adminName,
                    adminUsername: adminUsername,
                  ),

                  // Area Konten Utama (Menggunakan IndexedStack untuk transisi instan)
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Layout Layar Kecil (Mobile): AppBar dengan Hamburger Drawer
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppColors.primaryDark,
            appBar: AppBar(
              backgroundColor: AppColors.primaryNavy,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.accentSky),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.iconGradient,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'asset/image/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tomsi Karaoke',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            drawer: Drawer(
              backgroundColor: AppColors.primaryNavy,
              child: AdminSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onItemSelected,
                adminName: adminName,
                adminUsername: adminUsername,
              ),
            ),
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          );
        }
      },
    );
  }
}
