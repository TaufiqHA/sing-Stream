import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_application_service.dart';
import '../../../core/services/application_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/application_model.dart';

class AdminSettingScreen extends StatefulWidget {
  final ApplicationService? applicationService;

  const AdminSettingScreen({
    super.key,
    this.applicationService,
  });

  @override
  State<AdminSettingScreen> createState() => _AdminSettingScreenState();
}

class _AdminSettingScreenState extends State<AdminSettingScreen> {
  late ApplicationService _applicationService;

  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _appNameController = TextEditingController();
  final _ads1Controller = TextEditingController();
  final _ads2Controller = TextEditingController();
  final _adsBottomController = TextEditingController();

  // Mode input iklan: 0 = Tautan Link, 1 = Unggah Gambar
  int _ads1Mode = 0;
  int _ads2Mode = 0;
  int _adsBottomMode = 0;

  int _applicationId = 1;
  bool _adsActive = true;
  bool _adsBottomActive = true;

  bool _isLoading = true;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _applicationService = widget.applicationService ?? ApiApplicationService();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await _applicationService.getApplicationConfig();
      if (mounted) {
        setState(() {
          _applicationId = config.applicationid;
          _companyController.text = config.applicationcompany;
          _appNameController.text = config.applicationname;
          _ads1Controller.text = config.applicationads1 ?? '';
          _ads2Controller.text = config.applicationads2 ?? '';
          _adsActive = config.isAdsActive;
          _adsBottomController.text = config.applicationadsbottom ?? '';
          _adsBottomActive = config.isAdsBottomActive;

          // Deteksi mode awal
          if (_ads1Controller.text.isNotEmpty && !_ads1Controller.text.startsWith('http')) {
            _ads1Mode = 1;
          }
          if (_ads2Controller.text.isNotEmpty && !_ads2Controller.text.startsWith('http')) {
            _ads2Mode = 1;
          }
          if (_adsBottomController.text.isNotEmpty && !_adsBottomController.text.startsWith('http')) {
            _adsBottomMode = 1;
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _appNameController.dispose();
    _ads1Controller.dispose();
    _ads2Controller.dispose();
    _adsBottomController.dispose();
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

  Future<void> _pickImage(TextEditingController controller) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          controller.text = image.path;
        });
        _showSnackBar('Gambar berhasil dipilih!');
      }
    } on MissingPluginException {
      if (mounted) {
        _showMissingPluginDialog(controller);
      }
    } catch (e) {
      if (e.toString().contains('MissingPluginException') ||
          e.toString().contains('No implementation found')) {
        if (mounted) {
          _showMissingPluginDialog(controller);
        }
      } else {
        _showSnackBar('Gagal memilih gambar: $e', isError: true);
      }
    }
  }

  Future<void> _showMissingPluginDialog(TextEditingController controller) async {
    final textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardGlassBorder),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline_rounded, color: AppColors.accentCyan, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Perlu Restart Aplikasi',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plugin pemilih galeri (image_picker) baru saja ditambahkan ke proyek. Agar plugin ini aktif di perangkat, aplikasi perlu dihentikan (stop) dan di-run ulang (flutter run).',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            const Text(
              'Atau masukkan path / nama file gambar secara manual:',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Contoh: banner-promo.png',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                setState(() {
                  controller.text = textController.text.trim();
                });
                _showSnackBar('Gambar berhasil disetel!');
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryElectric,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Simpan File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedConfig = ApplicationModel(
      applicationid: _applicationId,
      applicationcompany: _companyController.text.trim(),
      applicationname: _appNameController.text.trim(),
      applicationads1: _ads1Controller.text.trim().isEmpty ? null : _ads1Controller.text.trim(),
      applicationads2: _ads2Controller.text.trim().isEmpty ? null : _ads2Controller.text.trim(),
      applicationadsactive: _adsActive ? 'Y' : 'N',
      applicationadsbottom: _adsBottomController.text.trim().isEmpty ? null : _adsBottomController.text.trim(),
      applicationadsbottomactive: _adsBottomActive ? 'Y' : 'N',
    );

    try {
      final saved = await _applicationService.updateApplicationConfig(updatedConfig);
      if (mounted) {
        setState(() {
          _applicationId = saved.applicationid;
          _isSaving = false;
        });
        _showSnackBar('Pengaturan aplikasi berhasil disimpan!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        _showSnackBar('Gagal menyimpan pengaturan: $msg', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadConfig,
                color: AppColors.accentCyan,
                backgroundColor: AppColors.surfaceDark,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Header In-Page
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Pengaturan Aplikasi',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Konfigurasi data aplikasi dan iklan sistem',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Main Form
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Kartu Informasi Aplikasi & Instansi
                                _buildCompanyCard(),

                                const SizedBox(height: 16),

                                // 2. Kartu Konfigurasi Iklan Utama
                                _buildPrimaryAdsCard(),

                                const SizedBox(height: 16),

                                // 3. Kartu Konfigurasi Iklan Bawah
                                _buildBottomAdsCard(),

                                const SizedBox(height: 24),

                                // 4. Tombol Simpan
                                ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _saveSettings,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                                  label: const Text(
                                    'Simpan Pengaturan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryElectric,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                ),

                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCompanyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardGlassBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryElectric.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Profil & Instansi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Badge Application ID
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Text(
                  'ID: $_applicationId',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // applicationcompany (Nama Instansi)
          _buildFieldLabel('Nama Instansi *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _companyController,
            maxLength: 100,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'Contoh: PT Karaoke Musik Nusantara',
              prefixIcon: Icons.apartment_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama instansi wajib diisi';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // applicationname (Nama Aplikasi)
          _buildFieldLabel('Nama Aplikasi *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _appNameController,
            maxLength: 255,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'Contoh: Karaoke Mobile App',
              prefixIcon: Icons.apps_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama aplikasi wajib diisi';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryAdsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardGlassBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryElectric.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.ad_units_rounded,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Iklan Utama & Banner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // applicationadsactive Switch
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Status Iklan Utama',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _adsActive ? 'Iklan aktif dan ditayangkan' : 'Iklan dinonaktifkan',
                style: TextStyle(
                  color: _adsActive ? Colors.greenAccent : AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              value: _adsActive,
              activeThumbColor: AppColors.accentCyan,
              onChanged: (val) {
                setState(() => _adsActive = val);
              },
            ),
          ),

          Divider(color: AppColors.cardGlassBorder, height: 24),

          // Iklan 1
          _buildAdInputSlot(
            title: 'Iklan 1',
            controller: _ads1Controller,
            currentMode: _ads1Mode,
            onModeChanged: (mode) => setState(() => _ads1Mode = mode),
            hintText: 'https://contoh.com/banner-1.jpg atau script iklan',
          ),

          const SizedBox(height: 18),

          // Iklan 2
          _buildAdInputSlot(
            title: 'Iklan 2',
            controller: _ads2Controller,
            currentMode: _ads2Mode,
            onModeChanged: (mode) => setState(() => _ads2Mode = mode),
            hintText: 'https://contoh.com/banner-2.jpg atau script iklan',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAdsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardGlassBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryElectric.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.view_stream_rounded,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Iklan Bilah Bawah',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // applicationadsbottomactive Switch
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Status Iklan Bawah',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _adsBottomActive ? 'Iklan bawah aktif ditayangkan' : 'Iklan bawah dinonaktifkan',
                style: TextStyle(
                  color: _adsBottomActive ? Colors.greenAccent : AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              value: _adsBottomActive,
              activeThumbColor: AppColors.accentCyan,
              onChanged: (val) {
                setState(() => _adsBottomActive = val);
              },
            ),
          ),

          Divider(color: AppColors.cardGlassBorder, height: 24),

          // Iklan Bawah
          _buildAdInputSlot(
            title: 'Iklan Bawah',
            controller: _adsBottomController,
            currentMode: _adsBottomMode,
            onModeChanged: (mode) => setState(() => _adsBottomMode = mode),
            hintText: 'https://contoh.com/banner-bottom.jpg atau script iklan',
          ),
        ],
      ),
    );
  }

  Widget _buildAdInputSlot({
    required String title,
    required TextEditingController controller,
    required int currentMode,
    required ValueChanged<int> onModeChanged,
    required String hintText,
  }) {
    final value = controller.text.trim();
    final hasContent = value.isNotEmpty;
    final isNetworkUrl = value.startsWith('http://') || value.startsWith('https://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Label Slot Iklan di baris atas
        _buildFieldLabel(title),
        const SizedBox(height: 8),

        // 2. Full-Width Segmented Tab (100% Bebas Overflow)
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.inputBorder),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onModeChanged(0),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentMode == 0 ? AppColors.primaryElectric : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 15,
                          color: currentMode == 0 ? Colors.white : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tautan Link',
                          style: TextStyle(
                            color: currentMode == 0 ? Colors.white : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: currentMode == 0 ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () => onModeChanged(1),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentMode == 1 ? AppColors.primaryElectric : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_rounded,
                          size: 15,
                          color: currentMode == 1 ? Colors.white : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Unggah Gambar',
                          style: TextStyle(
                            color: currentMode == 1 ? Colors.white : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: currentMode == 1 ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Konten Berdasarkan Mode
        if (currentMode == 0) ...[
          // Mode Tautan Link (Single-line horizontal scroll)
          TextFormField(
            controller: controller,
            maxLines: 1,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration(
              hintText: hintText,
              prefixIcon: Icons.link_rounded,
              suffixIcon: hasContent
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                      tooltip: 'Bersihkan',
                      onPressed: () {
                        setState(() => controller.clear());
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),

          // Pratinjau Gambar Bersih untuk Tautan Link (hanya jika gambar berhasil dimuat)
          if (hasContent && isNetworkUrl) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                width: double.infinity,
                color: Colors.black26,
                child: Image.network(
                  value,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Jika URL gagal di-load / bukan URL gambar langsung, sembunyikan kotak error
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ] else ...[
          // Mode Unggah Gambar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: hasContent
                ? Row(
                    children: [
                      // Thumbnail Gambar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: Colors.black26,
                          child: isNetworkUrl
                              ? Image.network(
                                  value,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.image_rounded,
                                    color: AppColors.accentCyan,
                                  ),
                                )
                              : (!kIsWeb && File(value).existsSync()
                                  ? Image.file(File(value), fit: BoxFit.cover)
                                  : const Icon(
                                      Icons.image_rounded,
                                      color: AppColors.accentCyan,
                                    )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value.split(Platform.pathSeparator).last,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Gambar tersimpan',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.accentSky, size: 18),
                        tooltip: 'Ganti Gambar',
                        onPressed: () => _pickImage(controller),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                        tooltip: 'Hapus Gambar',
                        onPressed: () {
                          setState(() => controller.clear());
                        },
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () => _pickImage(controller),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryElectric.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              color: AppColors.accentCyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Pilih gambar dari galeri perangkat',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Format JPG, PNG, WEBP (maks. 5 MB)',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}
