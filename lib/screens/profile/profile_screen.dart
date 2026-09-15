import 'package:flutter/material.dart';
import '../../core/services/api_auth_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? initialUser;
  final StorageService? storageService;
  final UserService? userService;
  final AuthService? authService;
  final bool showBackButton;

  const ProfileScreen({
    super.key,
    this.initialUser,
    this.storageService,
    this.userService,
    this.authService,
    this.showBackButton = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late StorageService _storageService;
  late AuthService _authService;

  UserModel? _currentUser;
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Data Pribadi, 1: Keamanan

  // Controllers Data Pribadi
  final _profileFormKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSavingProfile = false;

  // Controllers Ganti Password
  final _passwordFormKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSavingPassword = false;

  @override
  void initState() {
    super.initState();
    _initServicesAndLoadUser();
  }

  Future<void> _initServicesAndLoadUser() async {
    _storageService = widget.storageService ?? await StorageService.getInstance();
    _authService = widget.authService ?? ApiAuthService(storageService: _storageService);

    // 1. Muat data instan dari cache lokal jika ada
    final cachedUser = widget.initialUser ?? await _storageService.getUser();

    if (mounted) {
      setState(() {
        _currentUser = cachedUser;
        _isLoading = false;
        if (cachedUser != null) {
          _displayNameController.text = cachedUser.displayName;
          _emailController.text = cachedUser.email ?? '';
        }
      });
    }

    // 2. Ambil data profil terbaru dari endpoint /me backend jika token tersedia
    final token = await _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      await _fetchProfileFromServer();
    }
  }

  Future<void> _fetchProfileFromServer({bool showFeedback = false}) async {
    final token = await _storageService.getToken();
    if (token == null || token.isEmpty) {
      if (showFeedback && mounted) {
        _showSnackBar('Tidak ada sesi aktif', isError: true);
      }
      return;
    }

    try {
      final latestUser = await _authService.getProfile();
      if (latestUser != null && mounted) {
        setState(() {
          _currentUser = latestUser;
          _isLoading = false;
          if (!_isSavingProfile) {
            _displayNameController.text = latestUser.displayName;
            _emailController.text = latestUser.email ?? '';
          }
        });

        if (showFeedback) {
          _showSnackBar('Data profil berhasil diperbarui');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (showFeedback) {
          _showSnackBar('Gagal memperbarui profil: $e', isError: true);
        }
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primaryElectric,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveProfileChanges() async {
    FocusScope.of(context).unfocus();
    if (!_profileFormKey.currentState!.validate() || _currentUser == null) return;

    setState(() => _isSavingProfile = true);

    try {
      final token = await _storageService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Sesi login telah berakhir. Silakan login kembali.');
      }

      final updatedUser = await _authService.updateProfile(
        name: _displayNameController.text.trim(),
        username: _currentUser!.username,
        email: _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
          _isSavingProfile = false;
        });
        _showSnackBar('Profil berhasil diperbarui!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingProfile = false);
        final errText = e.toString().replaceAll('Exception: ', '');
        _showSnackBar(errText, isError: true);
      }
    }
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (!_passwordFormKey.currentState!.validate() || _currentUser == null) return;

    setState(() => _isSavingPassword = true);

    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    try {
      final token = await _storageService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Sesi login telah berakhir. Silakan login kembali.');
      }

      await _authService.updatePassword(
        currentPassword: oldPass,
        newPassword: newPass,
        newPasswordConfirmation: confirmPass,
      );

      if (mounted) {
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _isSavingPassword = false);
        _showSnackBar('Kata sandi berhasil diperbarui!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingPassword = false);
        final errText = e.toString().replaceAll('Exception: ', '');
        _showSnackBar(errText, isError: true);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: AppColors.accentSky, size: 18),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputFocusedBorder, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
            ),
          )
        : RefreshIndicator(
            onRefresh: () => _fetchProfileFromServer(showFeedback: true),
            color: AppColors.accentCyan,
            backgroundColor: AppColors.surfaceDark,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header Section (Consistent with Admin screens)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row Title, Back Button, and Role Badge
                        Row(
                          children: [
                            if (widget.showBackButton) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: AppColors.accentSky,
                                  size: 18,
                                ),
                                tooltip: 'Kembali',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.of(context).pop(_currentUser),
                              ),
                              const SizedBox(width: 10),
                            ],
                            const Text(
                              'Manajemen Profil',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Kelola informasi akun dan pengaturan profil Anda',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Profile Summary Card
                      _buildProfileSummaryCard(),

                      const SizedBox(height: 16),

                      // 2. ChoiceChip Navigation Bar (Consistent with Admin filters)
                      _buildNavigationChips(),

                      const SizedBox(height: 16),

                      // 3. Tab Section Content
                      if (_selectedTab == 0) _buildPersonalInfoTab(),
                      if (_selectedTab == 1) _buildSecurityTab(),

                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: widget.showBackButton
          ? Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: SafeArea(child: content),
            )
          : SafeArea(child: content),
    );
  }

  Widget _buildProfileSummaryCard() {
    final user = _currentUser;
    final displayName = user?.displayName ?? 'Pengguna';
    final username = user?.username ?? 'user';
    final isAdmin = user?.isAdmin ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cardGlassBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Circular Avatar (Consistent with HomeScreen & AdminSidebar)
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.iconGradient,
              border: Border.all(
                color: AppColors.accentCyan,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.accentSky,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? AppColors.primaryElectric.withValues(alpha: 0.25)
                            : AppColors.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isAdmin
                              ? AppColors.accentSky.withValues(alpha: 0.35)
                              : AppColors.accentCyan.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAdmin ? Icons.shield_rounded : Icons.person_rounded,
                            size: 12,
                            color: isAdmin ? AppColors.accentSky : AppColors.accentCyan,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAdmin ? 'ADMINISTRATOR' : 'MEMBER KARAOKE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: isAdmin ? AppColors.accentSky : AppColors.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 5, color: Colors.greenAccent),
                          SizedBox(width: 4),
                          Text(
                            'Aktif',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationChips() {
    final tabs = [
      {'title': 'Data Pribadi', 'icon': Icons.person_rounded},
      {'title': 'Keamanan', 'icon': Icons.lock_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                tabs[index]['icon'] as IconData,
                size: 15,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
              label: Text(tabs[index]['title'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedTab = index);
                }
              },
              selectedColor: AppColors.primaryElectric,
              backgroundColor: AppColors.cardGlass,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(
                color: isSelected ? AppColors.accentCyan : AppColors.cardGlassBorder,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonalInfoTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardGlassBorder, width: 1.0),
      ),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Akun',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Perbarui nama tampilan dan alamat email profil Anda',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),

            // Nama Tampilan
            _buildFieldLabel('Nama Lengkap / Tampilan'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _displayNameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'Masukkan nama lengkap atau nama panggung',
                prefixIcon: Icons.badge_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama tampilan tidak boleh kosong';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Email
            _buildFieldLabel('Alamat Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'contoh@karaokeapp.com',
                prefixIcon: Icons.email_outlined,
              ),
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Format email tidak valid';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Username (Read-Only)
            _buildFieldLabel('Username'),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _currentUser?.username ?? '',
              readOnly: true,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'Username',
                prefixIcon: Icons.alternate_email_rounded,
                suffixIcon: const Tooltip(
                  message: 'Username bersifat unik dan tidak dapat diubah',
                  child: Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Role / Hak Akses (Read-Only)
            _buildFieldLabel('Hak Akses'),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: (_currentUser?.isAdmin ?? false) ? 'Administrator' : 'Pengguna Biasa (User)',
              readOnly: true,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'Hak Akses',
                prefixIcon: Icons.admin_panel_settings_outlined,
              ),
            ),

            const SizedBox(height: 22),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSavingProfile ? null : _saveProfileChanges,
              icon: _isSavingProfile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Simpan Perubahan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryElectric,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardGlassBorder, width: 1.0),
      ),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ubah Kata Sandi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gunakan kata sandi unik dengan minimal 6 karakter demi keamanan akun Anda',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),

            // Password Lama
            _buildFieldLabel('Kata Sandi Lama'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _oldPasswordController,
              obscureText: _obscureOldPassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'Masukkan kata sandi saat ini',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOldPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscureOldPassword = !_obscureOldPassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kata sandi lama wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Password Baru
            _buildFieldLabel('Kata Sandi Baru'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'Minimal 6 karakter',
                prefixIcon: Icons.key_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kata sandi baru wajib diisi';
                }
                if (value.trim().length < 6) {
                  return 'Kata sandi minimal 6 karakter';
                }
                if (value == _oldPasswordController.text) {
                  return 'Kata sandi baru tidak boleh sama dengan kata sandi lama';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Konfirmasi Password Baru
            _buildFieldLabel('Konfirmasi Kata Sandi Baru'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'Ketik ulang kata sandi baru',
                prefixIcon: Icons.lock_reset_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Konfirmasi kata sandi wajib diisi';
                }
                if (value != _newPasswordController.text) {
                  return 'Konfirmasi kata sandi tidak cocok';
                }
                return null;
              },
            ),

            const SizedBox(height: 22),

            // Submit Password Button
            ElevatedButton.icon(
              onPressed: _isSavingPassword ? null : _changePassword,
              icon: _isSavingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_reset_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Perbarui Kata Sandi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryElectric,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
