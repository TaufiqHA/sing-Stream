import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/youtube_helper.dart';

/// Widget untuk menampilkan cover thumbnail video YouTube dari URL lagu secara proporsional,
/// dengan dukungan rasio aspek (e.g. 16:9 full-width) atau ukuran tetap, serta
/// loading indicator dan fallback elegan jika URL tidak valid atau offline.
class SongCoverThumbnail extends StatelessWidget {
  final String? songUrl;
  final double? width;
  final double? height;
  final double? aspectRatio;
  final double borderRadius;
  final Widget? fallback;

  const SongCoverThumbnail({
    super.key,
    required this.songUrl,
    this.width,
    this.height,
    this.aspectRatio,
    this.borderRadius = 6,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final videoId = YoutubeHelper.extractVideoId(songUrl);

    if (videoId == null || videoId.isEmpty) {
      return _wrapContainer(context, _buildFallback(context));
    }

    final thumbnailUrl = YoutubeHelper.getMediumThumbnailUrl(videoId);

    final imageWidget = Image.network(
      thumbnailUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildLoadingPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildFallback(context);
      },
    );

    return _wrapContainer(context, imageWidget);
  }

  Widget _wrapContainer(BuildContext context, Widget child) {
    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );

    if (aspectRatio != null) {
      return AspectRatio(
        aspectRatio: aspectRatio!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E293B),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.accentCyan.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    if (fallback != null) {
      return fallback!;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF162235),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: AppColors.accentSky.withValues(alpha: 0.4),
          size: (height != null) ? height! * 0.45 : 24,
        ),
      ),
    );
  }
}
