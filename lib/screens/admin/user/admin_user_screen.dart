import 'package:flutter/material.dart';

import '../../../core/services/api_user_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_account_model.dart';

class AdminUserScreen extends StatefulWidget {
  final UserService? userService;

  const AdminUserScreen({super.key, this.userService});

  @override
  State<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends State<AdminUserScreen> {
  late final UserService _userService;
  List<UserAccountModel> _users = [];
  List<UserAccountModel> _filteredUsers = [];

  bool _isLoading = true;
  String? _selectedRoleFilter; // null for 'all', 'admin', 'user'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? ApiUserService();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _userService.getUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal memuat pengguna: $e', isError: true);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredUsers = _users.where((u) {
        final matchQuery =
            query.isEmpty ||
            u.username.toLowerCase().contains(query) ||
            (u.name?.toLowerCase().contains(query) ?? false) ||
            (u.email?.toLowerCase().contains(query) ?? false) ||
            u.role.toLowerCase().contains(query) ||
            '#${u.userid}'.contains(query) ||
            '${u.userid}'.contains(query);

        final matchRole =
            _selectedRoleFilter == null ||
            u.role.toLowerCase() == _selectedRoleFilter!.toLowerCase();

        return matchQuery && matchRole;
      }).toList();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primaryElectric,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.accentCyan, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primaryElectric,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Future<void> _showUserFormDialog({UserAccountModel? user}) async {
    final isEditing = user != null;
    final usernameController = TextEditingController(
      text: user?.username ?? '',
    );
    final passwordController = TextEditingController(
      text: user?.password ?? '',
    );
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    String selectedRole = user?.role.toLowerCase() == 'admin'
        ? 'admin'
        : 'user';
    bool obscurePassword = true;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: AppColors.cardGlassBorder,
                  width: 1.2,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryElectric.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing
                          ? Icons.manage_accounts_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: AppColors.accentCyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Ubah Akun Pengguna' : 'Tambah Pengguna Baru',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    tooltip: 'Tutup',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Username
                          const Text(
                            'Username *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: usernameController,
                            autofocus: !isEditing,
                            maxLength: 30,
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => Text(
                                  '$currentLength/$maxLength',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              hint: 'Contoh: johndoe, admin_karaoke',
                              icon: Icons.alternate_email_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username wajib diisi';
                              }
                              if (value.trim().length > 30) {
                                return 'Username maksimal 30 karakter';
                              }
                              if (!RegExp(r'^[a-zA-Z0-9_.-]+$')
                                  .hasMatch(value.trim())) {
                                return 'Hanya huruf, angka, titik, underscore, dan strip';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // 2. Password
                          const Text(
                            'Password *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              hint: isEditing
                                  ? 'Masukkan password baru / tetap'
                                  : 'Minimal 4 karakter (API min 8)',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Password wajib diisi';
                              }
                              if (value.trim().length < 4) {
                                return 'Password minimal 4 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // 3. Nama Lengkap (Opsional di UI, otomatis terisi username jika kosong)
                          const Text(
                            'Nama Lengkap',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              hint: 'Contoh: John Doe (Opsional)',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Email (Opsional di UI, otomatis terisi username@karaoke.local jika kosong)
                          const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              hint: 'Contoh: john@example.com (Opsional)',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  return 'Format email tidak valid';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // 5. Role Selector (Segmented Button: Admin / User)
                          const Text(
                            'Peran Pengguna (Role) *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.inputBorder),
                            ),
                            child: Row(
                              children: [
                                // Admin Button
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      setDialogState(() {
                                        selectedRole = 'admin';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selectedRole == 'admin'
                                            ? Colors.amber.shade700
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.shield_rounded,
                                              size: 18,
                                              color: selectedRole == 'admin'
                                                  ? Colors.white
                                                  : Colors.amberAccent,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Administrator',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    selectedRole == 'admin'
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: selectedRole == 'admin'
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // User Button
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      setDialogState(() {
                                        selectedRole = 'user';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selectedRole == 'user'
                                            ? AppColors.primaryElectric
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.person_rounded,
                                              size: 18,
                                              color: selectedRole == 'user'
                                                  ? Colors.white
                                                  : AppColors.accentSky,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'User Biasa',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    selectedRole == 'user'
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: selectedRole == 'user'
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final inputUsername = usernameController.text.trim();
                      final inputPassword = passwordController.text.trim();
                      final inputName = nameController.text.trim();
                      final inputEmail = emailController.text.trim();

                      final finalName = inputName.isNotEmpty
                          ? inputName
                          : inputUsername;
                      final finalEmail = inputEmail.isNotEmpty
                          ? inputEmail
                          : (user?.email?.isNotEmpty == true
                                ? user!.email!
                                : '${inputUsername.toLowerCase()}@karaoke.local');

                      // Check uniqueness
                      final isExists = await _userService.isUsernameExists(
                        inputUsername,
                        excludeUserId: user?.userid,
                      );

                      if (isExists) {
                        if (context.mounted) {
                          _showSnackBar(
                            'Username "$inputUsername" sudah digunakan',
                            isError: true,
                          );
                        }
                        return;
                      }

                      try {
                        if (isEditing) {
                          final updated = user.copyWith(
                            username: inputUsername,
                            password: inputPassword,
                            role: selectedRole,
                            name: finalName,
                            email: finalEmail,
                          );
                          await _userService.updateUser(updated);
                        } else {
                          await _userService.createUser(
                            username: inputUsername,
                            password: inputPassword,
                            role: selectedRole,
                            name: finalName,
                            email: finalEmail,
                          );
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          final msg = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                          _showSnackBar(
                            'Gagal menyimpan pengguna: $msg',
                            isError: true,
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryElectric,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isEditing ? 'Simpan Perubahan' : 'Simpan Pengguna',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _showSnackBar(
        isEditing
            ? 'Data pengguna berhasil diperbarui'
            : 'Pengguna baru berhasil ditambahkan',
      );
      _loadUsers();
    }
  }

  Future<void> _showDeleteConfirmDialog(UserAccountModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: AppColors.cardGlassBorder,
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Hapus Pengguna',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                tooltip: 'Tutup',
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus akun pengguna "${user.username}" (ID: #${user.userid})?\n\nTindakan ini tidak dapat dibatalkan.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Hapus',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _userService.deleteUser(user.userid);
        _showSnackBar('Pengguna "${user.username}" berhasil dihapus');
        _loadUsers();
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _showSnackBar('Gagal menghapus pengguna: $msg', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUsers,
          color: AppColors.accentCyan,
          backgroundColor: AppColors.surfaceDark,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Section (Identical with AdminSongScreen & AdminCategoryScreen)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul & Tombol Tambah
                      Row(
                        children: [
                          const Text(
                            'Kelola User',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryElectric.withValues(
                                alpha: 0.25,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_users.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentSky,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => _showUserFormDialog(),
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Tambah User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryElectric,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Search Bar (Identical with AdminSongScreen)
                      SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _applyFilters(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari username, ID (#1), atau role...',
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.textMuted,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _applyFilters();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.cardGlass,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.cardGlassBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.cardGlassBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.accentCyan,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Filter Role Chips (ChoiceChips identical with AdminSongScreen)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Semua'),
                              selected: _selectedRoleFilter == null,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedRoleFilter = null;
                                    _applyFilters();
                                  });
                                }
                              },
                              selectedColor: AppColors.primaryElectric,
                              backgroundColor: AppColors.cardGlass,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedRoleFilter == null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedRoleFilter == null
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _selectedRoleFilter == null
                                      ? AppColors.accentCyan
                                      : AppColors.cardGlassBorder,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Admin'),
                              selected: _selectedRoleFilter == 'admin',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedRoleFilter = selected
                                      ? 'admin'
                                      : null;
                                  _applyFilters();
                                });
                              },
                              selectedColor: AppColors.primaryElectric,
                              backgroundColor: AppColors.cardGlass,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedRoleFilter == 'admin'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedRoleFilter == 'admin'
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _selectedRoleFilter == 'admin'
                                      ? AppColors.accentCyan
                                      : AppColors.cardGlassBorder,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('User'),
                              selected: _selectedRoleFilter == 'user',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedRoleFilter = selected
                                      ? 'user'
                                      : null;
                                  _applyFilters();
                                });
                              },
                              selectedColor: AppColors.primaryElectric,
                              backgroundColor: AppColors.cardGlass,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedRoleFilter == 'user'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedRoleFilter == 'user'
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _selectedRoleFilter == 'user'
                                      ? AppColors.accentCyan
                                      : AppColors.cardGlassBorder,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Users List (Identical padding & card architecture with AdminSongScreen)
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accentCyan,
                      ),
                    ),
                  ),
                )
              else if (_filteredUsers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_rounded,
                          size: 48,
                          color: AppColors.accentSky.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tidak ada pengguna ditemukan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Coba kata kunci lain atau tambah pengguna baru',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final user = _filteredUsers[index];
                      final isAdmin = user.isAdmin;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardGlass,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.cardGlassBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar (42x42 with AppColors.cardGradient & 10 radius)
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: AppColors.cardGradient,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.accentCyan.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    isAdmin
                                        ? Icons.shield_rounded
                                        : Icons.person_rounded,
                                    color: isAdmin
                                        ? Colors.amberAccent
                                        : AppColors.accentCyan,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // User Details (Single Clean Column with Subtitle if available)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.username,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Role Badge (Identical with Song Category Badge)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (isAdmin
                                                        ? Colors.amber
                                                        : AppColors
                                                              .primaryElectric)
                                                    .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isAdmin
                                                          ? Colors.amberAccent
                                                          : AppColors
                                                                .accentCyan)
                                                      .withValues(alpha: 0.3),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            user.role.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isAdmin
                                                  ? Colors.amberAccent
                                                  : AppColors.accentLight,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if ((user.name != null &&
                                            user.name!.trim().isNotEmpty &&
                                            user.name!.trim() !=
                                                user.username) ||
                                        (user.email != null &&
                                            user.email!.trim().isNotEmpty)) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        [
                                          if (user.name != null &&
                                              user.name!.trim().isNotEmpty &&
                                              user.name!.trim() !=
                                                  user.username)
                                            user.name!.trim(),
                                          if (user.email != null &&
                                              user.email!.trim().isNotEmpty)
                                            user.email!.trim(),
                                        ].join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Actions (Identical with AdminSongScreen & AdminCategoryScreen)
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                color: AppColors.accentCyan,
                                tooltip: 'Ubah',
                                onPressed: () =>
                                    _showUserFormDialog(user: user),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_rounded,
                                  size: 20,
                                ),
                                color: AppColors.error,
                                tooltip: 'Hapus',
                                onPressed: () => _showDeleteConfirmDialog(user),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: _filteredUsers.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
