import 'dart:convert';
import 'dart:io';

import 'package:aluguel_app/data/datasources/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Resposta de erro da API de mentira.
class Falha {
  const Falha(this.status, this.detalhe);

  final int status;
  final Object detalhe;
}

/// A requisicao nem sai: e o celular sem sinal, nao o servidor recusando.
///
/// Vira uma [ApiException] sem status, que e como o [ApiClient] traduz
/// qualquer falha de transporte — e e por esse `status` nulo que o
/// repository sabe que vale guardar no aparelho e tentar depois.
class SemRede {
  const SemRede();
}

/// API de mentira para os testes.
///
/// Substitui o `http.Client` por dentro do [ApiClient] em vez de trocar o
/// repository por um dublê: assim o teste passa pela conversão de JSON e
/// pelo tratamento de erro de verdade, que é onde moram os enganos.
class ApiFalsa {
  ApiFalsa(this.rotas);

  /// `"GET /competencias"` para o corpo da resposta, ou uma [Falha].
  final Map<String, Object?> rotas;

  /// Tudo que o app pediu, na ordem. É o que permite afirmar que a
  /// competência certa foi parar na query string.
  final List<http.Request> chamadas = [];

  late final ApiClient cliente = ApiClient(cliente: MockClient(_responder));

  static String _chave(http.BaseRequest pedido) =>
      '${pedido.method} ${pedido.url.path.replaceFirst('/api/v1', '')}';

  Future<http.Response> _responder(http.Request pedido) async {
    chamadas.add(pedido);

    final resposta = rotas[_chave(pedido)];
    if (resposta is SemRede) {
      throw const SocketException('sem sinal');
    }
    if (resposta == null) {
      return _json({'detail': 'rota nao mapeada: ${_chave(pedido)}'}, 404);
    }
    if (resposta is Falha) {
      return _json({'detail': resposta.detalhe}, resposta.status);
    }
    return _json(resposta, 200);
  }

  static http.Response _json(Object? corpo, int status) => http.Response(
        jsonEncode(corpo),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// A primeira chamada feita para a rota, para conferir query e corpo.
  http.Request chamada(String chave) =>
      chamadas.firstWhere((pedido) => _chave(pedido) == chave);

  bool chamou(String chave) =>
      chamadas.any((pedido) => _chave(pedido) == chave);

  /// A ordem em que as rotas foram chamadas.
  List<String> get ordem => [for (final pedido in chamadas) _chave(pedido)];

  Map<String, dynamic> corpoDe(String chave) =>
      jsonDecode(chamada(chave).body) as Map<String, dynamic>;
}

// --- montadores de resposta, para os testes nao repetirem JSON ------------

Map<String, Object?> competenciaJson(
  String valor, {
  int cobrancas = 0,
  int imoveisFechados = 0,
  int imoveis = 2,
  bool atual = false,
}) =>
    {
      'competencia': valor,
      'cobrancas': cobrancas,
      'imoveis_fechados': imoveisFechados,
      'imoveis': imoveis,
      'atual': atual,
    };

Map<String, Object?> imovelJson(
  int id, {
  String nome = 'Palmeiras',
  String endereco = 'Rua das Palmeiras, 240',
  int unidades = 2,
  int unidadesOcupadas = 1,
}) =>
    {
      'id': id,
      'nome': nome,
      'endereco': endereco,
      'unidades': unidades,
      'unidades_ocupadas': unidadesOcupadas,
    };

Map<String, Object?> unidadeJson(
  int id, {
  int imovelId = 1,
  String identificacao = 'Kitnet 01',
  String status = 'ocupada',
  String? inquilino = 'Maria Souza',
  int? valorAluguel = 65000,
  String? cobrancaStatus,
  int? cobrancaTotal,
}) =>
    {
      'id': id,
      'imovel_id': imovelId,
      'identificacao': identificacao,
      'status': status,
      'inquilino': inquilino,
      'valor_aluguel': valorAluguel,
      'cobranca_status': cobrancaStatus,
      'cobranca_total': cobrancaTotal,
    };

Map<String, Object?> leituraJson(
  int unidadeId, {
  String identificacao = 'Kitnet 01',
  String tipo = 'energia',
  String competencia = '2026-11',
  double valorAnterior = 3180,
  double? valorAtual,
  double? mediaConsumo,
  int mesesHistorico = 0,
}) =>
    {
      'unidade_id': unidadeId,
      'identificacao': identificacao,
      'tipo': tipo,
      'competencia': competencia,
      'valor_anterior': valorAnterior,
      'valor_atual': valorAtual,
      'consumo': valorAtual == null ? null : valorAtual - valorAnterior,
      'media_consumo': mediaConsumo,
      'meses_historico': mesesHistorico,
    };

Map<String, Object?> cobrancaJson(
  int id, {
  int unidadeId = 1,
  int contratoId = 1,
  String identificacao = 'Kitnet 01',
  String inquilino = 'Maria Souza',
  String competencia = '2026-11',
  int aluguel = 65000,
  int agua = 12000,
  int energia = 23000,
  String status = 'aberta',
  String vencimento = '2026-11-10',
  Map<String, Object?>? detalheAgua,
  Map<String, Object?>? detalheEnergia,
}) =>
    {
      'id': id,
      'contrato_id': contratoId,
      'unidade_id': unidadeId,
      'identificacao': identificacao,
      'inquilino': inquilino,
      'competencia': competencia,
      'valor_aluguel': aluguel,
      'valor_agua': agua,
      'valor_energia': energia,
      'valor_total': aluguel + agua + energia,
      'status': status,
      'vencimento': vencimento,
      'detalhe_agua': detalheAgua,
      'detalhe_energia': detalheEnergia,
    };

/// A quebra de uma parcela: o que o submedidor marcou, a parte da area
/// comum, e o preco da unidade de consumo no mes.
Map<String, Object?> detalheJson({
  required double consumo,
  required double rateioComum,
  required double valorUnitario,
}) =>
    {
      'consumo': consumo,
      'rateio_comum': rateioComum,
      'valor_unitario': valorUnitario,
    };
