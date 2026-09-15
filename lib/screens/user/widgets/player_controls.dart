import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/song_model.dart';

/// Bar kontrol pemutaran studio karaoke (3 Kolom Simetris & Rapi).
/// Kolom Kiri: Info lagu aktif & ikon musik
/// Kolom Tengah: Tombol navigasi playback simetris & seekbar waktu presisi
/// Kolom Kanan: Pengatur volume horizontal & toggle fullscreen
class PlayerControls extends StatefulWidget {
  final SongModel? song;
  final bool isPlaying;
  final bool hasSong;
  final Duration currentPosition;
  final ValueListenable<Duration>? currentPositionListenable;
  final Duration totalDuration;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onTogglePlayPause;
  final VoidCallback? onStop;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final double volume; // 0.0 - 1.0
  final bool isMuted;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final VoidCallback? onCastTapped;
  final bool isCasting;

  const PlayerControls({
    super.key,
    this.song,
    required this.isPlaying,
    required this.hasSong,
    this.currentPosition = Duration.zero,
    this.currentPositionListenable,
    required this.totalDuration,
    this.onSeek,
    this.onTogglePlayPause,
    this.onStop,
    this.onNext,
    this.onPrevious,
    this.volume = 0.8,
    this.isMuted = false,
    this.onVolumeChanged,
    this.onToggleMute,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.onCastTapped,
    this.isCasting = false,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _isDragging = false;
  double _dragPosition = 0.0;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final double maxSeconds = widget.totalDuration.inSeconds > 0
        ? widget.totalDuration.inSeconds.toDouble()
        : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 480;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12 : 14,
            vertical: isNarrow ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: isNarrow
              ? _buildMobileLayout(context, maxSeconds)
              : _buildDesktopLayout(context, maxSeconds),
        );
      },
    );
  }

  /// Layout Desktop: 3 Kolom Seimbang (Kiri: Info Lagu, Tengah: Playback + Seekbar, Kanan: Volume + Fullscreen)
  Widget _buildDesktopLayout(
    BuildContext context,
    double maxSeconds,
  ) {
    final song = widget.song;
    final hasSong = widget.hasSong;
    final isPlaying = widget.isPlaying;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Kolom Kiri (flex 3): Info Lagu Aktif
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.primaryElectric.withValues(alpha: 0.2),
                  border: Border.all(
                    color: isPlaying
                        ? AppColors.accentCyan.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Icon(
                    isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                    color: isPlaying ? AppColors.accentCyan : AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song?.songtitle ?? 'Player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (song != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        song.songsinger,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentSky,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // 2. Kolom Tengah (flex 4): Playback Buttons & Seekbar
        Expanded(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Playback Navigation Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: hasSong ? widget.onStop : null,
                    tooltip: 'Berhenti',
                    icon: const Icon(Icons.stop_rounded),
                    color: hasSong && isPlaying ? AppColors.error : AppColors.textMuted,
                    iconSize: 24,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 10),

                  // Main Play / Pause Button
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: hasSong ? widget.onTogglePlayPause : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasSong ? AppColors.buttonGradient : null,
                        color: hasSong ? null : Colors.white.withValues(alpha: 0.08),
                        boxShadow: hasSong && isPlaying
                            ? [
                                BoxShadow(
                                  color: AppColors.accentCyan.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: hasSong ? Colors.white : AppColors.textMuted,
                          size: 26,
                        ),
                      ),
                    ),
                  ),

                  if (widget.onNext != null) ...[
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: hasSong ? widget.onNext : null,
                      tooltip: 'Lagu Berikutnya',
                      icon: const Icon(Icons.skip_next_rounded),
                      color: hasSong ? Colors.white : AppColors.textMuted,
                      iconSize: 24,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),

              // Seekbar Row with Timers
              _buildDesktopSeekbar(context, maxSeconds, hasSong),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // 3. Kolom Kanan (flex 3): Volume & Fullscreen Button (Adaptif & Bebas Overflow)
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: widget.onToggleMute,
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    visualDensity: VisualDensity.compact,
                    tooltip: widget.isMuted ? 'Batal Bisukan' : 'Bisukan',
                    icon: Icon(
                      widget.isMuted || widget.volume == 0.0
                          ? Icons.volume_off_rounded
                          : (widget.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                      color: widget.isMuted ? AppColors.error : AppColors.accentSky,
                    ),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 55,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 7),
                        activeTrackColor: widget.isMuted ? AppColors.textMuted : AppColors.accentCyan,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: widget.isMuted ? 0.0 : widget.volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          widget.onVolumeChanged?.call(val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${(widget.isMuted ? 0 : (widget.volume * 100).toInt())}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),

                  if (widget.onCastTapped != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      onPressed: widget.onCastTapped,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      visualDensity: VisualDensity.compact,
                      tooltip: widget.isCasting ? 'Putus Cast' : 'Cast ke TV',
                      icon: Icon(
                        widget.isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
                        color: widget.isCasting ? AppColors.accentCyan : AppColors.accentSky,
                        size: 18,
                      ),
                    ),
                  ],
                  if (widget.onToggleFullscreen != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      onPressed: widget.onToggleFullscreen,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      visualDensity: VisualDensity.compact,
                      tooltip: widget.isFullscreen ? 'Perkecil Layar' : 'Layar Penuh',
                      icon: Icon(
                        widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                        color: AppColors.accentSky,
                        size: 18,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Layout Mobile: Vertikal Teratur & Sangat Kompak
  Widget _buildMobileLayout(
    BuildContext context,
    double maxSeconds,
  ) {
    final song = widget.song;
    final hasSong = widget.hasSong;
    final isPlaying = widget.isPlaying;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Info Lagu & Volume Row (1 Baris Ringkas)
        Row(
          children: [
            Expanded(
              child: Text(
                song != null
                    ? '${song.songtitle} • ${song.songsinger}'
                    : 'Player',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              onPressed: widget.onToggleMute,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: Icon(
                widget.isMuted || widget.volume == 0.0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: widget.isMuted ? AppColors.error : AppColors.accentSky,
              ),
            ),
            SizedBox(
              width: 55,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
                  activeTrackColor: AppColors.accentCyan,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: widget.isMuted ? 0.0 : widget.volume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => widget.onVolumeChanged?.call(val),
                ),
              ),
            ),
          ],
        ),

        // 2. Seekbar
        _buildMobileSeekbar(context, maxSeconds, hasSong),

        // 3. Playback Navigation Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: hasSong ? widget.onStop : null,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.stop_rounded),
              color: hasSong && isPlaying ? AppColors.error : AppColors.textMuted,
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: hasSong ? widget.onTogglePlayPause : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasSong ? AppColors.buttonGradient : null,
                  color: hasSong ? null : Colors.white.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            if (widget.onNext != null)
              IconButton(
                onPressed: hasSong ? widget.onNext : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Lagu Berikutnya',
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: hasSong ? Colors.white : AppColors.textMuted,
                  size: 22,
                ),
              ),
            if (widget.onCastTapped != null)
              IconButton(
                onPressed: widget.onCastTapped,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  widget.isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
                  color: widget.isCasting ? AppColors.accentCyan : AppColors.accentSky,
                  size: 20,
                ),
              ),
            if (widget.onToggleFullscreen != null)
              IconButton(
                onPressed: widget.onToggleFullscreen,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: AppColors.accentSky,
                  size: 20,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopSeekbar(BuildContext context, double maxSeconds, bool hasSong) {
    Widget buildRow(Duration currentPos) {
      final double currentSeconds = currentPos.inSeconds.clamp(0, maxSeconds.toInt()).toDouble();
      final double sliderValue = _isDragging
          ? _dragPosition.clamp(0.0, maxSeconds)
          : (hasSong ? currentSeconds : 0.0).clamp(0.0, maxSeconds);

      return Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _formatDuration(
                _isDragging
                    ? Duration(seconds: _dragPosition.toInt())
                    : currentPos,
              ),
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.accentLight,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: hasSong ? AppColors.accentCyan : AppColors.textMuted,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: hasSong ? Colors.white : AppColors.textMuted,
                overlayColor: AppColors.accentCyan.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: sliderValue,
                min: 0.0,
                max: hasSong ? maxSeconds : 1.0,
                onChangeStart: hasSong
                    ? (val) {
                        setState(() {
                          _isDragging = true;
                          _dragPosition = val;
                        });
                      }
                    : null,
                onChanged: hasSong
                    ? (val) {
                        setState(() {
                          _dragPosition = val;
                        });
                      }
                    : null,
                onChangeEnd: hasSong
                    ? (val) {
                        setState(() {
                          _isDragging = false;
                        });
                        widget.onSeek?.call(Duration(seconds: val.toInt()));
                      }
                    : null,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              _formatDuration(widget.totalDuration),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    if (widget.currentPositionListenable != null) {
      return ValueListenableBuilder<Duration>(
        valueListenable: widget.currentPositionListenable!,
        builder: (context, currentPos, _) => buildRow(currentPos),
      );
    }
    return buildRow(widget.currentPosition);
  }

  Widget _buildMobileSeekbar(BuildContext context, double maxSeconds, bool hasSong) {
    Widget buildRow(Duration currentPos) {
      final double currentSeconds = currentPos.inSeconds.clamp(0, maxSeconds.toInt()).toDouble();
      final double sliderValue = _isDragging
          ? _dragPosition.clamp(0.0, maxSeconds)
          : (hasSong ? currentSeconds : 0.0).clamp(0.0, maxSeconds);

      return Row(
        children: [
          Text(
            _formatDuration(
              _isDragging
                  ? Duration(seconds: _dragPosition.toInt())
                  : currentPos,
            ),
            style: const TextStyle(fontSize: 10, color: AppColors.accentLight),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
                activeTrackColor: AppColors.accentCyan,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: sliderValue,
                min: 0.0,
                max: hasSong ? maxSeconds : 1.0,
                onChangeStart: hasSong
                    ? (val) {
                        setState(() {
                          _isDragging = true;
                          _dragPosition = val;
                        });
                      }
                    : null,
                onChanged: hasSong
                    ? (val) {
                        setState(() {
                          _dragPosition = val;
                        });
                      }
                    : null,
                onChangeEnd: hasSong
                    ? (val) {
                        setState(() {
                          _isDragging = false;
                        });
                        widget.onSeek?.call(Duration(seconds: val.toInt()));
                      }
                    : null,
              ),
            ),
          ),
          Text(
            _formatDuration(widget.totalDuration),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      );
    }

    if (widget.currentPositionListenable != null) {
      return ValueListenableBuilder<Duration>(
        valueListenable: widget.currentPositionListenable!,
        builder: (context, currentPos, _) => buildRow(currentPos),
      );
    }
    return buildRow(widget.currentPosition);
  }
}
