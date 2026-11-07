import '../datasources/api_client.dart';
import '../models/cobranca.dart';
import '../models/consumo.dart';

/// Rotas do perfil inquilino. Sao duas, e as duas pendem do token: a API
/// resolve de quem sao as cobrancas pela sessao, nao por id na URL.
class InquilinoRepository {
  InquilinoRepository(this._api);

  final ApiClient _api;

  Future<List<Cobranca>> minhasCobrancas() async {
    final json = await _api.get('/minhas-cobrancas') as List;
    return json
        .map((e) => Cobranca.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Consumo>> meuConsumo() async {
    final json = await _api.get('/meu-consumo') as List;
    return json
        .map((e) => Consumo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
