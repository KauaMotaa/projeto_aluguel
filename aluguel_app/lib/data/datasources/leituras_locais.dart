import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Leituras guardadas no proprio aparelho.
///
/// Ler submedidor e descer na garagem, no corredor dos fundos, no quadro
/// de luz — lugares onde nao ha sinal. Sem isto o dono anota no papel e
/// digita em casa, e o app vira uma planilha mais bonita.
///
/// Guarda duas coisas por ponto e competencia:
///
///  - **o espelho** do que a API respondeu da ultima vez, para a tela
///    abrir offline com as unidades, as leituras anteriores e as medias;
///  - **as pendencias**, que sao os valores digitados que a API ainda nao
///    aceitou.
///
/// Usa `SharedPreferences` porque o volume e pequeno e o formato e
/// estavel: sao dezenas de numeros por mes, nao um banco.
class LeiturasLocais {
  LeiturasLocais({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  static String _chaveEspelho(int imovelId, String competencia) =>
      'leituras:$imovelId:$competencia';

  static String _chavePendencias(int imovelId, String competencia) =>
      'pendentes:$imovelId:$competencia';

  /// Identifica uma pendencia. Medidor de agua e de energia da mesma
  /// unidade sao lancamentos separados e podem falhar separados.
  static String chaveDe(int unidadeId, String tipo) => '$unidadeId:$tipo';

  // --- espelho da ultima resposta da API ---------------------------------

  Future<void> guardarEspelho(
    int imovelId,
    String competencia,
    List<Map<String, dynamic>> linhas,
  ) async {
    final store = await _store;
    await store.setString(
      _chaveEspelho(imovelId, competencia),
      jsonEncode(linhas),
    );
  }

  /// O que a API respondeu da ultima vez, ou `null` se esta tela nunca
  /// abriu com rede neste aparelho.
  Future<List<Map<String, dynamic>>?> espelho(
    int imovelId,
    String competencia,
  ) async {
    final store = await _store;
    final bruto = store.getString(_chaveEspelho(imovelId, competencia));
    if (bruto == null) return null;

    final lista = jsonDecode(bruto) as List;
    return [for (final linha in lista) linha as Map<String, dynamic>];
  }

  // --- pendencias --------------------------------------------------------

  /// Valores digitados esperando a rede, por `unidadeId:tipo`.
  Future<Map<String, double>> pendencias(
    int imovelId,
    String competencia,
  ) async {
    final store = await _store;
    final bruto = store.getString(_chavePendencias(imovelId, competencia));
    if (bruto == null) return {};

    final mapa = jsonDecode(bruto) as Map<String, dynamic>;
    return mapa.map((chave, valor) => MapEntry(chave, (valor as num).toDouble()));
  }

  /// Guarda o que acabou de ser digitado, por cima do que ja houvesse.
  ///
  /// Por cima, e nao somando: relancar a leitura de uma unidade corrige a
  /// anterior, e a pendencia tem de refletir o ultimo valor digitado.
  Future<void> guardarPendencias(
    int imovelId,
    String competencia,
    Map<String, double> novas,
  ) async {
    final store = await _store;
    final atuais = await pendencias(imovelId, competencia);
    atuais.addAll(novas);
    await store.setString(
      _chavePendencias(imovelId, competencia),
      jsonEncode(atuais),
    );
  }

  Future<void> limparPendencias(int imovelId, String competencia) async {
    final store = await _store;
    await store.remove(_chavePendencias(imovelId, competencia));
  }
}
