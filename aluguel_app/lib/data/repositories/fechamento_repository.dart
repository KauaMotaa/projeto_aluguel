import '../datasources/api_client.dart';
import '../models/previa.dart';

class FechamentoRepository {
  FechamentoRepository(this._api);

  final ApiClient _api;

  Future<Previa> previa({
    required int imovelId,
    required String competencia,
  }) async {
    final json = await _api
            .get('/imoveis/$imovelId/competencias/$competencia/previa')
        as Map<String, dynamic>;
    return Previa.fromJson(json);
  }

  Future<int> fechar({
    required int imovelId,
    required String competencia,
  }) async {
    final json = await _api
        .post('/imoveis/$imovelId/competencias/$competencia/fechar') as List;
    return json.length;
  }
}
