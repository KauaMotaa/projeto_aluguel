import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/cobranca.dart';
import '../../../data/models/pagamento.dart';
import '../../../data/repositories/inquilino_repository.dart';

/// O inquilino avisando que pagou.
///
/// Substitui o "ja te mandei o pix" que hoje acontece por fora do app.
/// Nao muda o status da cobranca de proposito: quem sabe se o dinheiro
/// entrou e o proprietario, e e o lancamento dele que vale. O aviso so
/// acende a etiqueta do lado de la e poupa a digitacao.
///
/// Deixar o inquilino mudar o status sozinho seria pior do que nao ter o
/// recurso: a cobranca apareceria paga para os dois sem ninguem ter
/// conferido nada.
class AvisoPagamentoViewModel extends ChangeNotifier {
  AvisoPagamentoViewModel(
    this._repo, {
    required this.cobranca,
    DateTime? hoje,
  }) : _hoje = hoje ?? DateTime.now() {
    final anterior = cobranca.pagamentoInformado;
    controllerValor.text =
        Formatters.valor(anterior?.valor ?? cobranca.valorTotal);
    _forma = anterior?.forma ?? 'pix';
    _data = anterior == null
        ? _hoje
        : DateTime.tryParse(anterior.dataPagamento) ?? _hoje;
  }

  final InquilinoRepository _repo;
  final Cobranca cobranca;
  final DateTime _hoje;

  final TextEditingController controllerValor = TextEditingController();

  static const Map<String, String> formas = formasDePagamento;

  late String _forma;
  late DateTime _data;
  bool _salvando = false;
  String? _erro;
  String? _erroValor;
  Cobranca? _enviado;

  String get forma => _forma;
  DateTime get data => _data;
  bool get salvando => _salvando;
  String? get erro => _erro;
  String? get erroValor => _erroValor;
  Cobranca? get enviado => _enviado;

  /// Ja havia um aviso: isto aqui e uma correcao dele, nao um aviso novo.
  bool get corrigindo => cobranca.foiAvisada;

  String get titulo => corrigindo ? 'Corrigir o aviso' : 'Avisar que paguei';
  String get subtitulo =>
      '${cobranca.identificacao}  ·  ${Formatters.competencia(cobranca.competencia)}';

  String get totalFormatado => Formatters.moeda(cobranca.valorTotal);
  String get dataFormatada => Formatters.data(dataIso);

  String get dataIso => '${_data.year.toString().padLeft(4, '0')}-'
      '${_data.month.toString().padLeft(2, '0')}-'
      '${_data.day.toString().padLeft(2, '0')}';

  int? get centavos => Formatters.centavos(controllerValor.text);

  /// O limite do seletor de data. Nao da para ter pago amanha.
  DateTime get ultimoDiaValido => _hoje;

  bool get podeSalvar =>
      !_salvando && _erroValor == null && (centavos ?? 0) > 0;

  /// Aviso de valor diferente do cobrado. Nao trava: pagamento parcial
  /// acontece, e combinado entre as duas partes. Mas vale dizer, porque
  /// na maioria das vezes e engano de digitacao.
  String? get avisoValor {
    final valor = centavos;
    if (valor == null || _erroValor != null) return null;

    final diferenca = cobranca.valorTotal - valor;
    if (diferenca > 0) {
      return 'Faltam ${Formatters.moeda(diferenca)} para o total de '
          '$totalFormatado.';
    }
    if (diferenca < 0) {
      return '${Formatters.moeda(-diferenca)} acima do total de '
          '$totalFormatado.';
    }
    return null;
  }

  void escolherForma(String chave) {
    if (!formas.containsKey(chave) || chave == _forma) return;
    _forma = chave;
    notifyListeners();
  }

  void escolherData(DateTime data) {
    _data = data;
    notifyListeners();
  }

  void validar() {
    final texto = controllerValor.text.trim();
    if (texto.isEmpty) {
      _erroValor = 'Informe quanto voce pagou';
    } else {
      final valor = centavos;
      if (valor == null) {
        _erroValor = 'Valor invalido';
      } else if (valor <= 0) {
        _erroValor = 'Precisa ser maior que zero';
      } else {
        _erroValor = null;
      }
    }
    notifyListeners();
  }

  Future<bool> salvar() async {
    validar();
    if (!podeSalvar) return false;

    _salvando = true;
    _erro = null;
    notifyListeners();

    try {
      _enviado = await _repo.avisarPagamento(
        cobrancaId: cobranca.id,
        valor: centavos!,
        dataPagamento: dataIso,
        forma: _forma,
      );
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      return false;
    } finally {
      _salvando = false;
      notifyListeners();
    }
  }

  /// Mensagem de volta. Diz o que vai acontecer agora, que e a duvida de
  /// quem acabou de avisar: nada muda ate o proprietario conferir.
  String get confirmacao => corrigindo
      ? 'Aviso corrigido. O proprietario vai conferir.'
      : 'Aviso enviado. A cobranca segue em aberto ate o proprietario '
          'confirmar o recebimento.';

  @override
  void dispose() {
    controllerValor.dispose();
    super.dispose();
  }
}
