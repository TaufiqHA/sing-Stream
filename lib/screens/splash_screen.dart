import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/api_auth_service.dart';
import '../core/services/storage_service.dart';
import '../core/theme/app_colors.dart';
import '../models/user_model.dart';
import 'admin/admin_main_layout.dart';
import 'login_screen.dart';
import 'user/user_main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    _startTimer();
  }

  void _startTimer() {
    _navTimer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;

      Widget destination = const LoginScreen();

      try {
        final storage = await StorageService.getInstance();
        final loggedIn = await storage.isLoggedIn();
        UserModel? user = await storage.getUser();

        if (loggedIn) {
          try {
            final authService = ApiAuthService(storageService: storage);
            final updatedUser = await authService
                .getProfile()
                .timeout(const Duration(milliseconds: 2000));
            if (updatedUser != null) {
              user = updatedUser;
            }
          } catch (_) {
            // Jika koneksi timeout atau offline, cek apakah sesi lokal masih valid
            final stillValid = await storage.isLoggedIn();
            if (!stillValid) {
              user = null;
            }
          }
        }

        final isUserLoggedIn = await storage.isLoggedIn();
        if (isUserLoggedIn && user != null) {
          destination = user.isAdmin
              ? const AdminMainLayout()
              : const UserMainLayout();
        }
      } catch (_) {
        destination = const LoginScreen();
      } finally {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  destination,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Animated Logo Section
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.iconGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentCyan.withValues(alpha: 0.45),
                                blurRadius: 35,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: AppColors.primaryRoyal.withValues(alpha: 0.6),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'asset/image/logo.png',
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // App Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Colors.white,
                          AppColors.accentLight,
                          AppColors.accentCyan,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'Tomsi Karaoke',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tagline
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'Sing Your Heart Out',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentSky,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Bottom Loading Indicator & Version
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accentCyan.withValues(alpha: 0.85),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Versi 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
