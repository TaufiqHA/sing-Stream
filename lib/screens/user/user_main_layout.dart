import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/services/api_auth_service.dart';
import '../../core/services/api_category_service.dart';
import '../../core/services/api_song_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/song_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/youtube_helper.dart';
import '../../models/category_model.dart';
import '../../models/song_model.dart';
import '../../models/user_model.dart';
import '../login_screen.dart';
import '../../services/cast/smart_tv_cast_service.dart';
import 'widgets/cast_device_modal.dart';
import 'widgets/player_controls.dart';
import 'widgets/player_display.dart';
import 'widgets/song_catalog_playlist_section.dart';
import 'widgets/song_search_panel.dart';

class UserMainLayout extends StatefulWidget {
  final SongService? songService;
  final CategoryService? categoryService;
  final SmartTvCastService? castService;
  final bool isTestMode;

  const UserMainLayout({
    super.key,
    this.songService,
    this.categoryService,
    this.castService,
    this.isTestMode = false,
  });

  @override
  State<UserMainLayout> createState() => _UserMainLayoutState();
}

class _UserMainLayoutState extends State<UserMainLayout> {
  late final SongService _songService;
  late final CategoryService _categoryService;
  late final SmartTvCastService _castService;
  StreamSubscription? _castSubscription;

  UserModel? _currentUser;
  List<SongModel> _allSongs = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  // Playback state
  SongModel? _currentSong;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  final ValueNotifier<Duration> _currentPositionNotifier = ValueNotifier<Duration>(Duration.zero);
  Duration _totalDuration = const Duration(minutes: 3, seconds: 30);
  Timer? _playbackTimer;

  void _updateCurrentPosition(Duration position) {
    _currentPosition = position;
    _currentPositionNotifier.value = position;
  }

  // Audio & Display Settings
  double _volume = 0.8;
  bool _isMuted = false;
  bool _isFullscreen = false;
  DateTime? _lastManualActionTime;
  final List<SongModel> _queue = [];

  // YouTube Player Controller
  final GlobalKey _playerDisplayKey = GlobalKey();
  YoutubePlayerController? _youtubeController;
  StreamSubscription? _youtubePlayerSubscription;
  StreamSubscription<YoutubeVideoState>? _videoStateSubscription;

