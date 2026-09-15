import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AdminPlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const AdminPlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Panel Admin / $title',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.accentSky,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.cardGlass,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.cardGlassBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryElectric.withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            icon,
                            size: 48,
                            color: AppColors.accentCyan,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
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
      ),
    );
  }
}
