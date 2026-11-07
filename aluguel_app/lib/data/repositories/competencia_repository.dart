import '../datasources/api_client.dart';
import '../models/competencia.dart';

class CompetenciaRepository {
  CompetenciaRepository(this._api);

  final ApiClient _api;

  Future<List<Competencia>> listar() async {
    final json = await _api.get('/competencias') as List;
    return json
        .map((e) => Competencia.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
