import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/api_admin_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/admin_stats_model.dart';

class AdminHomeScreen extends StatefulWidget {
  final AdminService? adminService;

  const AdminHomeScreen({super.key, this.adminService});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late final AdminService _adminService;
  AdminStatsModel? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _adminService = widget.adminService ?? ApiAdminService();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _adminService.getStats();
      if (mounted) {
        setState(() {
          _stats = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: AppColors.accentCyan,
          backgroundColor: AppColors.surfaceDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title
                const Text(
                  'Beranda Admin',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ringkasan data sistem Melindastore Youtube Stream Karaoke',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 28),

                // Statistics Section (Total Lagu & Total User)
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                      ),
                    ),
                  )
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;

                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total Lagu Diinput',
                                    value: _formatNumber(_stats?.totalSongs ?? 0),
                                    subtitle: 'Lagu siap dinyanyikan',
                                    icon: Icons.music_note_rounded,
                                    gradientColors: [
                                      AppColors.primaryRoyal,
                                      AppColors.primaryElectric,
                                    ],
                                    accentColor: AppColors.accentSky,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total User Terdaftar',
                                    value: _formatNumber(_stats?.totalUsers ?? 0),
                                    subtitle: 'Pengguna aktif sistem',
                                    icon: Icons.people_alt_rounded,
                                    gradientColors: [
                                      const Color(0xFF0F4C81),
                                      const Color(0xFF1B6CA8),
                                    ],
                                    accentColor: AppColors.accentNeon,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildStatCard(
                                  title: 'Total Lagu Diinput',
                                  value: _formatNumber(_stats?.totalSongs ?? 0),
                                  subtitle: 'Lagu siap dinyanyikan',
                                  icon: Icons.music_note_rounded,
                                  gradientColors: [
                                    AppColors.primaryRoyal,
                                    AppColors.primaryElectric,
                                  ],
                                  accentColor: AppColors.accentSky,
                                ),
                                const SizedBox(height: 18),
                                _buildStatCard(
                                  title: 'Total User Terdaftar',
                                  value: _formatNumber(_stats?.totalUsers ?? 0),
                                  subtitle: 'Pengguna aktif sistem',
                                  icon: Icons.people_alt_rounded,
                                  gradientColors: [
                                    const Color(0xFF0F4C81),
                                    const Color(0xFF1B6CA8),
                                  ],
                                  accentColor: AppColors.accentNeon,
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
