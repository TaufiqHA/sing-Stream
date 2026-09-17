import 'package:flutter/material.dart';
import '../../../core/services/api_category_service.dart';
import '../../../core/services/api_nada_service.dart';
import '../../../core/services/api_song_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/nada_service.dart';
import '../../../core/services/song_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/nada_model.dart';
import '../../../models/song_model.dart';
import '../../user/widgets/song_cover_thumbnail.dart';

class AdminSongScreen extends StatefulWidget {
  final SongService? songService;
  final CategoryService? categoryService;
  final NadaService? nadaService;

  const AdminSongScreen({
    super.key,
    this.songService,
    this.categoryService,
    this.nadaService,
  });

  @override
  State<AdminSongScreen> createState() => _AdminSongScreenState();
}

class _AdminSongScreenState extends State<AdminSongScreen> {
  late final SongService _songService;
  late final CategoryService _categoryService;
  late final NadaService _nadaService;

  List<SongModel> _allSongs = [];
  List<SongModel> _filteredSongs = [];
  List<CategoryModel> _categories = [];
  List<NadaModel> _nadas = [];
  int? _selectedCategoryFilter; // null = Semua
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _songService = widget.songService ?? ApiSongService();
    _categoryService = widget.categoryService ?? ApiCategoryService();
    _nadaService = widget.nadaService ?? ApiNadaService();
    _searchController.addListener(_filterSongs);
    _loadData();
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
    final cat = _categories.firstWhere(
      (c) => _parseCategoryId(c.id) == categoryId,
      orElse: () => CategoryModel(
        id: 'cat_$categoryId',
        name: 'Kategori #$categoryId',
        createdAt: DateTime.now(),
      ),
    );
    return cat.name;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    List<CategoryModel> categoriesList = _categories;
    List<SongModel> songsList = _allSongs;
    List<NadaModel> nadasList = _nadas;

    try {
      final results = await Future.wait([
        _categoryService.getCategories().catchError((e) {
          debugPrint('Error loading categories: $e');
          return <CategoryModel>[];
        }),
        _songService.getSongs().catchError((e) {
          debugPrint('Error loading songs: $e');
          return <SongModel>[];
        }),
        _nadaService.getNadas().catchError((e) {
          debugPrint('Error loading nadas: $e');
          return <NadaModel>[];
        }),
      ]);

      final fetchedCategories = results[0] as List<CategoryModel>;
      final fetchedSongs = results[1] as List<SongModel>;
      final fetchedNadas = results[2] as List<NadaModel>;

      if (fetchedCategories.isNotEmpty || _categories.isEmpty) {
        categoriesList = fetchedCategories;
      }
      if (fetchedSongs.isNotEmpty || _allSongs.isEmpty) {
        songsList = fetchedSongs;
      }
      if (fetchedNadas.isNotEmpty || _nadas.isEmpty) {
        nadasList = fetchedNadas;
      }
    } catch (e) {
      debugPrint('Error in _loadData: $e');
    }

    if (nadasList.isEmpty && _nadas.isEmpty) {
      nadasList = [
        NadaModel(id: 1, nada: 'Pria'),
        NadaModel(id: 2, nada: 'Wanita'),
      ];
    }

