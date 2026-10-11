import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/theme/app_colors.dart';

/// ID factory native yang didaftarkan pada platform (lihat `MainActivity.kt`
/// dan `FeedAdFactory.kt` di Android).
const String kAdMobNativeFactoryId = 'feedAdFactory';

/// Tampilkan kotak pesan error iklan di layar (untuk diagnosis).
///
/// - `true`  → kotak error tampil di **semua** mode (termasuk release).
/// - `false` → kotak error hanya tampil di mode debug (perilaku produksi).
///
/// Catatan: kotak ini hanya muncul saat iklan GAGAL; tidak memengaruhi
/// keberhasilan pemuatan iklan. Set `false` sebelum rilis produksi.
const bool kShowAdErrors = false;

/// Pembatas permintaan iklan agar app tidak menembak Ad Unit yang sama secara
/// beruntun (penyebab error SDK `code=1` "Too many recently failed requests").
///
/// Satu Ad Unit hanya boleh diminta **sekali per [cooldown]**. Setelah jeda itu,
/// unit boleh diminta lagi.
class AdMobRequestThrottle {
  AdMobRequestThrottle._();

  /// Jeda minimum antar permintaan untuk unit yang sama.
  static const Duration cooldown = Duration(seconds: 60);

  static final Map<String, DateTime> _lastRequest = <String, DateTime>{};

  /// Kembalikan `true` bila [adUnitId] boleh diminta sekarang, lalu catat
  /// waktunya. Kembalikan `false` bila masih dalam masa cooldown.
  static bool allow(String adUnitId) {
    if (adUnitId.isEmpty) return true;
    if (cooldown == Duration.zero) return true;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastRequest[adUnitId];
    if (last != null && now.difference(last) < cooldown) return false;
    _lastRequest[adUnitId] = now;
    return true;
  }
}

/// Cache iklan yang **sudah dimuat**, per Ad Unit ID.
class AdMobAdCache {
  AdMobAdCache._();

  static final Map<String, Ad> _cache = <String, Ad>{};

  static Ad? take(String adUnitId) => _cache.remove(adUnitId);

  static void store(String adUnitId, Ad ad) => _cache[adUnitId] = ad;

  static void drop(String adUnitId) => _cache.remove(adUnitId)?.dispose();
}

/// Iklan AdMob format native (in-feed). Hanya aktif di Android/iOS.
class AdMobNativeView extends StatefulWidget {
  final String adUnitId;
  final EdgeInsets padding;

  const AdMobNativeView({
    super.key,
    required this.adUnitId,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  State<AdMobNativeView> createState() => _AdMobNativeViewState();
}

class _AdMobNativeViewState extends State<AdMobNativeView>
    with AutomaticKeepAliveClientMixin {
  NativeAd? _ad;
  bool _loaded = false;
  bool _skipped = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Ad? cached = AdMobAdCache.take(widget.adUnitId);
    if (cached is NativeAd) {
      _ad = cached;
      _loaded = true;
      return;
    }
    if (cached != null) cached.dispose();

    if (!AdMobRequestThrottle.allow(widget.adUnitId)) {
      _skipped = true;
      debugPrint('AdMob: native unit ${widget.adUnitId} DILEWATI (cooldown).');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _load() {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    if (widget.adUnitId.isEmpty) return;

    try {
      final ad = NativeAd(
        adUnitId: widget.adUnitId,
        factoryId: kAdMobNativeFactoryId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _ad = ad as NativeAd;
              _loaded = true;
              _error = null;
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('AdMob: gagal memuat native ad. code=${error.code} message=${error.message}');
            ad.dispose();
            if (mounted) {
              setState(() {
                _ad = null;
                _loaded = false;
                _error = '${error.code}: ${error.message}';
              });
            }
          },
        ),
      );
      _ad = ad;
      ad.load();
    } catch (e, s) {
      debugPrint('AdMob: gagal memuat iklan native: $e\n$s');
    }
  }

  @override
  void dispose() {
    if (_loaded && _ad != null) {
      AdMobAdCache.store(widget.adUnitId, _ad!);
    } else {
      _ad?.dispose();
    }
    super.dispose();
  }

  /// Tinggi tetap slot iklan native (logical px) agar geometri tidak berubah
  /// saat platform view AdWidget dipasang.
  static const double _nativeAdHeight = 380;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const SizedBox.shrink();
    }
    if (_skipped) return const SizedBox.shrink();

