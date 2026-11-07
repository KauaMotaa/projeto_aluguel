import '../datasources/api_client.dart';
import '../models/cobranca.dart';
import '../models/pagamento.dart';

/// Cobrancas geradas pelo fechamento, na visao do proprietario.
class CobrancaRepository {
  CobrancaRepository(this._api);

  final ApiClient _api;

  Future<List<Cobranca>> listar({
    required String competencia,
    int? imovelId,
  }) async {
    final json = await _api.get('/cobrancas', query: {
      'competencia': competencia,
      'imovel_id': imovelId,
    }) as List;
    return json
        .map((e) => Cobranca.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Pagamento> registrarPagamento({
    required int cobrancaId,
    required int valor,
    required String dataPagamento,
    required String forma,
  }) async {
    final json = await _api.post(
      '/cobrancas/$cobrancaId/pagamento',
      corpo: {
        'valor': valor,
        'data_pagamento': dataPagamento,
        'forma': forma,
      },
    ) as Map<String, dynamic>;
    return Pagamento.fromJson(json);
  }
}
