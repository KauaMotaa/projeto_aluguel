/// Resposta do registro de pagamento.
///
/// O campo que a tela usa e [cobrancaStatus]: a API soma os pagamentos da
/// cobranca e so a marca como paga quando eles cobrem o total. Quem decide
/// o novo status e ela, nao o app — um pagamento parcial deixa a cobranca
/// aberta, e o app precisa saber disso para nao mentir no painel.
class Pagamento {
  const Pagamento({
    required this.id,
    required this.cobrancaId,
    required this.valor,
    required this.dataPagamento,
    required this.forma,
    required this.cobrancaStatus,
  });

  final int id;
  final int cobrancaId;
  final int valor;
  final String dataPagamento;
  final String forma;
  final String cobrancaStatus;

  bool get quitou => cobrancaStatus == 'paga';

  factory Pagamento.fromJson(Map<String, dynamic> json) => Pagamento(
        id: json['id'] as int,
        cobrancaId: json['cobranca_id'] as int,
        valor: json['valor'] as int,
        dataPagamento: json['data_pagamento'] as String,
        forma: json['forma'] as String,
        cobrancaStatus: json['cobranca_status'] as String,
      );
}
