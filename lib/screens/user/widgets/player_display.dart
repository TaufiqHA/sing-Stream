import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/youtube_helper.dart';
import '../../../models/song_model.dart';
import 'youtube_video_player.dart';

/// Panggung Karaoke Cinema Terbuka (Tanpa Card Box Sempit & Tanpa Visualizer).
class PlayerDisplay extends StatelessWidget {
  final SongModel? song;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final int queueCount;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final YoutubePlayerController? youtubeController;
  final bool isTestMode;
  final VoidCallback? onPlayPauseTapped;
  final VoidCallback? onOpenSearchModal;

  const PlayerDisplay({
    super.key,
    required this.song,
    required this.isPlaying,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.queueCount = 0,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.youtubeController,
    this.isTestMode = false,
    this.onPlayPauseTapped,
    this.onOpenSearchModal,
  });

  @override
  Widget build(BuildContext context) {
    final videoId = YoutubeHelper.extractVideoId(song?.songurl);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 450 || constraints.maxHeight < 250;

        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              // 1. Main Stage Area (YouTube Video or Clean Standby Stage)
              if (song != null)
                Positioned.fill(
                  child: YoutubeVideoPlayerWidget(
                    controller: youtubeController,
                    videoId: videoId,
                    songTitle: song!.songtitle,
                    songSinger: song!.songsinger,
                    isPlaying: isPlaying,
                    onPlayTapped: onPlayPauseTapped,
                    isTestMode: isTestMode,
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: isCompact ? 40 : 54,
                            height: isCompact ? 40 : 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryElectric.withValues(alpha: 0.2),
                              border: Border.all(
                                color: AppColors.accentCyan.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.music_note_rounded,
                              size: isCompact ? 20 : 28,
                              color: AppColors.accentLight,
                            ),
                          ),
                          SizedBox(height: isCompact ? 6 : 10),
                          Text(
                            'Player',
                            style: TextStyle(
                              fontSize: isCompact ? 14 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. Queue Floating Badge (Pill di pojok kiri atas)
              if (queueCount > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.queue_music_rounded,
                          size: 13,
                          color: AppColors.accentSky,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$queueCount antrean',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentSky,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
