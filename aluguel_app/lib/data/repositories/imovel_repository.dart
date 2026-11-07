import '../datasources/api_client.dart';
import '../models/imovel.dart';
import '../models/unidade.dart';

class ImovelRepository {
  ImovelRepository(this._api);

  final ApiClient _api;

  Future<List<Imovel>> listarImoveis() async {
    final json = await _api.get('/imoveis') as List;
    return json
        .map((e) => Imovel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Unidade>> listarUnidades({String? competencia}) async {
    final json = await _api.get('/unidades', query: {
      'competencia': competencia,
    }) as List;
    return json
        .map((e) => Unidade.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
