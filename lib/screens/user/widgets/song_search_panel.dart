import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/song_model.dart';

class SongSearchPanel extends StatefulWidget {
  final List<SongModel> songs;
  final List<CategoryModel> categories;
  final List<SongModel> queue;
  final SongModel? currentPlayingSong;
  final bool isLoading;
  final ValueChanged<SongModel> onPlaySong;
  final ValueChanged<SongModel> onAddToQueue;
  final ValueChanged<int>? onRemoveFromQueue;
  final VoidCallback? onClearQueue;
  final Future<void> Function()? onRefresh;

  const SongSearchPanel({
    super.key,
    required this.songs,
    required this.categories,
    required this.queue,
    required this.currentPlayingSong,
    this.isLoading = false,
    required this.onPlaySong,
    required this.onAddToQueue,
    this.onRemoveFromQueue,
    this.onClearQueue,
    this.onRefresh,
  });

  @override
  State<SongSearchPanel> createState() => _SongSearchPanelState();
}

class _SongSearchPanelState extends State<SongSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryFilter; // null = Semua
  int _activeTab = 0; // 0 = Katalog Lagu, 1 = Antrean (Queue)

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
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
        name: 'Kategori #$categoryId',
        createdAt: DateTime.now(),
      ),
    );
    return cat.name;
  }

  List<SongModel> get _filteredSongs {
    final query = _searchController.text.trim().toLowerCase();
    return widget.songs.where((song) {
      final matchesQuery = query.isEmpty ||
          song.songtitle.toLowerCase().contains(query) ||
          song.songsinger.toLowerCase().contains(query);

      final matchesCategory = _selectedCategoryFilter == null ||
          song.songcategory == _selectedCategoryFilter;

      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSongs;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Panel Header Tabs (Katalog Lagu vs Antrean)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardGlassBorder, width: 1)),
            ),
            child: Row(
              children: [
                // Tab Katalog
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _activeTab = 0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeTab == 0
                            ? AppColors.primaryElectric.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _activeTab == 0
                              ? AppColors.accentCyan
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_music_rounded,
                            size: 16,
                            color: _activeTab == 0 ? AppColors.accentLight : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Katalog (${widget.songs.length})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _activeTab == 0 ? Colors.white : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Tab Antrean
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _activeTab = 1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeTab == 1
                            ? AppColors.primaryElectric.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _activeTab == 1
                              ? AppColors.accentCyan
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            size: 16,
                            color: _activeTab == 1 ? AppColors.accentLight : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Antrean (${widget.queue.length})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _activeTab == 1 ? Colors.white : AppColors.textMuted,
                              ),
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

          // 2. Tab Content: Katalog vs Antrean
          Expanded(
            child: _activeTab == 0
                ? _buildCatalogTab(filtered)
                : _buildQueueTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTab(List<SongModel> filtered) {
    return Column(
      children: [
        // Search bar & Category filters
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari lagu...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentSky, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 16),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.cardGlassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.cardGlassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.2),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Category Choice Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _selectedCategoryFilter == null,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategoryFilter = null;
                          });
                        }
                      },
                      selectedColor: AppColors.primaryElectric,
                      backgroundColor: AppColors.cardGlass,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedCategoryFilter == null ? FontWeight.bold : FontWeight.normal,
                        color: _selectedCategoryFilter == null ? Colors.white : AppColors.textSecondary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _selectedCategoryFilter == null
                              ? AppColors.accentCyan
                              : AppColors.cardGlassBorder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ...widget.categories.map((cat) {
                      final catId = _parseCategoryId(cat.id);
                      final isSelected = _selectedCategoryFilter == catId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryFilter = selected ? catId : null;
                            });
                          },
                          selectedColor: AppColors.primaryElectric,
                          backgroundColor: AppColors.cardGlass,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.accentCyan
                                  : AppColors.cardGlassBorder,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(color: AppColors.cardGlassBorder, height: 1),

        // Song List
        Expanded(
          child: widget.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_off_rounded,
                            size: 40,
                            color: AppColors.accentSky.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Lagu tidak ditemukan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: widget.onRefresh ?? () async {},
                      color: AppColors.accentCyan,
                      backgroundColor: AppColors.surfaceDark,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final song = filtered[index];
                          final isCurrentlyPlaying = widget.currentPlayingSong?.songid == song.songid;
                          final categoryName = _getCategoryName(
                            song.songcategory,
                            embeddedCategory: song.category,
                          );

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrentlyPlaying
                                  ? AppColors.primaryElectric.withValues(alpha: 0.25)
                                  : AppColors.cardGlass,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentlyPlaying
                                    ? AppColors.accentCyan
                                    : AppColors.cardGlassBorder,
                                width: isCurrentlyPlaying ? 1.4 : 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Title & Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.songtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentlyPlaying ? AppColors.accentCyan : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        song.songsinger,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.accentSky,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Badges (Category & Nada)
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              categoryName,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          if (song.songnada != null && song.songnada!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: song.songnada!.toLowerCase() == 'wanita'
                                                    ? const Color(0xFFFF4081).withValues(alpha: 0.15)
                                                    : AppColors.primaryElectric.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                song.songnada!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: song.songnada!.toLowerCase() == 'wanita'
                                                      ? const Color(0xFFFF80AB)
                                                      : AppColors.accentCyan,
                                                ),
                                              ),
                                            ),
                                          if (song.songduration != null && song.songduration!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 2.0),
                                              child: Text(
                                                song.songduration!,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Action 1: Add to Queue button
                                IconButton(
                                  onPressed: () {
                                    widget.onAddToQueue(song);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('"${song.songtitle}" ditambahkan ke antrean'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: AppColors.primaryElectric,
                                      ),
                                    );
                                  },
                                  tooltip: 'Tambah ke Antrean',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.playlist_add_rounded,
                                    color: AppColors.accentSky,
                                    size: 22,
                                  ),
                                ),

                                // Action 2: Putar Sekarang Button
                                ElevatedButton.icon(
                                  onPressed: () => widget.onPlaySong(song),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCurrentlyPlaying
                                        ? AppColors.primaryElectric
                                        : AppColors.primaryRoyal,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: Icon(
                                    isCurrentlyPlaying
                                        ? Icons.refresh_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    isCurrentlyPlaying ? 'Putar Ulang' : 'Putar',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildQueueTab() {
    final queue = widget.queue;

    if (queue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 48,
                color: AppColors.accentSky.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              const Text(
                'Antrean Lagu Masih Kosong',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih lagu dari Katalog Lagu dan tekan tombol (+) antre untuk menambahkan lagu berikutnya.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Queue Header Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ${queue.length} lagu di antrean',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentSky,
                  ),
                ),
              ),
              if (widget.onClearQueue != null)
                TextButton.icon(
                  onPressed: widget.onClearQueue,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.error),
                  label: const Text(
                    'Kosongkan',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const Divider(color: AppColors.cardGlassBorder, height: 1),

        // Queue List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: queue.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final song = queue[index];

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardGlass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardGlassBorder, width: 0.8),
                ),
                child: Row(
                  children: [
                    // Queue Order Badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryElectric.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Song Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.songtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.songsinger,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentSky,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Play Now button
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: AppColors.accentCyan, size: 22),
                      tooltip: 'Putar Sekarang',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        widget.onPlaySong(song);
                        widget.onRemoveFromQueue?.call(index);
                      },
                    ),

                    // Remove from queue button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                      tooltip: 'Hapus dari Antrean',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onRemoveFromQueue?.call(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
