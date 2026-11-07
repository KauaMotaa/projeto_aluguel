import '../datasources/api_client.dart';
import '../models/leitura.dart';

class LeituraRepository {
  LeituraRepository(this._api);

  final ApiClient _api;

  Future<List<Leitura>> listar({
    required String competencia,
    int? imovelId,
  }) async {
    final json = await _api.get('/leituras', query: {
      'competencia': competencia,
      'imovel_id': imovelId,
    }) as List;
    return json
        .map((e) => Leitura.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> lancar({
    required String competencia,
    required List<Map<String, dynamic>> leituras,
  }) async {
    await _api.post('/leituras', corpo: {
      'competencia': competencia,
      'leituras': leituras,
    });
  }
}
