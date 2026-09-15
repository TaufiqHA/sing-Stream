import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/cast/cast_device_model.dart';
import '../../../services/cast/smart_tv_cast_service.dart';

/// Modal dialog pemilihan perangkat Smart TV (Ultra-Minimalis, Bersih, Tanpa Subteks).
class CastDeviceModal extends StatefulWidget {
  final SmartTvCastService castService;
  final String? currentVideoId;
  final String? songTitle;
  final String? songSinger;
  final String? songThumbnail;
  final VoidCallback? onDeviceChanged;

  const CastDeviceModal({
    super.key,
    required this.castService,
    this.currentVideoId,
    this.songTitle,
    this.songSinger,
    this.songThumbnail,
    this.onDeviceChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required SmartTvCastService castService,
    String? currentVideoId,
    String? songTitle,
    String? songSinger,
    String? songThumbnail,
    VoidCallback? onDeviceChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CastDeviceModal(
        castService: castService,
        currentVideoId: currentVideoId,
        songTitle: songTitle,
        songSinger: songSinger,
        songThumbnail: songThumbnail,
        onDeviceChanged: onDeviceChanged,
      ),
    );
  }

  @override
  State<CastDeviceModal> createState() => _CastDeviceModalState();
}

class _CastDeviceModalState extends State<CastDeviceModal> {
  final TextEditingController _codeController = TextEditingController();
  List<CastDevice> _devices = [];
  bool _isLoading = true;
  String? _connectingDeviceId;
  bool _isConnectingWithCode = false;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _connectedDeviceSubscription;

  @override
  void initState() {
    super.initState();
    _devices = widget.castService.discoveredDevices;
    _devicesSubscription = widget.castService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });
    _connectedDeviceSubscription = widget.castService.connectedDeviceStream.listen((_) {
      if (mounted) setState(() {});
    });
    _startScan();
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _connectedDeviceSubscription?.cancel();
    _codeController.dispose();
    widget.castService.stopDiscovery();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    await widget.castService.startContinuousDiscovery();

    if (mounted) {
      setState(() {
        _devices = widget.castService.discoveredDevices;
      });
    }
  }

  Future<void> _connect(CastDevice device) async {
    if (_connectingDeviceId != null || _isConnectingWithCode) return;
    setState(() {
      _connectingDeviceId = device.id;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await widget.castService.connect(device);
      bool castOk = true;
      if (widget.currentVideoId != null) {
        castOk = await widget.castService.castVideo(
          widget.currentVideoId!,
          title: widget.songTitle,
          artist: widget.songSinger,
          thumbnailUrl: widget.songThumbnail,
        );
      } else {
        await widget.castService.wakeOrLaunchApp(device);
      }
      widget.onDeviceChanged?.call();
      if (mounted) {
        Navigator.of(context).pop();
        if (success && !widget.castService.isTestMode) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.tv_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.currentVideoId != null
                          ? (castOk
                              ? 'Terhubung ke ${device.name}. Video sedang diputar di TV.'
                              : 'Terhubung ke ${device.name}. Jika belum tampil di TV, izinkan koneksi menggunakan remote TV.')
                          : 'Terhubung ke ${device.name}. Putar lagu untuk bernyanyi di TV.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: castOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted && !widget.castService.isTestMode) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gagal menghubungkan ke ${device.name}. Pastikan TV menyala dan satu jaringan Wi-Fi.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectingDeviceId = null;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await widget.castService.disconnect();
    widget.onDeviceChanged?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _connectWithCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _isConnectingWithCode || _connectingDeviceId != null) return;

    setState(() {
      _isConnectingWithCode = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await widget.castService.connectWithTvCode(code);
      if (!success) {
        if (mounted && !widget.castService.isTestMode) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kode TV ($code) tidak valid, telah kedaluwarsa, atau sesi TV gagal dibuat. Silakan periksa kode di aplikasi YouTube TV Anda.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      bool castOk = true;
      if (widget.currentVideoId != null) {
        castOk = await widget.castService.castVideo(
          widget.currentVideoId!,
          title: widget.songTitle,
          artist: widget.songSinger,
          thumbnailUrl: widget.songThumbnail,
        );
      }
      widget.onDeviceChanged?.call();
      if (mounted) {
        Navigator.of(context).pop();
        if (!widget.castService.isTestMode) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    castOk ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.currentVideoId != null
                          ? (castOk
                              ? 'Terhubung dengan Kode TV ($code). Video sedang diputar di TV.'
                              : 'Terhubung ke TV ($code), namun video belum dapat diputar. Silakan putar ulang lagu.')
                          : 'Terhubung dengan Kode TV ($code). Putar lagu untuk bernyanyi di TV.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: castOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted && !widget.castService.isTestMode) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gagal menghubungkan ke TV ($code). Pastikan koneksi internet aktif.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingWithCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevice = widget.castService.connectedDevice;

    return Material(
      color: const Color(0xFF0F172A),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 14,
        ),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar Minimalis (Judul + Tombol Tutup)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.cast_rounded,
                    color: AppColors.accentCyan,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cast ke TV',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          // Status Perangkat Aktif (Jika Terhubung)
          if (connectedDevice != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tv_rounded,
                    color: AppColors.accentLight,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      connectedDevice.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _disconnect,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Putus',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // SATU-SATUNYA Progress Indicator: Garis Linear di Bawah Header
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                child: LinearProgressIndicator(
                  value: widget.castService.isTestMode ? 0.5 : null,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                  minHeight: 2.5,
                ),
              ),
            ),

          // Daftar Perangkat TV atau Status Pencarian Terus Menerus
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: _devices.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tv_rounded,
                            color: AppColors.textMuted,
                            size: 28,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Mencari Smart TV di jaringan Wi-Fi...',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _devices.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: Colors.white10,
                    ),
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isCurrent = connectedDevice?.id == device.id;
                      final isConnectingThis = _connectingDeviceId == device.id;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: Icon(
                          device.type == CastDeviceType.chromecast
                              ? Icons.cast_rounded
                              : Icons.tv_rounded,
                          color: isCurrent ? AppColors.accentCyan : AppColors.accentSky,
                          size: 22,
                        ),
                        title: Text(
                          device.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        trailing: isConnectingThis
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                                ),
                              )
                            : isCurrent
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.accentCyan,
                                    size: 18,
                                  )
                                : const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textMuted,
                                    size: 18,
                                  ),
                        onTap: isConnectingThis ? null : () => _connect(device),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),

          // Input Kode TV (1 Baris Ringkas & Rapi)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _codeController,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Kode TV',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.dialpad_rounded, size: 16, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.accentCyan),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _isConnectingWithCode ? null : _connectWithCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryElectric,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isConnectingWithCode
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Hubungkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            'Jika muncul konfirmasi di layar TV, tekan Izinkan pada remote.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  }
}
