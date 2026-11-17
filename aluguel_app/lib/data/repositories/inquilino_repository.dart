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

  /// Avisa o proprietario de que esta cobranca foi paga.
  ///
  /// Nao muda o status: devolve a cobranca com o recado anexado. Quem
  /// confirma o recebimento e o proprietario, pela rota dele.
  Future<Cobranca> avisarPagamento({
    required int cobrancaId,
    required int valor,
    required String dataPagamento,
    required String forma,
  }) async {
    final json = await _api.post(
      '/minhas-cobrancas/$cobrancaId/aviso-pagamento',
      corpo: {
        'valor': valor,
        'data_pagamento': dataPagamento,
        'forma': forma,
      },
    ) as Map<String, dynamic>;
    return Cobranca.fromJson(json);
  }

  Future<List<Consumo>> meuConsumo() async {
    final json = await _api.get('/meu-consumo') as List;
    return json
        .map((e) => Consumo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
