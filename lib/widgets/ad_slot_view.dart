import 'package:flutter/material.dart';

import '../core/config/api_config.dart';
import '../core/theme/app_colors.dart';
import '../models/application_model.dart';
import 'admob_view.dart';

/// Membangun URL gambar iklan dari nilai backend.
///
/// Nilai bisa berupa URL penuh (mis. `https://...`) atau path relatif di
/// storage publik (mis. `banners/promo.jpg`). Untuk path relatif, digabung
/// dengan origin API (dengan `/api` dilepas) + `/storage/`.
String resolveAdImageUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  var base = ApiConfig.baseUrl;
  final apiIndex = base.indexOf('/api');
  if (apiIndex >= 0) base = base.substring(0, apiIndex);
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  return '$base/storage/$value';
}

/// Menampilkan satu slot iklan sesuai konfigurasi dari panel admin website.
///
/// - Jenis `image`    → banner gambar (di-load dari URL storage).
/// - Jenis `admob_native` / `admob_banner` → iklan AdMob in-feed.
/// - Jenis full-screen (interstitial/app open/reward) → tidak dirender di slot
///   (ditangani [AdManager]).
class AdSlotView extends StatelessWidget {
  final AdSlotConfig ad;

  /// Status aktif slot (dari `applicationadsactive`/`applicationadsbottomactive`).
  final bool active;

  final EdgeInsets padding;

  /// Batas tinggi opsional agar slot tidak memicu overflow pada layout tetap
  /// (mis. layout karaoke). Bila `null`, tinggi mengikuti isi iklan.
  final double? maxHeight;

  const AdSlotView({
    super.key,
    required this.ad,
    this.active = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.maxHeight,
  });

  bool get _hasRenderable =>
      (ad.isImage && (ad.image ?? '').trim().isNotEmpty) ||
      ((ad.isNative || ad.isBanner) && ad.hasUnit);

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();

    // Iklan layar penuh tidak dirender di slot.
    if (ad.isFullScreen) return const SizedBox.shrink();
    if (!_hasRenderable) return const SizedBox.shrink();

    final Widget content;
    if (ad.isNative) {
      content = AdMobNativeView(adUnitId: ad.unit!, padding: padding);
    } else if (ad.isBanner) {
      content = AdMobBannerView(adUnitId: ad.unit!, padding: padding);
    } else {
      final url = resolveAdImageUrl(ad.image ?? '');
      content = Padding(
        padding: padding,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            width: double.infinity,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
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
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
    }

    final height = maxHeight;
    if (height == null) return content;

    // Batasi tinggi agar tidak overflow pada Column dengan tinggi tetap.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: ClipRect(child: content),
    );
  }
}
