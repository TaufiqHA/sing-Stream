import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/youtube_helper.dart';

/// Widget pemutar video YouTube berkonsep layar bioskop / cinema (tanpa kartu sempit).
class YoutubeVideoPlayerWidget extends StatelessWidget {
  final YoutubePlayerController? controller;
  final String? videoId;
  final String songTitle;
  final String songSinger;
  final bool isPlaying;
  final VoidCallback? onPlayTapped;
  final bool isTestMode;

  const YoutubeVideoPlayerWidget({
    super.key,
    required this.controller,
    required this.videoId,
    required this.songTitle,
    required this.songSinger,
    this.isPlaying = false,
    this.onPlayTapped,
    this.isTestMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (videoId == null || videoId!.isEmpty) {
      return _buildNoVideoPlaceholder();
    }

    if (isTestMode || controller == null) {
      return _buildThumbnailPlaceholder(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(
            key: controller != null ? ObjectKey(controller) : null,
            controller: controller!,
            aspectRatio: 16 / 9,
            autoFullScreen: false,
            enableFullScreenOnVerticalDrag: false,
            keepAlive: true,
            controlsBuilder: (context, isFullscreen) {
              if (!isFullscreen) return const SizedBox.shrink();
              return buildFullscreenOverlay(
                context: context,
                songTitle: songTitle,
                songSinger: songSinger,
                onExitFullScreen: () => controller?.exitFullScreen(),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Overlay kontrol di layar penuh (info judul lagu & tombol tutup fullscreen)
  static Widget buildFullscreenOverlay({
    required BuildContext context,
    required String songTitle,
    required String songSinger,
    VoidCallback? onExitFullScreen,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge Info Lagu
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Text(
                  '$songTitle - $songSinger',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Tombol Exit / Close Fullscreen
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onExitFullScreen,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: const Icon(
                    Icons.fullscreen_exit_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Placeholder thumbnail saat test mode atau controller sedang bersiap
  Widget _buildThumbnailPlaceholder(BuildContext context) {
    final thumbnailUrl = YoutubeHelper.getThumbnailUrl(videoId!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl.isNotEmpty)
                Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildFallbackBackground(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildFallbackBackground();
                  },
                )
              else
                _buildFallbackBackground(),

              // Gradient Cinematic Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),

              // Play overlay button
              Center(
                child: InkWell(
                  onTap: onPlayTapped,
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF0000).withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom song info
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    const Icon(
                      Icons.smart_display_rounded,
                      color: Color(0xFFFF5252),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$songTitle - $songSinger',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Icon(
          Icons.music_video_rounded,
          size: 60,
          color: AppColors.accentCyan.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildNoVideoPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: const Color(0xFF0F172A),
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Text(
              'Link video YouTube tidak valid',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
