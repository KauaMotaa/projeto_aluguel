import '../datasources/api_client.dart';
import '../models/contrato.dart';
import '../models/inquilino.dart';
import '../models/unidade.dart';

/// Lado de escrita do cadastro: criar unidade, inquilino e contrato.
///
/// Fica separado do [ImovelRepository], que so le, porque sao usos
/// diferentes: o painel consulta o tempo todo, e o cadastro grava uma vez
/// e sai da tela. Juntar os dois daria um repository que quase toda tela
/// importa inteiro para usar um metodo.
class CadastroRepository {
  CadastroRepository(this._api);

  final ApiClient _api;

  Future<Unidade> criarUnidade({
    required int imovelId,
    required String identificacao,
  }) async {
    final json = await _api.post('/unidades', corpo: {
      'imovel_id': imovelId,
      'identificacao': identificacao,
    }) as Map<String, dynamic>;
    return Unidade.fromJson(json);
  }

  Future<List<Inquilino>> listarInquilinos() async {
    final json = await _api.get('/inquilinos') as List;
    return json
        .map((e) => Inquilino.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Inquilino> criarInquilino({
    required String nome,
    required String telefone,
  }) async {
    final json = await _api.post('/inquilinos', corpo: {
      'nome': nome,
      'telefone': telefone,
    }) as Map<String, dynamic>;
    return Inquilino.fromJson(json);
  }

  Future<Contrato> criarContrato({
    required int unidadeId,
    required int inquilinoId,
    required int valorAluguel,
    required int diaVencimento,
    required String dataInicio,
  }) async {
    final json = await _api.post('/contratos', corpo: {
      'unidade_id': unidadeId,
      'inquilino_id': inquilinoId,
      'valor_aluguel': valorAluguel,
      'dia_vencimento': diaVencimento,
      'data_inicio': dataInicio,
    }) as Map<String, dynamic>;
    return Contrato.fromJson(json);
  }
}
