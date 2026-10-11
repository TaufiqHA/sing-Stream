import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/application_model.dart';

/// Mengelola iklan AdMob full-screen: interstitial, app open, dan reward.
///
/// Iklan inline (native/banner/gambar) dirender langsung oleh widget di
/// `../widgets/ad_slot_view.dart`/`../widgets/admob_view.dart`. Service ini
/// hanya menangani format yang memenuhi layar dan dipicu oleh navigasi/aksi
/// pengguna.
///
/// Ad Unit full-screen diambil dari salah satu slot iklan (slot 1, slot 2, atau
/// banner bawah) yang pada panel admin website disetel ke jenis interstitial,
/// app open, atau reward.
class AdManager {
  AdManager._();

  static final AdManager instance = AdManager._();

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // ---- Konfigurasi Ad Unit (berasal dari konfigurasi aplikasi) ----
  String? _interstitialUnit;
  String? _appOpenUnit;
  String? _rewardUnit;

  // ---- Iklan yang sudah dimuat ----
  InterstitialAd? _interstitial;
  AppOpenAd? _appOpen;
  RewardedAd? _reward;

  bool _loadingInterstitial = false;
  bool _loadingAppOpen = false;
  bool _loadingReward = false;

  bool _configuredOnce = false;
  bool _showAppOpenWhenReady = false;

  // ---- Pengaturan frekuensi ----
  int _songOpens = 0;
  DateTime? _lastInterstitial;
  DateTime? _lastAppOpen;

  /// Interstitial ditampilkan tiap sekian pemutaran lagu.
  static const int _interstitialEvery = 3;

  /// Jeda minimum antar interstitial.
  static const Duration _interstitialCooldown = Duration(minutes: 2);

  /// Jeda minimum antar app open.
  static const Duration _appOpenCooldown = Duration(minutes: 4);

  static const String _prefLastAppOpen = 'admob_last_app_open_ms';

  /// Terapkan konfigurasi dari data aplikasi. Aman dipanggil berulang.
  void configure(ApplicationModel config) {
    if (!_supported) return;

    _interstitialUnit = null;
    _appOpenUnit = null;
    _rewardUnit = null;

    for (final slot in [config.ads1Config, config.ads2Config, config.adsBottomConfig]) {
      if (!slot.isAdMob) continue;
      final unit = slot.unit;
      if (slot.isInterstitial && _interstitialUnit == null) _interstitialUnit = unit;
      if (slot.isAppOpen && _appOpenUnit == null) _appOpenUnit = unit;
      if (slot.isReward && _rewardUnit == null) _rewardUnit = unit;
    }

    if (!_configuredOnce) {
      _configuredOnce = true;
      _showAppOpenWhenReady = true;
    }

    _loadInterstitial();
    _loadAppOpen();
  }

  // ---------------------------------------------------------------------------
  // Interstitial — tampil saat pengguna mengganti/memutar lagu.
  // ---------------------------------------------------------------------------

  void _loadInterstitial() {
    final unit = _interstitialUnit;
    if (unit == null || unit.isEmpty || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('AdMob: gagal memuat interstitial. ${error.code}: ${error.message}');
        },
      ),
    );
  }

  /// Panggil saat pengguna memutar lagu. Menampilkan interstitial secara
  /// berkala (tiap [_interstitialEvery] pemutaran, dengan jeda
  /// [_interstitialCooldown]).
  void maybeShowInterstitial() {
    if (!_supported) return;
    _songOpens++;

    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    if (_songOpens < _interstitialEvery) return;
    if (_lastInterstitial != null &&
        DateTime.now().difference(_lastInterstitial!) < _interstitialCooldown) {
      return;
    }

    _songOpens = 0;
    _lastInterstitial = DateTime.now();
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: gagal menampilkan interstitial. ${error.code}: ${error.message}');
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  // ---------------------------------------------------------------------------
  // App open — tampil saat aplikasi dibuka/dikembalikan dari background.
  // ---------------------------------------------------------------------------

  void _loadAppOpen() {
    final unit = _appOpenUnit;
    if (unit == null || unit.isEmpty || _appOpen != null || _loadingAppOpen) return;
    _loadingAppOpen = true;
    AppOpenAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingAppOpen = false;
          _appOpen = ad;
          if (_showAppOpenWhenReady) {
            _showAppOpenWhenReady = false;
            maybeShowAppOpen();
          }
        },
        onAdFailedToLoad: (error) {
          _loadingAppOpen = false;
          debugPrint('AdMob: gagal memuat app open. ${error.code}: ${error.message}');
        },
      ),
    );
  }

  /// Tampilkan app open bila tersedia dan jeda sudah lewat.
  Future<void> maybeShowAppOpen() async {
    if (!_supported) return;
    final ad = _appOpen;
    if (ad == null) {
      _loadAppOpen();
      return;
    }

    final last = _lastAppOpen ?? await _readLastAppOpen();
    if (last != null && DateTime.now().difference(last) < _appOpenCooldown) {
      return;
    }

    _lastAppOpen = DateTime.now();
    _appOpen = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: gagal menampilkan app open. ${error.code}: ${error.message}');
        ad.dispose();
        _loadAppOpen();
      },
    );
    ad.show();
    _persistLastAppOpen(_lastAppOpen!);
  }

  Future<DateTime?> _readLastAppOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_prefLastAppOpen);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  void _persistLastAppOpen(DateTime t) {
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_prefLastAppOpen, t.millisecondsSinceEpoch))
        .catchError((Object _) => false);
  }

  // ---------------------------------------------------------------------------
  // Reward — ditampilkan atas aksi pengguna.
  // ---------------------------------------------------------------------------

  /// True bila ada Ad Unit reward yang dikonfigurasi.
  bool get hasReward => _rewardUnit != null && _rewardUnit!.isNotEmpty;

  /// Muat (bila perlu) lalu tampilkan iklan reward. [onReward] dipanggil bila
  /// pengguna menonton sampai selesai.
  Future<void> showReward({VoidCallback? onReward}) async {
    if (!_supported) return;
    final unit = _rewardUnit;
    if (unit == null || unit.isEmpty) return;

    final loaded = _reward;
    if (loaded != null) {
      _presentReward(loaded, onReward);
      return;
    }
    if (_loadingReward) return;

    _loadingReward = true;
    RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingReward = false;
          _presentReward(ad, onReward);
        },
        onAdFailedToLoad: (error) {
          _loadingReward = false;
          debugPrint('AdMob: gagal memuat reward. ${error.code}: ${error.message}');
        },
      ),
    );
  }

  void _presentReward(RewardedAd ad, VoidCallback? onReward) {
    _reward = null;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (earned) onReward?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: gagal menampilkan reward. ${error.code}: ${error.message}');
        ad.dispose();
      },
    );
    ad.show(onUserEarnedReward: (ad, reward) {
      earned = true;
    });
  }
}
