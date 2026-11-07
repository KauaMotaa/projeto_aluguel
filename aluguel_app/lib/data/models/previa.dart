class ResumoTipo {
  const ResumoTipo({
    required this.valorTotalFatura,
    required this.valorUnitario,
    required this.consumoTotal,
    required this.consumoMedido,
    required this.consumoComum,
    required this.rateioComumPorUnidade,
  });

  final int valorTotalFatura;
  final double valorUnitario;
  final double consumoTotal;
  final double consumoMedido;
  final double consumoComum;
  final double rateioComumPorUnidade;

  factory ResumoTipo.fromJson(Map<String, dynamic> json) => ResumoTipo(
        valorTotalFatura: json['valor_total_fatura'] as int,
        valorUnitario: (json['valor_unitario'] as num).toDouble(),
        consumoTotal: (json['consumo_total'] as num).toDouble(),
        consumoMedido: (json['consumo_medido'] as num).toDouble(),
        consumoComum: (json['consumo_comum'] as num).toDouble(),
        rateioComumPorUnidade:
            (json['rateio_comum_por_unidade'] as num).toDouble(),
      );
}

class ParcelaConsumo {
  const ParcelaConsumo({
    required this.consumo,
    required this.rateioComum,
    required this.valor,
  });

  final double consumo;
  final double rateioComum;
  final int valor;

  factory ParcelaConsumo.fromJson(Map<String, dynamic> json) => ParcelaConsumo(
        consumo: (json['consumo'] as num).toDouble(),
        rateioComum: (json['rateio_comum'] as num).toDouble(),
        valor: json['valor'] as int,
      );
}

class LinhaPrevia {
  const LinhaPrevia({
    required this.unidadeId,
    required this.identificacao,
    required this.inquilino,
    required this.valorAluguel,
    required this.agua,
    required this.energia,
    required this.valorTotal,
  });

  final int unidadeId;
  final String identificacao;
  final String inquilino;
  final int valorAluguel;
  final ParcelaConsumo agua;
  final ParcelaConsumo energia;
  final int valorTotal;

  factory LinhaPrevia.fromJson(Map<String, dynamic> json) => LinhaPrevia(
        unidadeId: json['unidade_id'] as int,
        identificacao: json['identificacao'] as String,
        inquilino: json['inquilino'] as String,
        valorAluguel: json['valor_aluguel'] as int,
        agua: ParcelaConsumo.fromJson(json['agua'] as Map<String, dynamic>),
        energia:
            ParcelaConsumo.fromJson(json['energia'] as Map<String, dynamic>),
        valorTotal: json['valor_total'] as int,
      );
}

class Alerta {
  const Alerta({required this.codigo, required this.mensagem, this.unidadeId});

  final String codigo;
  final String mensagem;
  final int? unidadeId;

  factory Alerta.fromJson(Map<String, dynamic> json) => Alerta(
        codigo: json['codigo'] as String,
        mensagem: json['mensagem'] as String,
        unidadeId: json['unidade_id'] as int?,
      );
}

class Previa {
  const Previa({
    required this.imovelId,
    required this.competencia,
    required this.unidades,
    required this.totalGeral,
    required this.alertas,
    required this.podeFechar,
    this.agua,
    this.energia,
  });

  final int imovelId;
  final String competencia;
  final List<LinhaPrevia> unidades;
  final int totalGeral;
  final List<Alerta> alertas;
  final bool podeFechar;
  final ResumoTipo? agua;
  final ResumoTipo? energia;

  factory Previa.fromJson(Map<String, dynamic> json) => Previa(
        imovelId: json['imovel_id'] as int,
        competencia: json['competencia'] as String,
        agua: json['agua'] == null
            ? null
            : ResumoTipo.fromJson(json['agua'] as Map<String, dynamic>),
        energia: json['energia'] == null
            ? null
            : ResumoTipo.fromJson(json['energia'] as Map<String, dynamic>),
        unidades: (json['unidades'] as List)
            .map((e) => LinhaPrevia.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalGeral: json['total_geral'] as int,
        alertas: (json['alertas'] as List)
            .map((e) => Alerta.fromJson(e as Map<String, dynamic>))
            .toList(),
        podeFechar: json['pode_fechar'] as bool,
      );
}