    final bool ready = _loaded && _ad != null;

    if (!ready && _error != null) {
      if (!kShowAdErrors && !kDebugMode) return const SizedBox.shrink();
      return Padding(
        padding: widget.padding,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'AdMob gagal memuat: $_error',
            style: const TextStyle(color: AppColors.error, fontSize: 11),
          ),
        ),
      );
    }

    return Padding(
      padding: widget.padding,
      child: SizedBox(
        height: _nativeAdHeight,
        child: ready
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AdWidget(ad: _ad!),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Iklan AdMob format banner (in-feed). Hanya aktif di Android/iOS.
class AdMobBannerView extends StatefulWidget {
  final String adUnitId;
  final EdgeInsets padding;

  const AdMobBannerView({
    super.key,
    required this.adUnitId,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  State<AdMobBannerView> createState() => _AdMobBannerViewState();
}

class _AdMobBannerViewState extends State<AdMobBannerView>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _ad;
  bool _loaded = false;
  bool _started = false;
  bool _skipped = false;
  String? _error;
  AdSize? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final Ad? cached = AdMobAdCache.take(widget.adUnitId);
    if (cached is BannerAd) {
      _ad = cached;
      _size = cached.size;
      _loaded = true;
      return;
    }
    if (cached != null) cached.dispose();

    if (!AdMobRequestThrottle.allow(widget.adUnitId)) {
      _skipped = true;
      debugPrint('AdMob: banner unit ${widget.adUnitId} DILEWATI (cooldown).');
      return;
    }
    final double width =
        MediaQuery.sizeOf(context).width - widget.padding.horizontal;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(width.truncate());
    });
  }

  Future<void> _load(int width) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    if (widget.adUnitId.isEmpty) return;

    AdSize size = AdSize.banner;
    try {
      size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width) ?? AdSize.banner;
    } catch (_) {
      size = AdSize.banner;
    }
    if (!mounted) return;
    setState(() => _size = size);

    try {
      final ad = BannerAd(
        adUnitId: widget.adUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _ad = ad as BannerAd;
              _loaded = true;
              _error = null;
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('AdMob: gagal memuat banner. code=${error.code} message=${error.message}');
            ad.dispose();
            if (mounted) {
              setState(() {
                _ad = null;
                _loaded = false;
                _error = '${error.code}: ${error.message}';
              });
            }
          },
        ),
      );
      _ad = ad;
      ad.load();
    } catch (e, s) {
      debugPrint('AdMob: gagal memuat banner: $e\n$s');
    }
  }

  @override
  void dispose() {
    if (_loaded && _ad != null) {
      AdMobAdCache.store(widget.adUnitId, _ad!);
    } else {
      _ad?.dispose();
    }
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const SizedBox.shrink();
    }
    if (_skipped) return const SizedBox.shrink();

    final int? knownHeight = _size?.height ?? _ad?.size.height;
    final int? knownWidth = _size?.width ?? _ad?.size.width;
    final double reservedHeight =
        (knownHeight != null && knownHeight > 0) ? knownHeight.toDouble() : 100.0;
    final double adWidth = (knownWidth != null && knownWidth > 0)
        ? knownWidth.toDouble()
        : double.infinity;

    if (!_loaded || _ad == null) {
      if (_error != null) {
        if (!kShowAdErrors && !kDebugMode) return const SizedBox.shrink();
        return Padding(
          padding: widget.padding,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'AdMob banner gagal memuat: $_error',
              style: const TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ),
        );
      }
      return Padding(
        padding: widget.padding,
        child: SizedBox(height: reservedHeight, width: double.infinity),
      );
    }
    return Padding(
      padding: widget.padding,
      child: Center(
        child: SizedBox(
          width: adWidth,
          height: reservedHeight,
          child: AdWidget(ad: _ad!),
        ),
      ),
    );
  }
}
