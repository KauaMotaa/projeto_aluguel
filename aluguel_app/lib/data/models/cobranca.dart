/// De onde sai a parcela de agua ou de energia de uma cobranca.
///
/// Fica guardado na cobranca, e nao recalculado na hora: a conta e
/// daquela competencia, e corrigir uma leitura em marco nao pode mudar o
/// que ja foi cobrado em janeiro.
class DetalheRateio {
  const DetalheRateio({
    required this.consumo,
    required this.rateioComum,
    required this.valorUnitario,
  });

  /// O que o submedidor da unidade marcou.
  final double consumo;

  /// A parte da area comum que coube a esta unidade.
  final double rateioComum;

  /// Centavos por m³ ou por kWh naquele mes.
  final double valorUnitario;

  double get consumoCobrado => consumo + rateioComum;

  factory DetalheRateio.fromJson(Map<String, dynamic> json) => DetalheRateio(
        consumo: (json['consumo'] as num).toDouble(),
        rateioComum: (json['rateio_comum'] as num).toDouble(),
        valorUnitario: (json['valor_unitario'] as num).toDouble(),
      );
}

/// O que o inquilino diz ter pago.
///
/// Nao e um pagamento: e um recado. Nao mexe no status da cobranca nem
/// entra em soma nenhuma — quem decide se o dinheiro entrou e o
/// proprietario. Serve para ele saber que ha algo a conferir, e para nao
/// ter de redigitar o que o outro lado ja informou.
class AvisoPagamento {
  const AvisoPagamento({
    required this.valor,
    required this.dataPagamento,
    required this.forma,
    required this.informadoEm,
  });

  final int valor;
  final String dataPagamento;
  final String forma;
  final String informadoEm;

  factory AvisoPagamento.fromJson(Map<String, dynamic> json) => AvisoPagamento(
        valor: json['valor'] as int,
        dataPagamento: json['data_pagamento'] as String,
        forma: json['forma'] as String,
        informadoEm: json['informado_em'] as String,
      );
}

class Cobranca {
  const Cobranca({
    required this.id,
    required this.contratoId,
    required this.unidadeId,
    required this.identificacao,
    required this.inquilino,
    required this.competencia,
    required this.valorAluguel,
    required this.valorAgua,
    required this.valorEnergia,
    required this.valorTotal,
    required this.status,
    required this.vencimento,
    this.detalheAgua,
    this.detalheEnergia,
    this.pagamentoInformado,
  });

  final int id;
  final int contratoId;
  final int unidadeId;
  final String identificacao;
  final String inquilino;
  final String competencia;
  final int valorAluguel;
  final int valorAgua;
  final int valorEnergia;
  final int valorTotal;
  final String status;
  final String vencimento;

  /// Nulos em cobranca gerada antes de a API passar a guardar a quebra.
  /// A tela mostra o detalhe quando existe e o total quando nao existe.
  final DetalheRateio? detalheAgua;
  final DetalheRateio? detalheEnergia;

  /// Presente quando o inquilino avisou que pagou e o proprietario ainda
  /// nao lancou. Some assim que ele lanca.
  final AvisoPagamento? pagamentoInformado;

  bool get paga => status == 'paga';
  bool get atrasada => status == 'atrasada';

  bool get temDetalhe => detalheAgua != null && detalheEnergia != null;
  bool get foiAvisada => pagamentoInformado != null;

  factory Cobranca.fromJson(Map<String, dynamic> json) => Cobranca(
        id: json['id'] as int,
        contratoId: json['contrato_id'] as int,
        unidadeId: json['unidade_id'] as int,
        identificacao: json['identificacao'] as String,
        inquilino: json['inquilino'] as String,
        competencia: json['competencia'] as String,
        valorAluguel: json['valor_aluguel'] as int,
        valorAgua: json['valor_agua'] as int,
        valorEnergia: json['valor_energia'] as int,
        valorTotal: json['valor_total'] as int,
        status: json['status'] as String,
        vencimento: json['vencimento'] as String,
        detalheAgua: json['detalhe_agua'] == null
            ? null
            : DetalheRateio.fromJson(
                json['detalhe_agua'] as Map<String, dynamic>),
        detalheEnergia: json['detalhe_energia'] == null
            ? null
            : DetalheRateio.fromJson(
                json['detalhe_energia'] as Map<String, dynamic>),
        pagamentoInformado: json['pagamento_informado'] == null
            ? null
            : AvisoPagamento.fromJson(
                json['pagamento_informado'] as Map<String, dynamic>),
      );
}
