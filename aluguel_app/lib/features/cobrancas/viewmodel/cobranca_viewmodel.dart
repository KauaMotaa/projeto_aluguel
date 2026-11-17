import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/texto_cobranca.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/cobranca.dart';
import '../../../data/models/pagamento.dart';
import '../../../data/repositories/cobranca_repository.dart';

/// Uma cobranca aberta a partir do painel: o que se pode fazer com ela.
///
/// Sao duas coisas. **Compartilhar** manda a quebra para o inquilino pelo
/// app que ele ja usa — sem isso o calculo so existe para quem instalou
/// este aqui, e inquilino de kitnet nao instala. **Registrar o pagamento**
/// fecha o ciclo do lado do dono.
///
/// No pagamento, o valor comeca preenchido com o total, que e o caso
/// normal, mas fica editavel: a API aceita pagamento parcial e soma os
/// lancamentos, so marcando a cobranca como paga quando eles cobrem o
/// total. Esconder isso num botao de "marcar como paga" jogaria fora
/// metade do que a rota faz.
class CobrancaViewModel extends ChangeNotifier {
  CobrancaViewModel(this._repo, {required this.cobranca, DateTime? hoje})
      : _hoje = hoje ?? DateTime.now() {
    // Se o inquilino avisou, o formulario abre com o que ele informou.
    // Conferir um numero ja preenchido e mais rapido, e menos sujeito a
    // engano, do que digitar de novo o que o outro lado ja disse.
    final aviso = cobranca.pagamentoInformado;
    controllerValor.text =
        Formatters.valor(aviso?.valor ?? cobranca.valorTotal);
    if (aviso != null) _forma = aviso.forma;
  }

  final CobrancaRepository _repo;
  final Cobranca cobranca;
  final DateTime _hoje;

  final TextEditingController controllerValor = TextEditingController();

  /// As formas que a API aceita. Mora no Model porque o aviso que o
  /// inquilino manda usa a mesma lista.
  static const Map<String, String> formas = formasDePagamento;

  String _forma = 'pix';
  bool _salvando = false;
  String? _erro;
  String? _erroValor;
  Pagamento? _pagamento;

  String get forma => _forma;
  bool get salvando => _salvando;
  String? get erro => _erro;
  String? get erroValor => _erroValor;
  Pagamento? get pagamento => _pagamento;

  int? get centavos => Formatters.centavos(controllerValor.text);

  /// Cobranca ja quitada nao tem o que receber: a folha mostra so a
  /// quebra e o botao de compartilhar.
  bool get quitada => cobranca.paga;

  String get titulo => '${cobranca.identificacao}  ·  ${cobranca.inquilino}';

  /// O recado do inquilino, quando ele avisou que pagou.
  ///
  /// Nao e pagamento: e o que ele diz ter feito. O proprietario confere e
  /// lanca, ou corrige o valor antes de lancar — e so o lancamento dele
  /// que muda o status.
  String? get avisoDoInquilino {
    final aviso = cobranca.pagamentoInformado;
    if (aviso == null) return null;

    final rotulo = formas[aviso.forma] ?? aviso.forma;
    return '${cobranca.inquilino} informou ${Formatters.moeda(aviso.valor)} '
        'por $rotulo em ${Formatters.data(aviso.dataPagamento)}.';
  }
  String get aluguelFormatado => Formatters.moeda(cobranca.valorAluguel);
  String get aguaFormatada => Formatters.moeda(cobranca.valorAgua);
  String get energiaFormatada => Formatters.moeda(cobranca.valorEnergia);
  String get totalFormatado => Formatters.moeda(cobranca.valorTotal);
  String get vencimentoFormatado => Formatters.data(cobranca.vencimento);
  String get competenciaFormatada =>
      Formatters.competencia(cobranca.competencia);

  /// Data do lancamento: hoje. Nao ha seletor porque o registro acontece
  /// na hora em que o dinheiro entra.
  String get dataIso => '${_hoje.year.toString().padLeft(4, '0')}-'
      '${_hoje.month.toString().padLeft(2, '0')}-'
      '${_hoje.day.toString().padLeft(2, '0')}';

  String get dataFormatada => Formatters.data(dataIso);

  bool get podeSalvar =>
      !_salvando && _erroValor == null && (centavos ?? 0) > 0;

  /// Aviso de valor diferente do total. Diz o que vai acontecer com a
  /// cobranca, que e a duvida de quem esta digitando: abaixo do total ela
  /// continua aberta, e a API nao devolve isso como erro.
  String? get avisoValor {
    final valor = centavos;
    if (valor == null || _erroValor != null) return null;
    final diferenca = cobranca.valorTotal - valor;
    if (diferenca > 0) {
      return 'Pagamento parcial: a cobranca fica aberta por '
          '${Formatters.moeda(diferenca)}';
    }
    if (diferenca < 0) {
      return 'Acima do total em ${Formatters.moeda(-diferenca)}. '
          'A cobranca sera quitada.';
    }
    return null;
  }

  void escolherForma(String chave) {
    if (!formas.containsKey(chave) || chave == _forma) return;
    _forma = chave;
    notifyListeners();
  }

  void validar() {
    final texto = controllerValor.text.trim();
    if (texto.isEmpty) {
      _erroValor = 'Informe o valor recebido';
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
      _pagamento = await _repo.registrarPagamento(
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

  // --- o texto que vai para o inquilino ----------------------------------

  /// Assunto, para os destinos que tem um (e-mail, por exemplo).
  String get assuntoParaCompartilhar => TextoCobranca.assunto(cobranca);

  /// A cobranca em texto, para o menu de compartilhar do sistema. O
  /// inquilino manda exatamente o mesmo, do lado dele.
  String get textoParaCompartilhar => TextoCobranca.corpo(cobranca);

  /// Mensagem de confirmacao, depois de salvar. Quem decide se quitou e a
  /// API: ela soma os pagamentos anteriores, que o app nao conhece.
  String get confirmacao {
    final pago = _pagamento;
    if (pago == null) return 'Pagamento registrado';
    if (pago.quitou) {
      return '${cobranca.identificacao}: cobranca quitada';
    }
    return '${cobranca.identificacao}: ${Formatters.moeda(pago.valor)} '
        'registrado, cobranca segue aberta';
  }

  @override
  void dispose() {
    controllerValor.dispose();
    super.dispose();
  }
}
