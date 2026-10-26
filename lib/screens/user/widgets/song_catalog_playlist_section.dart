import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/song_filter.dart';
import '../../../models/song_model.dart';
import 'song_cover_thumbnail.dart';
import 'song_filter_dropdown.dart';

class SongCatalogPlaylistSection extends StatefulWidget {
  final List<SongModel> songs;
  final List<CategoryModel> categories;
  final List<SongModel> queue;
  final SongModel? currentPlayingSong;
  final bool isLoading;
  final ValueChanged<SongModel> onPlaySong;
  final ValueChanged<SongModel> onAddToQueue;
  final ValueChanged<int>? onRemoveFromQueue;
  final Function(int oldIndex, int newIndex)? onReorderQueue;
  final VoidCallback? onClearQueue;
  final Future<void> Function()? onRefresh;
  final void Function(String query, SongFilter filter)? onSearch;
  final Future<void> Function()? onLoadMore;
  final bool isLoadingMore;
  final bool hasMore;
  final SongFilter selectedFilter;
  final ValueChanged<SongFilter>? onFilterChanged;
  final Axis axis;
  final bool isTestMode;

  const SongCatalogPlaylistSection({
    super.key,
    required this.songs,
    required this.categories,
    required this.queue,
    required this.currentPlayingSong,
    this.isLoading = false,
    required this.onPlaySong,
    required this.onAddToQueue,
    this.onRemoveFromQueue,
    this.onReorderQueue,
    this.onClearQueue,
    this.onRefresh,
    this.onSearch,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.selectedFilter = SongFilter.karaoke,
    this.onFilterChanged,
    this.axis = Axis.horizontal,
    this.isTestMode = false,
  });

  @override
  State<SongCatalogPlaylistSection> createState() =>
      _SongCatalogPlaylistSectionState();
}