    if (mounted) {
      setState(() {
        _categories = categoriesList;
        _allSongs = songsList;
        _nadas = nadasList;
        _filterSongs();
        _isLoading = false;
      });
    }
  }

  void _filterSongs() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredSongs = _allSongs.where((song) {
        final matchQuery = query.isEmpty ||
            song.songtitle.toLowerCase().contains(query) ||
            song.songsinger.toLowerCase().contains(query);

        final matchCategory = _selectedCategoryFilter == null ||
            song.songcategory == _selectedCategoryFilter;

        return matchQuery && matchCategory;
      }).toList();
    });
  }

  Future<void> _openAddNadaDialog(
    BuildContext context,
    StateSetter setParentDialogState,
    void Function(String newNada) onNadaSelected,
  ) async {
    final nadaController = TextEditingController();
    final addFormKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setAddDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.cardGlassBorder, width: 1.2),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryElectric.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tambah Nada Baru',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              content: Form(
                key: addFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Nada *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nadaController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration(
                        hint: 'Misal: Pria, Wanita, C, D Minor, dll',
                        icon: Icons.tune_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nama nada wajib diisi';
                        }
                        return null;
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryElectric,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (addFormKey.currentState?.validate() != true) return;
                          setAddDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            final created = await _nadaService.createNada(nadaController.text.trim());
                            if (!mounted) return;

                            setState(() {
                              if (!_nadas.any((n) => n.id == created.id || n.nada.toLowerCase() == created.nada.toLowerCase())) {
                                _nadas.add(created);
                              }
                            });

                            onNadaSelected(created.nada);
                            setParentDialogState(() {});

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Nada "${created.nada}" berhasil ditambahkan'),
                                backgroundColor: AppColors.accentCyan,
                              ),
                            );
                          } catch (e) {
                            setAddDialogState(() {
                              isSaving = false;
                              errorMessage = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSongFormDialog({SongModel? song}) async {
    // Pastikan kategori telah termuat sebelum membuka dialog form
    if (_categories.isEmpty) {
      try {
        final cats = await _categoryService.getCategories();
        if (cats.isNotEmpty && mounted) {
          setState(() {
            _categories = cats;
          });
        }
      } catch (e) {
        debugPrint('Could not load categories prior to dialog: $e');
      }
    }

    // Pastikan nada telah termuat sebelum membuka dialog form
    if (_nadas.isEmpty) {
      try {
        final nads = await _nadaService.getNadas();
        if (nads.isNotEmpty && mounted) {
          setState(() {
            _nadas = nads;
          });
        }
      } catch (e) {
        debugPrint('Could not load nadas prior to dialog: $e');
      }
    }

    if (!mounted) return;

    final isEditing = song != null;
    final titleController = TextEditingController(text: song?.songtitle ?? '');
    final singerController = TextEditingController(text: song?.songsinger ?? '');
    final urlController = TextEditingController(text: song?.songurl ?? '');
    final durationController = TextEditingController(text: song?.songduration ?? '');
    
    // Ensure default category is valid
    int? selectedCategory = song?.songcategory;
    if (selectedCategory == null || !_categories.any((c) => _parseCategoryId(c.id) == selectedCategory)) {
      selectedCategory = _categories.isNotEmpty ? _parseCategoryId(_categories.first.id) : null;
    }
    
    // Initialize selectedNada from song, default to '-'
    String? selectedNada = song?.songnada?.trim();
    if (selectedNada == null || selectedNada.isEmpty) {
      selectedNada = '-';
    }

    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.cardGlassBorder, width: 1.2),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryElectric.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.library_add_rounded,
                      color: AppColors.accentCyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Ubah Lagu' : 'Tambah Lagu Baru',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                    tooltip: 'Tutup',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Judul Lagu
                          const Text(
                            'Judul Lagu *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: titleController,
                            autofocus: !isEditing,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration(
                              hint: 'Contoh: Sial, Rungkad, dll.',
                              icon: Icons.music_note_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Judul lagu wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Artis / Penyanyi
                          const Text(
                            'Artis / Penyanyi *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: singerController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration(
                              hint: 'Contoh: Mahalini, Dewa 19, dll.',
                              icon: Icons.person_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama penyanyi wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Kategori Lagu
                          const Text(
                            'Kategori Lagu *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: selectedCategory != null &&
                                    _categories.any((c) => _parseCategoryId(c.id) == selectedCategory)
                                ? selectedCategory
                                : (_categories.isNotEmpty
                                    ? _parseCategoryId(_categories.first.id)
                                    : null),
                            isExpanded: true,
                            dropdownColor: AppColors.surfaceDark,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.accentCyan,
                              size: 26,
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            hint: const Text(
                              'Pilih Kategori',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            decoration: _inputDecoration(
                              hint: 'Pilih Kategori',
                              icon: Icons.category_rounded,
                            ),
                            items: _categories.map((cat) {
                              final catId = _parseCategoryId(cat.id);
                              return DropdownMenuItem<int>(
                                value: catId,
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: _categories.isNotEmpty
                                ? (value) {
                                    if (value != null) {
                                      setDialogState(() {
                                        selectedCategory = value;
                                      });
                                    }
                                  }
                                : null,
                            validator: (value) {
                              if (value == null && _categories.isNotEmpty) {
                                return 'Pilih kategori lagu terlebih dahulu';
                              }
                              return null;
                            },
                          ),
                          if (_categories.isEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.warning,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Kategori belum termuat dari server.',
                                      style: TextStyle(
                                        color: AppColors.warning,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      try {
                                        final cats = await _categoryService.getCategories();
                                        if (cats.isNotEmpty && mounted) {
                                          setState(() => _categories = cats);
                                          setDialogState(() {
                                            selectedCategory = _parseCategoryId(cats.first.id);
                                          });
                                        }
                                      } catch (_) {}
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.refresh_rounded, size: 14, color: AppColors.accentCyan),
                                          SizedBox(width: 4),
                                          Text(
                                            'Muat Ulang',
                                            style: TextStyle(
                                              color: AppColors.accentCyan,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // URL Lagu / Media
                          const Text(
                            'URL Video YouTube / Lagu *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: urlController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration(
                              hint: 'Contoh: https://www.youtube.com/watch?v=... atau link YouTube',
                              icon: Icons.smart_display_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'URL video YouTube wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Nada Lagu Header dengan Tombol Tambah Nada
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Nada Lagu',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              InkWell(
                                onTap: () => _openAddNadaDialog(
                                  context,
                                  setDialogState,
                                  (newNada) {
                                    selectedNada = newNada;
                                  },
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, size: 16, color: AppColors.accentCyan),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tambah Nada',
                                        style: TextStyle(
                                          color: AppColors.accentCyan,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Dropdown Pilihan Nada Dinamis dari API
                          Builder(
                            builder: (context) {
                              final rawNadas = <NadaModel>[
                                const NadaModel(id: 0, nada: '-'),
                                ..._nadas,
                              ];
                              if (_nadas.isEmpty) {
                                rawNadas.addAll([
                                  const NadaModel(id: 1, nada: 'Pria'),
                                  const NadaModel(id: 2, nada: 'Wanita'),
                                ]);
                              }
                              // Sertakan selectedNada jika ada dan belum terdaftar di list
                              if (selectedNada != null &&
                                  selectedNada!.isNotEmpty &&
                                  !rawNadas.any((n) => n.nada.toLowerCase() == selectedNada!.toLowerCase())) {
                                rawNadas.add(NadaModel(id: 0, nada: selectedNada!));
                              }

                              // Deduplikasi berdasarkan string lowercase nada
                              final uniqueMap = <String, NadaModel>{};
                              for (final item in rawNadas) {
                                uniqueMap.putIfAbsent(item.nada.toLowerCase(), () => item);
                              }
                              final availableNadas = uniqueMap.values.toList();

                              // Tentukan value yang cocok secara case-insensitive
                              final matchingItem = selectedNada != null
                                  ? availableNadas.cast<NadaModel?>().firstWhere(
                                      (n) => n!.nada.toLowerCase() == selectedNada!.toLowerCase(),
                                      orElse: () => null,
                                    )
                                  : null;

                              return DropdownButtonFormField<String>(
                                key: const Key('nada_dropdown'),
                                initialValue: matchingItem?.nada ?? '-',
                                isExpanded: true,
                                dropdownColor: AppColors.surfaceDark,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.accentCyan,
                                  size: 26,
                                ),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                hint: const Text(
                                  'Pilih Nada Lagu',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                                decoration: _inputDecoration(
                                  hint: 'Pilih Nada Lagu',
                                  icon: Icons.tune_rounded,
                                ),
                                items: availableNadas.map((item) {
                                  final isDash = item.nada == '-';
                                  final isPria = item.nada.toLowerCase() == 'pria';
                                  final isWanita = item.nada.toLowerCase() == 'wanita';

                                  final icon = isDash
                                      ? Icons.horizontal_rule_rounded
                                      : isPria
                                          ? Icons.male_rounded
                                          : isWanita
                                              ? Icons.female_rounded
                                              : Icons.music_note_rounded;

                                  final iconColor = isDash
                                      ? AppColors.textMuted
                                      : isPria
                                          ? AppColors.primaryElectric
                                          : isWanita
                                              ? const Color(0xFFD81B60)
                                              : AppColors.accentCyan;

                                  final String label = isDash
                                      ? '-'
                                      : (isPria || isWanita)
                                          ? 'Nada ${item.nada}'
                                          : (item.nada.toLowerCase().startsWith('nada')
                                              ? item.nada
                                              : 'Nada ${item.nada}');

                                  return DropdownMenuItem<String>(
                                    value: item.nada,
                                    child: Row(
                                      children: [
                                        Icon(icon, size: 18, color: iconColor),
                                        const SizedBox(width: 10),
                                        Text(
                                          label,
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedNada = val;
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // Durasi Lagu (mm:ss)
                          const Text(
                            'Durasi Lagu (mm:ss)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: durationController,
                            maxLength: 5,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration(
                              hint: 'Contoh: 03:45',
                              icon: Icons.timer_outlined,
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value.trim())) {
                                  return 'Format: mm:ss';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            if (selectedCategory == null && _categories.isNotEmpty) {
                              selectedCategory = _parseCategoryId(_categories.first.id);
                            }
                            if (selectedCategory == null) {
                              _showSnackbar('Kategori lagu belum dipilih atau belum tersedia dari server', AppColors.error);
                              return;
                            }
                            setDialogState(() {
                              isSubmitting = true;
                            });
                            try {
                              if (isEditing) {
                                final updated = song.copyWith(
                                  songtitle: titleController.text.trim(),
                                  songsinger: singerController.text.trim(),
                                  songurl: urlController.text.trim(),
                                  songcategory: selectedCategory!,
                                  songnada: selectedNada?.trim().isNotEmpty == true ? selectedNada!.trim() : '-',
                                  songduration: durationController.text.trim().isNotEmpty ? durationController.text.trim() : null,
                                );
                                await _songService.updateSong(updated);
                              } else {
                                await _songService.createSong(
                                  songtitle: titleController.text.trim(),
                                  songsinger: singerController.text.trim(),
                                  songurl: urlController.text.trim(),
                                  songcategory: selectedCategory!,
                                  songnada: selectedNada?.trim().isNotEmpty == true ? selectedNada!.trim() : '-',
                                  songduration: durationController.text.trim().isNotEmpty ? durationController.text.trim() : null,
                                );
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setDialogState(() {
                                  isSubmitting = false;
                                });
                                final errText = e.toString().replaceAll('Exception: ', '');
                                _showSnackbar(errText, AppColors.error);
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryElectric,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Simpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _loadData();
      _showSnackbar(
        isEditing ? 'Lagu berhasil diperbarui' : 'Lagu berhasil ditambahkan',
        AppColors.primaryElectric,
      );
    }
  }

  Future<void> _showDeleteDialog(SongModel song) async {
    bool isDeleting = false;

    final deleted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.cardGlassBorder, width: 1.2),
            ),
            title: const Text(
              'Hapus Lagu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apakah Anda yakin ingin menghapus lagu "${song.songtitle}" oleh ${song.songsinger}?',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tindakan ini tidak dapat dibatalkan.',
                      style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Batal', style: TextStyle(color: AppColors.accentSky)),
              ),
              ElevatedButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() {
                          isDeleting = true;
                        });
                        try {
                          await _songService.deleteSong(song.songid);
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setDialogState(() {
                              isDeleting = false;
                            });
                            final errText = e.toString().replaceAll('Exception: ', '');
                            _showSnackbar(errText, AppColors.error);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (deleted == true) {
      await _loadData();
      _showSnackbar('Lagu berhasil dihapus', AppColors.error);
    }
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.accentSky, size: 18),
      filled: true,
      fillColor: AppColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputFocusedBorder, width: 1.5),
      ),
    );
  }

  void _showSnackbar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.accentCyan,
          backgroundColor: AppColors.surfaceDark,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul & Tombol Tambah
                      Row(
                        children: [
                          const Text(
                            'Kelola Lagu',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryElectric.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_allSongs.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentSky,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => _showSongFormDialog(),
                            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              'Tambah Lagu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryElectric,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Search Bar
                      SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Cari judul lagu atau nama penyanyi...',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 16),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.cardGlass,
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

                      const SizedBox(height: 12),

                      // Filter Kategori Chips
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
                                    _filterSongs();
                                  });
                                }
                              },
                              selectedColor: AppColors.primaryElectric,
                              backgroundColor: AppColors.cardGlass,
                              labelStyle: TextStyle(
                                fontSize: 12,
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
                            const SizedBox(width: 8),
                            ..._categories.map((cat) {
                              final catId = _parseCategoryId(cat.id);
                              final isSelected = _selectedCategoryFilter == catId;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(cat.name),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategoryFilter = selected ? catId : null;
                                      _filterSongs();
                                    });
                                  },
                                  selectedColor: AppColors.primaryElectric,
                                  backgroundColor: AppColors.cardGlass,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
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
              ),

              // Songs List
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    ),
                  ),
                )
              else if (_filteredSongs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_off_rounded,
                          size: 48,
                          color: AppColors.accentSky.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tidak ada lagu ditemukan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Coba kata kunci lain atau tambah lagu baru',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _filteredSongs[index];
                        final categoryName = _getCategoryName(
                          song.songcategory,
                          embeddedCategory: song.category,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardGlass,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.cardGlassBorder,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Song Leading Icon / Cover Thumbnail
                                SongCoverThumbnail(
                                  songUrl: song.songurl,
                                  width: 56,
                                  height: 38,
                                  borderRadius: 8,
                                  fallback: Container(
                                    width: 56,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.cardGradient,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        color: AppColors.accentCyan,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Song Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title & Singer
                                      Text(
                                        song.songtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
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
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.accentSky,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Badges: Category, Key/Nada, Duration
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          // Category Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryElectric.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppColors.accentCyan.withValues(alpha: 0.3),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              categoryName,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.accentLight,
                                              ),
                                            ),
                                          ),

                                          // Nada Badge (Pria / Wanita / Custom)
                                          if (song.songnada != null && song.songnada!.isNotEmpty && song.songnada != '-')
                                            Builder(
                                              builder: (context) {
                                                final isWanita = song.songnada!.toLowerCase() == 'wanita';
                                                final isPria = song.songnada!.toLowerCase() == 'pria';
                                                final Color badgeColor = isWanita
                                                    ? const Color(0xFFFF69B4)
                                                    : isPria
                                                        ? AppColors.accentNeon
                                                        : Colors.amberAccent;
                                                final IconData icon = isWanita
                                                    ? Icons.female_rounded
                                                    : isPria
                                                        ? Icons.male_rounded
                                                        : Icons.tune_rounded;

                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: badgeColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: badgeColor.withValues(alpha: 0.4),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(icon, size: 12, color: badgeColor),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Nada: ${song.songnada}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: badgeColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),

                                          // Duration Badge (if present)
                                          if (song.songduration != null && song.songduration!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.timer_outlined, size: 10, color: AppColors.textSecondary),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    song.songduration!,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Action Buttons
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.accentCyan,
                                    size: 20,
                                  ),
                                  tooltip: 'Ubah',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showSongFormDialog(song: song),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  tooltip: 'Hapus',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showDeleteDialog(song),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _filteredSongs.length,
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
