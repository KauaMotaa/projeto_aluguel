import '../datasources/api_client.dart';
import '../datasources/leituras_locais.dart';
import '../models/leitura.dart';

/// O que a tela de leituras recebeu, e de onde veio.
///
/// A ViewModel precisa saber a origem: offline ela mostra a tarja e os
/// valores anteriores podem estar velhos, e isso tem de aparecer em vez
/// de passar por dado fresco.
class LeiturasDoMes {
  const LeiturasDoMes({
    required this.leituras,
    required this.doCache,
    required this.pendentes,
  });

  final List<Leitura> leituras;

  /// A API nao respondeu e estes dados sao o espelho da ultima visita.
  final bool doCache;

  /// Valores digitados que a API ainda nao aceitou, por `unidadeId:tipo`.
  final Map<String, double> pendentes;

  bool get temPendencia => pendentes.isNotEmpty;
}

/// Resultado de tentar lancar leituras.
class ResultadoLancamento {
  const ResultadoLancamento.gravado()
      : aceito = true,
        guardadoLocalmente = false,
        erro = null;

  const ResultadoLancamento.guardadoNoAparelho()
      : aceito = false,
        guardadoLocalmente = true,
        erro = null;

  const ResultadoLancamento.recusado(this.erro)
      : aceito = false,
        guardadoLocalmente = false;

  /// A API gravou.
  final bool aceito;

  /// A rede falhou e o valor ficou na fila do aparelho.
  final bool guardadoLocalmente;

  /// A API respondeu recusando (leitura menor que a anterior, por
  /// exemplo). Repetir depois daria o mesmo erro, entao nao vira fila.
  final String? erro;
}

/// Leituras, da API e do aparelho.
///
/// O repository e que decide entre as duas fontes — e o que mantem a
/// ViewModel sem saber que existe cache, do mesmo jeito que ela nao sabe
/// que existe HTTP.
class LeituraRepository {
  LeituraRepository(this._api, this._locais);

  final ApiClient _api;
  final LeiturasLocais _locais;

  Future<LeiturasDoMes> listar({
    required String competencia,
    required int imovelId,
  }) async {
    final pendentes = await _locais.pendencias(imovelId, competencia);

    try {
      final json = await _api.get('/leituras', query: {
        'competencia': competencia,
        'imovel_id': imovelId,
      }) as List;
      final linhas = [for (final e in json) e as Map<String, dynamic>];

      await _locais.guardarEspelho(imovelId, competencia, linhas);

      return LeiturasDoMes(
        leituras: [for (final l in linhas) Leitura.fromJson(l)],
        doCache: false,
        pendentes: pendentes,
      );
    } on ApiException catch (e) {
      // Erro de verdade do servidor (401, 422) sobe: nao e caso de cache.
      if (!e.semRede) rethrow;

      final espelho = await _locais.espelho(imovelId, competencia);
      if (espelho == null) rethrow; // offline e sem nada guardado

      return LeiturasDoMes(
        leituras: [for (final l in espelho) Leitura.fromJson(l)],
        doCache: true,
        pendentes: pendentes,
      );
    }
  }

  /// Manda as leituras. Sem rede, guarda no aparelho em vez de perder.
  Future<ResultadoLancamento> lancar({
    required String competencia,
    required int imovelId,
    required List<Map<String, dynamic>> leituras,
  }) async {
    try {
      await _api.post('/leituras', corpo: {
        'competencia': competencia,
        'leituras': leituras,
      });
      await _locais.limparPendencias(imovelId, competencia);
      return const ResultadoLancamento.gravado();
    } on ApiException catch (e) {
      if (!e.semRede) return ResultadoLancamento.recusado(e.mensagem);

      await _locais.guardarPendencias(imovelId, competencia, {
        for (final leitura in leituras)
          LeiturasLocais.chaveDe(
            leitura['unidade_id'] as int,
            leitura['tipo'] as String,
          ): (leitura['valor_atual'] as num).toDouble(),
      });
      return const ResultadoLancamento.guardadoNoAparelho();
    }
  }
}
