import '../datasources/api_client.dart';
import '../models/fatura.dart';

/// Faturas da concessionaria. Penduram no imovel, nao na unidade: cada
/// ponto tem a propria conta e o proprio consumo comum.
class FaturaRepository {
  FaturaRepository(this._api);

  final ApiClient _api;

  Future<List<Fatura>> listar({
    required int imovelId,
    required String competencia,
  }) async {
    final json = await _api.get('/imoveis/$imovelId/faturas', query: {
      'competencia': competencia,
    }) as List;
    return json
        .map((e) => Fatura.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> lancar({
    required int imovelId,
    required String competencia,
    required List<Map<String, dynamic>> faturas,
  }) async {
    await _api.post('/imoveis/$imovelId/faturas', corpo: {
      'competencia': competencia,
      'faturas': faturas,
    });
  }
}