  @override
  void initState() {
    super.initState();
    _songService = widget.songService ?? ApiSongService();
    _categoryService = widget.categoryService ?? ApiCategoryService();
    _castService = widget.castService ?? SmartTvCastService(isTestMode: widget.isTestMode);
    _castSubscription = _castService.connectedDeviceStream.listen((_) {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  void _createYoutubeController(String videoId) {
    if (widget.isTestMode) return;
    try {
      _youtubePlayerSubscription?.cancel();
      _videoStateSubscription?.cancel();
      if (_youtubeController != null) {
        try {
          _youtubeController?.stopVideo();
        } catch (_) {}
        _youtubeController?.close();
      }

      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          showVideoAnnotations: false,
          pointerEvents: PointerEvents.auto,
          mute: false,
          enableCaption: true,
          captionLanguage: 'id',
          interfaceLanguage: 'id',
          videoStateUpdateInterval: 250,
        ),
      );

      // Sinkronisasi posisi real-time dari video YouTube secara terisolasi tanpa memicu root setState
      _videoStateSubscription = _youtubeController!.videoStateStream.listen((state) {
        if (!mounted) return;
        _updateCurrentPosition(state.position);
      });

      _youtubePlayerSubscription = _youtubeController!.listen((value) {
        if (!mounted) return;

        // Cegah race condition: jangan menimpa status pemutaran jika baru saja ada aksi manual user (<800ms)
        final isRecentManualAction = _lastManualActionTime != null &&
            DateTime.now().difference(_lastManualActionTime!).inMilliseconds < 800;

        if (!isRecentManualAction) {
          if (value.playerState == PlayerState.playing && !_isPlaying) {
            setState(() {
              _isPlaying = true;
            });
          } else if (value.playerState == PlayerState.paused && _isPlaying) {
            setState(() {
              _isPlaying = false;
            });
          }
        }

        // Sinkronisasi status fullscreen jika controller berubah
        if (_isFullscreen != value.fullScreenOption.enabled) {
          setState(() {
            _isFullscreen = value.fullScreenOption.enabled;
          });
        }

        // Sinkronisasi total durasi video YouTube jika terdeteksi
        if (value.metaData.duration > Duration.zero &&
            _totalDuration != value.metaData.duration) {
          setState(() {
            _totalDuration = value.metaData.duration;
          });
        }

        // Otomatis putar lagu berikutnya jika video selesai
        if (value.playerState == PlayerState.ended) {
          _onSongFinished();
        }
      });
    } catch (_) {
      _youtubeController = null;
    }
  }

  @override
  void dispose() {
    _castSubscription?.cancel();
    if (widget.castService == null) {
      _castService.dispose();
    }
    _youtubePlayerSubscription?.cancel();
    _videoStateSubscription?.cancel();
    try {
      _youtubeController?.stopVideo();
    } catch (_) {}
    _youtubeController?.close();
    _stopPlaybackTimer();
    _currentPositionNotifier.dispose();
    super.dispose();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    // Hanya gunakan timer manual jika dalam mode pengujian
    if (!widget.isTestMode) return;
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isPlaying || _currentSong == null) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_currentPosition.inSeconds < _totalDuration.inSeconds) {
          _updateCurrentPosition(_currentPosition + const Duration(seconds: 1));
        } else {
          timer.cancel();
          _onSongFinished();
        }
      });
    });
  }

  void _stopPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  void _onSongFinished() {
    if (_queue.isNotEmpty) {
      final nextSong = _queue.removeAt(0);
      _playSong(nextSong);
    } else {
      _stopPlaybackTimer();
      _updateCurrentPosition(Duration.zero);
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Duration _parseSongDuration(String? durationStr) {
    if (durationStr == null || durationStr.isEmpty) {
      return const Duration(minutes: 3, seconds: 30);
    }
    final parts = durationStr.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 3;
      final s = int.tryParse(parts[1]) ?? 30;
      return Duration(minutes: m, seconds: s);
    }
    return const Duration(minutes: 3, seconds: 30);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final storage = await StorageService.getInstance();
      final user = await storage.getUser();

      final results = await Future.wait([
        _categoryService.getCategories().catchError((e) {
          debugPrint('User layout category load error: $e');
          return <CategoryModel>[];
        }),
        _songService.getSongs().catchError((e) {
          debugPrint('User layout song load error: $e');
          return <SongModel>[];
        }),
      ]);

      final cats = results[0] as List<CategoryModel>;
      final songs = results[1] as List<SongModel>;

      if (mounted) {
        setState(() {
          _currentUser = user;
          _categories = cats.isNotEmpty ? cats : _categories;
          _allSongs = songs.isNotEmpty ? songs : _allSongs;
          // Saat pertama kali dibuka, player dalam kondisi kosong (standby).
          // Lagu baru muncul ketika pengguna memilih lagu dari katalog.
          _currentSong = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playSong(SongModel song) {
    _lastManualActionTime = DateTime.now();
    _stopPlaybackTimer();

    final videoId = YoutubeHelper.extractVideoId(song.songurl);
    if (videoId != null && !widget.isTestMode) {
      if (_youtubeController != null) {
        try {
          _youtubeController!.loadVideoById(
            videoId: videoId,
            startSeconds: 0,
          );
          _youtubeController!.seekTo(seconds: 0, allowSeekAhead: true);
          _youtubeController!.playVideo();
        } catch (_) {
          _createYoutubeController(videoId);
        }
      } else {
        _createYoutubeController(videoId);
      }
    }

    setState(() {
      _currentSong = song;
      _updateCurrentPosition(Duration.zero);
      _totalDuration = _parseSongDuration(song.songduration);
      _isPlaying = true;
    });
    if (_castService.connectedDevice != null && videoId != null) {
      _castService.castVideo(
        videoId,
        title: song.songtitle,
        artist: song.songsinger,
        thumbnailUrl: YoutubeHelper.getThumbnailUrl(videoId),
      );
    }
    _startPlaybackTimer();
  }

  void _togglePlayPause() {
    if (_currentSong == null) {
      if (_allSongs.isNotEmpty) {
        _playSong(_allSongs.first);
      }
      return;
    }
    _lastManualActionTime = DateTime.now();
    final willPlay = !_isPlaying;
    setState(() {
      _isPlaying = willPlay;
    });
    if (willPlay) {
      try {
        _youtubeController?.playVideo();
      } catch (_) {}
      if (_castService.connectedDevice != null) {
        _castService.play();
      }
      _startPlaybackTimer();
    } else {
      try {
        _youtubeController?.pauseVideo();
      } catch (_) {}
      if (_castService.connectedDevice != null) {
        _castService.pause();
      }
      _stopPlaybackTimer();
    }
  }

  void _stopSong() {
    _lastManualActionTime = DateTime.now();
    _stopPlaybackTimer();
    try {
      _youtubeController?.pauseVideo();
      _youtubeController?.stopVideo();
      _youtubeController?.seekTo(seconds: 0, allowSeekAhead: true);
    } catch (_) {}
    if (_castService.connectedDevice != null) {
      _castService.pause();
    }
    setState(() {
      _isPlaying = false;
      _updateCurrentPosition(Duration.zero);
    });
  }

  void _nextSong() {
    if (_queue.isNotEmpty) {
      final nextSong = _queue.removeAt(0);
      _playSong(nextSong);
    } else if (_allSongs.isNotEmpty && _currentSong != null) {
      final currentIndex = _allSongs.indexWhere((s) => s.songid == _currentSong!.songid);
      if (currentIndex != -1 && currentIndex + 1 < _allSongs.length) {
        _playSong(_allSongs[currentIndex + 1]);
      } else {
        _playSong(_allSongs.first);
      }
    }
  }

  void _previousSong() {
    _lastManualActionTime = DateTime.now();
    if (_currentPosition.inSeconds > 3) {
      try {
        _youtubeController?.seekTo(seconds: 0, allowSeekAhead: true);
      } catch (_) {}
      if (_castService.connectedDevice != null) {
        _castService.seek(Duration.zero);
      }
      setState(() {
        _updateCurrentPosition(Duration.zero);
      });
    } else if (_allSongs.isNotEmpty && _currentSong != null) {
      final currentIndex = _allSongs.indexWhere((s) => s.songid == _currentSong!.songid);
      if (currentIndex > 0) {
        _playSong(_allSongs[currentIndex - 1]);
      } else {
        try {
          _youtubeController?.seekTo(seconds: 0, allowSeekAhead: true);
        } catch (_) {}
        if (_castService.connectedDevice != null) {
          _castService.seek(Duration.zero);
        }
        setState(() {
          _updateCurrentPosition(Duration.zero);
        });
      }
    }
  }

  void _seek(Duration position) {
    _lastManualActionTime = DateTime.now();
    try {
      _youtubeController?.seekTo(
        seconds: position.inSeconds.toDouble(),
        allowSeekAhead: true,
      );
    } catch (_) {}
    if (_castService.connectedDevice != null) {
      _castService.seek(position);
    }
    setState(() {
      _updateCurrentPosition(position);
    });
  }

  void _toggleFullscreen() {
    final nextFullscreen = !_isFullscreen;
    setState(() {
      _isFullscreen = nextFullscreen;
    });
    try {
      if (nextFullscreen) {
        _youtubeController?.enterFullScreen();
      } else {
        _youtubeController?.exitFullScreen();
      }
    } catch (_) {}
  }

  void _onVolumeChanged(double v) {
    setState(() {
      _volume = v;
      _isMuted = false;
    });
    try {
      _youtubeController?.setVolume((v * 100).toInt());
      if (v > 0) {
        _youtubeController?.unMute();
      } else {
        _youtubeController?.mute();
      }
    } catch (_) {}
  }

  void _toggleMute() {
    final nextMuted = !_isMuted;
    setState(() {
      _isMuted = nextMuted;
    });
    try {
      if (nextMuted) {
        _youtubeController?.mute();
      } else {
        _youtubeController?.unMute();
        _youtubeController?.setVolume((_volume * 100).toInt());
      }
    } catch (_) {}
  }


  void _addToQueue(SongModel song) {
    setState(() {
      _queue.add(song);
    });
  }

  void _removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      setState(() {
        _queue.removeAt(index);
      });
    }
  }

  void _clearQueue() {
    setState(() {
      _queue.clear();
    });
  }

  void _reorderQueue(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final song = _queue.removeAt(oldIndex);
      _queue.insert(newIndex, song);
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardGlassBorder),
        ),
        title: const Text(
          'Konfirmasi Keluar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari Tomsi Karaoke?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.accentSky)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authService = ApiAuthService();
      await authService.logout();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _openCastModal(BuildContext context) {
    final videoId = YoutubeHelper.extractVideoId(_currentSong?.songurl);
    CastDeviceModal.show(
      context,
      castService: _castService,
      currentVideoId: videoId,
      songTitle: _currentSong?.songtitle,
      songSinger: _currentSong?.songsinger,
      songThumbnail: videoId != null ? YoutubeHelper.getThumbnailUrl(videoId) : null,
      onDeviceChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _openSongSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle & close button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                  ),

                  // SongSearchPanel (Full space inside modal)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: SongSearchPanel(
                        songs: _allSongs,
                        categories: _categories,
                        queue: _queue,
                        currentPlayingSong: _currentSong,
                        isLoading: _isLoading,
                        onPlaySong: (song) {
                          _playSong(song);
                          Navigator.of(modalContext).pop();
                        },
                        onAddToQueue: (song) {
                          _addToQueue(song);
                          setModalState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${song.songtitle} masuk antrean'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onRemoveFromQueue: (index) {
                          _removeFromQueue(index);
                          setModalState(() {});
                        },
                        onClearQueue: () {
                          _clearQueue();
                          setModalState(() {});
                        },
                        onRefresh: _loadData,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _currentUser?.displayName ?? 'Penyanyi';
    final username = _currentUser?.username ?? 'user';
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape ||
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final isCompactLandscape = isLandscape && MediaQuery.of(context).size.height < 550;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Header Bar (Minimalis & Tanpa Subteks)
              _buildHeader(displayName, username, isCompact: isCompactLandscape),

              // 2. Main Karaoke Screen Content
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isLandscapeLayout = isLandscape ||
                        constraints.maxWidth > constraints.maxHeight;

                    // ================= 1. LANDSCAPE LAYOUT (Tablet & Smartphone) =================
                    // Kolom Kiri: Player Display & Controls
                    // Kolom Kanan: Cari Lagu & Playlist
                    if (isLandscapeLayout) {
                      final isCompact = constraints.maxHeight < 550;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 12 : 20,
                          vertical: isCompact ? 4 : 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Kolom Kiri: Player Stage & Controls (Adaptif Tinggi)
                            Expanded(
                              flex: isCompact ? 10 : 11,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Player Cinema Stage (Otomatis menyesuaikan sisa tinggi 16:9)
                                  Expanded(
                                    child: Center(
                                      child: PlayerDisplay(
                                        key: _playerDisplayKey,
                                        song: _currentSong,
                                        isPlaying: _isPlaying,
                                        currentPosition: _currentPosition,
                                        totalDuration: _totalDuration,
                                        queueCount: _queue.length,
                                        isFullscreen: _isFullscreen,
                                        youtubeController: _youtubeController,
                                        isTestMode: widget.isTestMode,
                                        onPlayPauseTapped: _togglePlayPause,
                                        onOpenSearchModal: () => _openSongSearchModal(context),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 6 : 10),

                                  // Studio Playback Controls
                                  PlayerControls(
                                    song: _currentSong,
                                    isPlaying: _isPlaying,
                                    hasSong: _currentSong != null,
                                    currentPosition: _currentPosition,
                                    currentPositionListenable: _currentPositionNotifier,
                                    totalDuration: _totalDuration,
                                    onSeek: _seek,
                                    onTogglePlayPause: _togglePlayPause,
                                    onStop: _stopSong,
                                    onNext: _nextSong,
                                    onPrevious: _previousSong,
                                    volume: _volume,
                                    isMuted: _isMuted,
                                    isFullscreen: _isFullscreen,
                                    onToggleFullscreen: _toggleFullscreen,
                                    onVolumeChanged: _onVolumeChanged,
                                    onToggleMute: _toggleMute,
                                    onCastTapped: () => _openCastModal(context),
                                    isCasting: _castService.connectedDevice != null,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(width: isCompact ? 10 : 14),

                            // Kolom Kanan: Cari Lagu & Playlist (Vertikal untuk Tablet, Tabbed untuk Smartphone)
                            Expanded(
                              flex: isCompact ? 10 : 9,
                              child: SongCatalogPlaylistSection(
                                axis: Axis.vertical,
                                songs: _allSongs,
                                categories: _categories,
                                queue: _queue,
                                currentPlayingSong: _currentSong,
                                isLoading: _isLoading,
                                onPlaySong: _playSong,
                                onAddToQueue: _addToQueue,
                                onRemoveFromQueue: _removeFromQueue,
                                onReorderQueue: _reorderQueue,
                                onClearQueue: _clearQueue,
                                onRefresh: _loadData,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // ================= 2. SMARTPHONE PORTRAIT LAYOUT (< 768px atau Vertikal) =================
                    final isHeightConstrained = MediaQuery.of(context).size.height < 620;

                    if (isHeightConstrained) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Player Cinema Stage (Full Width)
                            PlayerDisplay(
                              key: _playerDisplayKey,
                              song: _currentSong,
                              isPlaying: _isPlaying,
                              currentPosition: _currentPosition,
                              totalDuration: _totalDuration,
                              queueCount: _queue.length,
                              isFullscreen: _isFullscreen,
                              youtubeController: _youtubeController,
                              isTestMode: widget.isTestMode,
                              onPlayPauseTapped: _togglePlayPause,
                              onOpenSearchModal: () => _openSongSearchModal(context),
                            ),
                            const SizedBox(height: 8),

                            // Studio Playback Controls
                            PlayerControls(
                              song: _currentSong,
                              isPlaying: _isPlaying,
                              hasSong: _currentSong != null,
                              currentPosition: _currentPosition,
                              currentPositionListenable: _currentPositionNotifier,
                              totalDuration: _totalDuration,
                              onSeek: _seek,
                              onTogglePlayPause: _togglePlayPause,
                              onStop: _stopSong,
                              onNext: _nextSong,
                              onPrevious: _previousSong,
                              volume: _volume,
                              isMuted: _isMuted,
                              isFullscreen: _isFullscreen,
                              onToggleFullscreen: _toggleFullscreen,
                              onVolumeChanged: _onVolumeChanged,
                              onToggleMute: _toggleMute,
                              onCastTapped: () => _openCastModal(context),
                              isCasting: _castService.connectedDevice != null,
                            ),
                            const SizedBox(height: 10),

                            // Cari Lagu & Playlist Section (Berdampingan secara horizontal di mobile)
                            SizedBox(
                              height: 480,
                              child: SongCatalogPlaylistSection(
                                songs: _allSongs,
                                categories: _categories,
                                queue: _queue,
                                currentPlayingSong: _currentSong,
                                isLoading: _isLoading,
                                onPlaySong: _playSong,
                                onAddToQueue: _addToQueue,
                                onRemoveFromQueue: _removeFromQueue,
                                onReorderQueue: _reorderQueue,
                                onClearQueue: _clearQueue,
                                onRefresh: _loadData,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Player Cinema Stage (Full Width, Fixed)
                          PlayerDisplay(
                            key: _playerDisplayKey,
                            song: _currentSong,
                            isPlaying: _isPlaying,
                            currentPosition: _currentPosition,
                            totalDuration: _totalDuration,
                            queueCount: _queue.length,
                            isFullscreen: _isFullscreen,
                            youtubeController: _youtubeController,
                            isTestMode: widget.isTestMode,
                            onPlayPauseTapped: _togglePlayPause,
                            onOpenSearchModal: () => _openSongSearchModal(context),
                          ),
                          const SizedBox(height: 8),

                          // Studio Playback Controls (Fixed)
                          PlayerControls(
                            song: _currentSong,
                            isPlaying: _isPlaying,
                            hasSong: _currentSong != null,
                            currentPosition: _currentPosition,
                            currentPositionListenable: _currentPositionNotifier,
                            totalDuration: _totalDuration,
                            onSeek: _seek,
                            onTogglePlayPause: _togglePlayPause,
                            onStop: _stopSong,
                            onNext: _nextSong,
                            onPrevious: _previousSong,
                            volume: _volume,
                            isMuted: _isMuted,
                            isFullscreen: _isFullscreen,
                            onToggleFullscreen: _toggleFullscreen,
                            onVolumeChanged: _onVolumeChanged,
                            onToggleMute: _toggleMute,
                            onCastTapped: () => _openCastModal(context),
                            isCasting: _castService.connectedDevice != null,
                          ),
                          const SizedBox(height: 10),

                          // Cari Lagu & Playlist Section
                          Expanded(
                            child: SongCatalogPlaylistSection(
                              songs: _allSongs,
                              categories: _categories,
                              queue: _queue,
                              currentPlayingSong: _currentSong,
                              isLoading: _isLoading,
                              onPlaySong: _playSong,
                              onAddToQueue: _addToQueue,
                              onRemoveFromQueue: _removeFromQueue,
                              onReorderQueue: _reorderQueue,
                              onClearQueue: _clearQueue,
                              onRefresh: _loadData,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String displayName, String username, {bool isCompact = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: isCompact ? 4.0 : 8.0),
      child: Row(
        children: [
          // Logo & Title (Clean & Minimalist: No subtexts!)
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.iconGradient,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'asset/image/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Tomsi Karaoke',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Logout Button
          IconButton(
            onPressed: _handleLogout,
            tooltip: 'Keluar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
