import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';

/// Erro que a camada de dados devolve para cima.
///
/// A View nunca ve um SocketException ou um status 422: ve uma mensagem
/// pronta para mostrar.
class ApiException implements Exception {
  const ApiException(this.mensagem, {this.status});

  final String mensagem;

  /// Nulo quando a requisicao nem chegou a ter resposta.
  final int? status;

  /// Nao foi o servidor que recusou: foi a rede que nao deixou chegar.
  ///
  /// E a diferenca que separa "guarda no aparelho e tenta depois" de
  /// "corrige o que voce mandou": repetir um 422 mais tarde vai dar 422
  /// de novo, repetir uma falha de rede pode dar certo.
  bool get semRede => status == null;

  @override
  String toString() => mensagem;
}

/// Unica classe do app que conhece HTTP. Devolve JSON cru, sem regra.
class ApiClient {
  ApiClient({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;
  String? _token;

  void autenticar(String token) => _token = token;

  void sair() => _token = null;

  Map<String, String> get _cabecalhos => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _url(String caminho, [Map<String, dynamic>? query]) {
    final limpo = query?..removeWhere((_, v) => v == null);
    return Uri.parse('${ApiConfig.baseUrl}$caminho').replace(
      queryParameters: limpo?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Future<dynamic> get(String caminho, {Map<String, dynamic>? query}) async {
    return _executar(() => _cliente.get(_url(caminho, query), headers: _cabecalhos));
  }

  Future<dynamic> post(String caminho, {Object? corpo}) async {
    return _executar(() => _cliente.post(
          _url(caminho),
          headers: _cabecalhos,
          body: corpo == null ? null : jsonEncode(corpo),
        ));
  }

  Future<dynamic> _executar(Future<http.Response> Function() chamada) async {
    late http.Response resposta;
    try {
      resposta = await chamada().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException(
        'Nao consegui falar com o servidor. Confira se a API esta rodando '
        'e se o endereco em ApiConfig aponta para ela.',
      );
    }

    final corpo = resposta.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(resposta.bodyBytes));

    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return corpo;

    throw ApiException(_mensagemDeErro(corpo, resposta.statusCode),
        status: resposta.statusCode);
  }

  String _mensagemDeErro(dynamic corpo, int status) {
    if (corpo is Map && corpo['detail'] != null) {
      final detalhe = corpo['detail'];
      if (detalhe is String) return detalhe;
      if (detalhe is Map && detalhe['mensagem'] != null) {
        return detalhe['mensagem'] as String;
      }
      if (detalhe is List && detalhe.isNotEmpty) {
        final primeiro = detalhe.first;
        if (primeiro is Map && primeiro['msg'] != null) {
          return primeiro['msg'] as String;
        }
      }
    }
    if (status == 401) return 'Sessao expirada. Entre de novo.';
    return 'O servidor respondeu com erro $status.';
  }
}
