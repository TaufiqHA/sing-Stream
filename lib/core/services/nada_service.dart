import '../../models/nada_model.dart';

abstract class NadaService {
  Future<List<NadaModel>> getNadas({String? search});
  Future<NadaModel> getNada(int id);
  Future<NadaModel> createNada(String nada);
  Future<NadaModel> updateNada(int id, String newNada);
  Future<bool> deleteNada(int id);
}
