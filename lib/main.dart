import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'core/theme/app_colors.dart';
import 'screens/splash_screen.dart';
import 'services/ad_manager.dart';
import 'services/cast/smart_tv_cast_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aktifkan Android Photo Picker pada semua versi Android yang didukung.
  // Pemilih foto bawaan sistem ini tidak memerlukan izin penyimpanan
  // (READ_MEDIA_IMAGES/READ_MEDIA_VIDEO), sesuai kebijakan Google Play.
  final imagePickerPlatform = ImagePickerPlatform.instance;
  if (imagePickerPlatform is ImagePickerAndroid) {
    imagePickerPlatform.useAndroidPhotoPicker = true;
  }

  // Initialize Google Cast context
  await SmartTvCastService.initGoogleCastContext();

  // Set status bar and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // SDK AdMob (Android/iOS) menyentuh Google Play Services. Inisialisasi
  // ditunda sampai frame pertama tampil agar tidak menghambat start-up, dan
  // kegagalannya tidak pernah menggagalkan aplikasi (iklan hanya tak tampil).
  if (Platform.isAndroid || Platform.isIOS) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        MobileAds.instance
            .initialize()
            .then((status) => debugPrint('Inisialisasi AdMob selesai: ${status.adapterStatuses}'))
            .catchError((Object e, StackTrace s) {
          debugPrint('Inisialisasi AdMob gagal: $e\n$s');
        });
      } catch (e, s) {
        debugPrint('Inisialisasi AdMob gagal: $e\n$s');
      }
    });
  }

  runApp(const KaraokeApp());
}

class KaraokeApp extends StatefulWidget {
  const KaraokeApp({super.key});

  @override
  State<KaraokeApp> createState() => _KaraokeAppState();
}

class _KaraokeAppState extends State<KaraokeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Iklan app open ditampilkan saat aplikasi kembali aktif.
    if (state == AppLifecycleState.resumed) {
      AdManager.instance.maybeShowAppOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melindastore Youtube Stream Karaoke',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.primaryDark,
        primaryColor: AppColors.primaryBlue,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentCyan,
          secondary: AppColors.accentSky,
          surface: AppColors.surfaceDark,
          error: AppColors.error,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
