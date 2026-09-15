import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/song_model.dart';

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
  final Axis axis;

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
    this.axis = Axis.horizontal,
  });

  @override
  State<SongCatalogPlaylistSection> createState() => _SongCatalogPlaylistSectionState();
}

class _SongCatalogPlaylistSectionState extends State<SongCatalogPlaylistSection> {
  final TextEditingController _searchController = TextEditingController();

  String? _selectedJudul;
  String? _selectedPencipta;
  String? _selectedNada;
  bool _isFilterExpanded = false;
  int _compactTabIndex = 0; // 0 = Cari Lagu, 1 = Playlist

  bool get _hasActiveFilters =>
      _selectedJudul != null || _selectedPencipta != null || _selectedNada != null;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedJudul != null) count++;
    if (_selectedPencipta != null) count++;
    if (_selectedNada != null) count++;
    return count;
  }

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
        name: 'Pop',
        createdAt: DateTime.now(),
      ),
    );
    return cat.name;
  }

  List<String> get _judulOptions {
    final titles = widget.songs
        .map((s) => s.songtitle.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    titles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return titles;
  }

  List<String> get _penciptaOptions {
    final singers = widget.songs
        .map((s) => s.songsinger.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    singers.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return singers;
  }

  List<String> get _nadaOptions {
    final nadas = widget.songs
        .map((s) => s.songnada?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    nadas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return nadas;
  }

  List<SongModel> get _filteredSongs {
    final query = _searchController.text.trim().toLowerCase();
    return widget.songs.where((song) {
      final matchesQuery = query.isEmpty ||
          song.songtitle.toLowerCase().contains(query) ||
          song.songsinger.toLowerCase().contains(query);

      final matchesJudul = _selectedJudul == null ||
          song.songtitle.trim().toLowerCase() == _selectedJudul!.trim().toLowerCase();

      final matchesPencipta = _selectedPencipta == null ||
          song.songsinger.trim().toLowerCase() == _selectedPencipta!.trim().toLowerCase();

      final matchesNada = _selectedNada == null ||
          (song.songnada != null &&
              song.songnada!.trim().toLowerCase() == _selectedNada!.trim().toLowerCase());

      return matchesQuery && matchesJudul && matchesPencipta && matchesNada;
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
            decoration: InputDecoration(
              hintText: 'Cari lagu...',
              hintStyle: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6FA4CE), size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. Filter Box (Steel Blue Container, Expandable / Collapsible)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3B5673),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF283B4F), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Toggle Bar
              InkWell(
                onTap: () {
                  setState(() {
                    _isFilterExpanded = !_isFilterExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Filter Lagu',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (_hasActiveFilters) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_activeFilterCount aktif',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(
                        _isFilterExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // Dropdown Options (Collapsible: hanya di-render saat dibuka)
              if (_isFilterExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 2, 9, 9),
                  child: Column(
                    children: [
                      // Dropdown: Judul Lagu
                      _buildFilterDropdown(
                        label: 'judul lagu',
                        selectedValue: _selectedJudul,
                        options: _judulOptions,
                        onChanged: (val) {
                          setState(() {
                            _selectedJudul = val;
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Dropdown: Pencipta
                      _buildFilterDropdown(
                        label: 'pencipta',
                        selectedValue: _selectedPencipta,
                        options: _penciptaOptions,
                        onChanged: (val) {
                          setState(() {
                            _selectedPencipta = val;
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Dropdown: Nada
                      _buildFilterDropdown(
                        label: 'nada',
                        selectedValue: _selectedNada,
                        options: _nadaOptions,
                        onChanged: (val) {
                          setState(() {
                            _selectedNada = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    strokeWidth: 2,
                  ),
                )
              : filteredSongs.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
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
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: filteredSongs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final categoryName = _getCategoryName(
                          song.songcategory,
                          embeddedCategory: song.category,
                        );
                        final isCurrent = widget.currentPlayingSong?.songid == song.songid;

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
                      ? Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4))
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
                      ? Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4))
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
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                    onReorder: (oldIndex, newIndex) {
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

  /// Dropdown filter box with label and arrow
  Widget _buildFilterDropdown({
    required String label,
    required String? selectedValue,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF5F81A5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF38536F), width: 1.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedValue,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFF0F172A),
            size: 22,
          ),
          hint: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          selectedItemBuilder: (context) {
            return [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              ...options.map((opt) {
                return Text(
                  opt,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              }),
            ];
          },
          dropdownColor: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Semua ${label[0].toUpperCase()}${label.substring(1)}',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...options.map((opt) {
              return DropdownMenuItem<String?>(
                value: opt,
                child: Text(
                  opt,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrent ? AppColors.accentCyan : cardBorder,
            width: isCurrent ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Info Lagu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.songtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    song.songsinger,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8EA9C7),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Badges Wrap (responsif tanpa overflow)
                  Wrap(
                    spacing: 3,
                    runSpacing: 2,
                    children: [
                      _buildBadge(categoryName, const Color(0xFF334155), const Color(0xFF94A3B8)),
                      if (song.songnada != null && song.songnada!.isNotEmpty)
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

            // Tombol Tambah ke Playlist
            IconButton(
              onPressed: () {
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
              tooltip: 'Tambah ke Playlist',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.playlist_add_rounded,
                color: Color(0xFF85B6DF),
                size: 20,
              ),
            ),
          ],
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
              _buildBadge(categoryName, const Color(0xFF334155), const Color(0xFF94A3B8)),
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
              icon: const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
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