class _SongCatalogPlaylistSectionState
    extends State<SongCatalogPlaylistSection> {
  static const double _loadMoreThreshold = 300;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _searchScrollController = ScrollController();

  int _compactTabIndex = 0; // 0 = Cari Lagu, 1 = Playlist

  Timer? _searchDebounce;
  DateTime? _lastLoadMoreTrigger;

  void _triggerSearch(String val) {
    if (widget.onSearch != null) {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        widget.onSearch!(val, widget.selectedFilter);
      });
    }
  }

  void _maybeLoadMore() {
    if (widget.onLoadMore == null || widget.isLoadingMore || !widget.hasMore) {
      return;
    }
    if (!_searchScrollController.hasClients) return;

    final position = _searchScrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) {
      return;
    }

    final now = DateTime.now();
    if (_lastLoadMoreTrigger != null &&
        now.difference(_lastLoadMoreTrigger!).inMilliseconds < 800) {
      return;
    }
    _lastLoadMoreTrigger = now;
    widget.onLoadMore!();
  }

  bool get _showSearchFooter => widget.isLoadingMore || !widget.hasMore;

  List<SongModel> _shuffledSongs = [];
  List<SongModel> _lastRawSongs = [];

  void _syncShuffledSongs({bool force = false}) {
    final incoming = widget.songs;
    if (widget.isTestMode) {
      _shuffledSongs = List<SongModel>.from(incoming);
      _lastRawSongs = List<SongModel>.from(incoming);
      return;
    }

    final isAppend =
        !force &&
        _shuffledSongs.isNotEmpty &&
        incoming.length > _lastRawSongs.length &&
        _hasSamePrefix(incoming, _lastRawSongs);

    if (isAppend) {
      final existingIds = _shuffledSongs.map((song) => song.songid).toSet();
      final appended = incoming
          .where((song) => existingIds.add(song.songid))
          .toList();
      _shuffledSongs = [..._shuffledSongs, ...appended];
    } else {
      _shuffledSongs = List<SongModel>.from(incoming)..shuffle();
    }
    _lastRawSongs = List<SongModel>.from(incoming);
  }

  bool _hasSamePrefix(List<SongModel> incoming, List<SongModel> reference) {
    if (incoming.length < reference.length) return false;
    for (var i = 0; i < reference.length; i++) {
      if (incoming[i].songid != reference[i].songid) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _searchScrollController.addListener(_maybeLoadMore);
    _syncShuffledSongs(force: true);
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant SongCatalogPlaylistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songs != oldWidget.songs) {
      _syncShuffledSongs();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _parseCategoryId(String id) {
    final numeric = id.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numeric) ?? 1;
  }

  String _getCategoryName(int categoryId, {CategoryModel? embeddedCategory}) {
    if (embeddedCategory != null && embeddedCategory.name.isNotEmpty) {
      return embeddedCategory.name;
    }
    final cat = widget.categories.firstWhere(
      (c) => _parseCategoryId(c.id) == categoryId,
      orElse: () => CategoryModel(
        id: 'cat_$categoryId',
        name: 'Pop',
        createdAt: DateTime.now(),
      ),
    );
    return cat.name;
  }

  List<SongModel> get _filteredSongs {
    final query = _searchController.text.trim().toLowerCase();
    final sourceList = (query.isEmpty && _shuffledSongs.isNotEmpty)
        ? _shuffledSongs
        : widget.songs;

    return sourceList.where((song) {
      return query.isEmpty ||
          song.songtitle.toLowerCase().contains(query) ||
          song.songsinger.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const filterPanelBg = Color(0xFF537699); // Steel blue from design
    const cardBg = Color(0xFF162235); // Dark navy card
    const cardBorder = Color(0xFF24364F);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactVertical =
            widget.axis == Axis.vertical && constraints.maxHeight < 500;

        if (isCompactVertical) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Compact Segmented Tab Bar (Cari Lagu vs Playlist)
                _buildCompactTabBar(),
                // Tab Content
                Expanded(
                  child: _compactTabIndex == 0
                      ? _buildSearchSection(
                          context,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                        )
                      : _buildPlaylistSection(
                          context,
                          filterPanelBg: filterPanelBg,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          hideHeaderTab: true,
                        ),
                ),
              ],
            ),
          );
        }

        if (widget.axis == Axis.vertical) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top section: Cari Lagu & Hasil Pencarian
                Expanded(
                  flex: 5,
                  child: _buildSearchSection(
                    context,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                  ),
                ),
                const SizedBox(height: 10),
                // Bottom section: Playlist
                Expanded(
                  flex: 4,
                  child: _buildPlaylistSection(
                    context,
                    filterPanelBg: filterPanelBg,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= LEFT COLUMN: CARI LAGU & HASIL PENCARIAN =================
              Expanded(
                child: _buildSearchSection(
                  context,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                ),
              ),
              const SizedBox(width: 10),
              // ================= RIGHT COLUMN: PLAYLIST =================
              Expanded(
                child: _buildPlaylistSection(
                  context,
                  filterPanelBg: filterPanelBg,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchSection(
    BuildContext context, {
    required Color cardBg,
    required Color cardBorder,
  }) {
    final filteredSongs = _filteredSongs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Search Bar
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: _triggerSearch,
            onSubmitted: (val) {
              _searchDebounce?.cancel();
              widget.onSearch?.call(val, widget.selectedFilter);
            },
            decoration: InputDecoration(
              hintText: widget.selectedFilter.isKaraoke
                  ? 'Cari lagu karaoke...'
                  : 'Cari lagu non karaoke...',
              hintStyle: const TextStyle(
                color: Color(0xFF8E9BAE),
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF6FA4CE),
                size: 18,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _searchController.clear();
                        _searchDebounce?.cancel();
                        _syncShuffledSongs(force: true);
                        widget.onSearch?.call('', widget.selectedFilter);
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. Pilihan jenis lagu: Karaoke / Non Karaoke
        SongFilterDropdown(
          selectedFilter: widget.selectedFilter,
          onChanged: widget.onFilterChanged,
        ),
        const SizedBox(height: 10),

        // 3. Section Title: Hasil Pencarian
        const Padding(
          padding: EdgeInsets.only(left: 2.0, bottom: 6.0),
          child: Text(
            'hasil pencarian',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF98B8DA),
            ),
          ),
        ),

        // 4. Hasil Pencarian Cards (Scrollable Area)
        Expanded(
          child: widget.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accentCyan,
                    ),
                    strokeWidth: 2,
                  ),
                )
              : filteredSongs.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'Tidak ada lagu yang cocok',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _searchScrollController,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: filteredSongs.length + (_showSearchFooter ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    if (index >= filteredSongs.length) {
                      return _buildSearchFooter();
                    }
                    final song = filteredSongs[index];
                    final categoryName = _getCategoryName(
                      song.songcategory,
                      embeddedCategory: song.category,
                    );
                    final isCurrent =
                        widget.currentPlayingSong?.songid == song.songid;

                    return _buildSearchResultCard(
                      song: song,
                      categoryName: categoryName,
                      isCurrent: isCurrent,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCompactTabBar() {
    return Container(
      height: 34,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF162235),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF24364F)),
      ),
      child: Row(
        children: [
          // Tab Cari Lagu
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _compactTabIndex = 0),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _compactTabIndex == 0
                      ? AppColors.primaryElectric.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: _compactTabIndex == 0
                      ? Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 13,
                      color: _compactTabIndex == 0
                          ? AppColors.accentCyan
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cari Lagu',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _compactTabIndex == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _compactTabIndex == 0
                            ? Colors.white
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab Playlist
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _compactTabIndex = 1),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _compactTabIndex == 1
                      ? AppColors.primaryElectric.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: _compactTabIndex == 1
                      ? Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      size: 13,
                      color: _compactTabIndex == 1
                          ? AppColors.accentCyan
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Playlist',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _compactTabIndex == 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _compactTabIndex == 1
                            ? Colors.white
                            : AppColors.textMuted,
                      ),
                    ),
                    if (widget.queue.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.queue.length}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistSection(
    BuildContext context, {
    required Color filterPanelBg,
    required Color cardBg,
    required Color cardBorder,
    bool hideHeaderTab = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Tab / Button Header: "playlist" (hanya jika tidak menggunakan tab atas)
        if (!hideHeaderTab) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: filterPanelBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF6B8FB5)),
              ),
              child: const Text(
                'playlist',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 2. Playlist Container (Scrollable inside)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: filterPanelBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF6B8FB5)),
            ),
            child: widget.queue.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.queue_music_rounded,
                              size: 26,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Playlist masih kosong',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tekan ikon (+) pada lagu untuk menambahkan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 6),
                    buildDefaultDragHandles: false,
                    itemCount: widget.queue.length,
                    onReorderItem: (oldIndex, newIndex) {
                      if (widget.onReorderQueue != null) {
                        widget.onReorderQueue!(oldIndex, newIndex);
                      }
                    },
                    itemBuilder: (context, index) {
                      final song = widget.queue[index];
                      final categoryName = _getCategoryName(
                        song.songcategory,
                        embeddedCategory: song.category,
                      );

                      return Padding(
                        key: ValueKey('queue_${song.songid}_$index'),
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: _buildPlaylistCard(
                          song: song,
                          index: index,
                          categoryName: categoryName,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchFooter() {
    if (widget.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Memuat lagu lainnya...',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'Semua hasil sudah ditampilkan',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
      ),
    );
  }

  /// Kartu Lagu di Kolom Hasil Pencarian (Kiri)
  Widget _buildSearchResultCard({
    required SongModel song,
    required String categoryName,
    required bool isCurrent,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        widget.onAddToQueue(song);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${song.songtitle}" ditambahkan ke playlist'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primaryElectric,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? AppColors.accentCyan : cardBorder,
            width: isCurrent ? 1.2 : 1.0,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowCard = constraints.maxWidth < 240;

            if (isNarrowCard) {
              // ================= SMARTPHONE / NARROW COLUMN =================
              // Thumbnail full-width (panjangnya sama dengan card-nya, rasio 16:9)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SongCoverThumbnail(
                            songUrl: song.songurl,
                            aspectRatio: 16 / 9,
                            borderRadius: 0,
                          ),
                          if (song.songduration != null &&
                              song.songduration!.isNotEmpty)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  song.songduration!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.songtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          song.songsinger,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF98B8DA),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 3,
                                runSpacing: 2,
                                children: [
                                  _buildBadge(
                                    categoryName,
                                    const Color(0xFF334155),
                                    const Color(0xFF94A3B8),
                                  ),
                                  if (song.songnada != null &&
                                      song.songnada!.isNotEmpty)
                                    _buildBadge(
                                      song.songnada!,
                                      const Color(0xFF0C4A6E),
                                      const Color(0xFF38BDF8),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => widget.onPlaySong(song),
                              tooltip: 'Putar Lagu',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                isCurrent
                                    ? Icons.refresh_rounded
                                    : Icons.play_arrow_rounded,
                                color: AppColors.accentCyan,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              onPressed: () {
                                widget.onAddToQueue(song);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '"${song.songtitle}" ditambahkan ke playlist',
                                    ),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppColors.primaryElectric,
                                  ),
                                );
                              },
                              tooltip: 'Tambah ke Playlist',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.playlist_add_rounded,
                                color: Color(0xFF85B6DF),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // ================= WIDE CARD / DESKTOP / TABLET =================
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SongCoverThumbnail(
                    songUrl: song.songurl,
                    width: 72,
                    height: 44,
                    borderRadius: 6,
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.songtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          song.songsinger,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF98B8DA),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 3,
                          runSpacing: 2,
                          children: [
                            _buildBadge(
                              categoryName,
                              const Color(0xFF334155),
                              const Color(0xFF94A3B8),
                            ),
                            if (song.songnada != null &&
                                song.songnada!.isNotEmpty)
                              _buildBadge(
                                song.songnada!,
                                const Color(0xFF0C4A6E),
                                const Color(0xFF38BDF8),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  IconButton(
                    onPressed: () => widget.onPlaySong(song),
                    tooltip: 'Putar Lagu',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isCurrent
                          ? Icons.refresh_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 2),

                  IconButton(
                    onPressed: () {
                      widget.onAddToQueue(song);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '"${song.songtitle}" ditambahkan ke playlist',
                          ),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.primaryElectric,
                        ),
                      );
                    },
                    tooltip: 'Tambah ke Playlist',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.playlist_add_rounded,
                      color: Color(0xFF85B6DF),
                      size: 20,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Kartu Lagu di Kolom Playlist (Kanan) - Desain Menurun (Vertical Stacked)
  Widget _buildPlaylistCard({
    required SongModel song,
    required int index,
    required String categoryName,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Baris Atas: Ikon Drag + Judul Lagu & Penyanyi + Tombol Hapus (Trash)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reorder Drag Handle
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(right: 6.0, top: 1.0),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
              ),

              // Judul Lagu & Penyanyi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.songtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.songsinger,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF98B8DA),
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol Hapus (Trash) di pojok kanan atas
              IconButton(
                onPressed: () {
                  widget.onRemoveFromQueue?.call(index);
                },
                tooltip: 'Hapus dari Playlist',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 2. Baris Tengah: Badges Kategori & Nada (Wrap menurun, tidak terpotong)
          Wrap(
            spacing: 4,
            runSpacing: 3,
            children: [
              _buildBadge(
                categoryName,
                const Color(0xFF334155),
                const Color(0xFF94A3B8),
              ),
              if (song.songnada != null && song.songnada!.isNotEmpty)
                _buildBadge(
                  song.songnada!,
                  const Color(0xFF0C4A6E),
                  const Color(0xFF38BDF8),
                ),
            ],
          ),

          const SizedBox(height: 7),

          // 3. Baris Bawah: Tombol ▶ Putar (Lebar penuh, menurun, mudah disentuh)
          SizedBox(
            width: double.infinity,
            height: 26,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onPlaySong(song);
                widget.onRemoveFromQueue?.call(index);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D6FBE),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0,
              ),
              icon: const Icon(
                Icons.play_arrow_rounded,
                size: 14,
                color: Colors.white,
              ),
              label: const Text(
                'Putar',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
