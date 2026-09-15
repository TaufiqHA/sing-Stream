import '../../models/nada_model.dart';
import 'nada_service.dart';

class DummyNadaService implements NadaService {
  final List<NadaModel> _nadas;

  DummyNadaService({List<NadaModel>? initialNadas})
      : _nadas = initialNadas ??
            [
              NadaModel(
                id: 1,
                nada: 'Pria',
                createdAt: DateTime.now().subtract(const Duration(days: 10)),
              ),
              NadaModel(
                id: 2,
                nada: 'Wanita',
                createdAt: DateTime.now().subtract(const Duration(days: 9)),
              ),
            ];

  @override
  Future<List<NadaModel>> getNadas({String? search}) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      return _nadas.where((n) => n.nada.toLowerCase().contains(query)).toList();
    }
    return List.from(_nadas);
  }

  @override
  Future<NadaModel> getNada(int id) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final item = _nadas.firstWhere(
      (n) => n.id == id,
      orElse: () => throw Exception('Nada tidak ditemukan.'),
    );
    return item;
  }

  @override
  Future<NadaModel> createNada(String nada) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final trimmed = nada.trim();
    if (trimmed.isEmpty) {
      throw Exception('Nama nada wajib diisi.');
    }
    if (_nadas.any((n) => n.nada.toLowerCase() == trimmed.toLowerCase())) {
      throw Exception('Nama nada sudah terdaftar.');
    }
    final nextId = _nadas.isEmpty
        ? 1
        : (_nadas.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);

    final newNada = NadaModel(
      id: nextId,
      nada: trimmed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _nadas.add(newNada);
    return newNada;
  }

  @override
  Future<NadaModel> updateNada(int id, String newNada) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final trimmed = newNada.trim();
    if (trimmed.isEmpty) {
      throw Exception('Nama nada wajib diisi.');
    }
    final index = _nadas.indexWhere((n) => n.id == id);
    if (index == -1) {
      throw Exception('Nada tidak ditemukan.');
    }
    if (_nadas.any((n) => n.id != id && n.nada.toLowerCase() == trimmed.toLowerCase())) {
      throw Exception('Nama nada sudah terdaftar.');
    }
    final updated = _nadas[index].copyWith(
      nada: trimmed,
      updatedAt: DateTime.now(),
    );
    _nadas[index] = updated;
    return updated;
  }

  @override
  Future<bool> deleteNada(int id) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final index = _nadas.indexWhere((n) => n.id == id);
    if (index == -1) {
      throw Exception('Nada tidak ditemukan.');
    }
    _nadas.removeAt(index);
    return true;
  }
}
