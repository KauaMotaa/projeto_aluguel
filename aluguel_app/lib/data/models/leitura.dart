class Leitura {
  const Leitura({
    required this.unidadeId,
    required this.identificacao,
    required this.tipo,
    required this.competencia,
    required this.valorAnterior,
    this.valorAtual,
    this.consumo,
    this.mediaConsumo,
    this.mesesHistorico = 0,
  });

  final int unidadeId;
  final String identificacao;
  final String tipo;
  final String competencia;
  final double valorAnterior;
  final double? valorAtual;
  final double? consumo;

  /// Media do que este medidor consumiu nas competencias ja fechadas.
  /// Vem da API, que e quem tem o historico.
  final double? mediaConsumo;

  /// De quantos meses a media saiu. Com menos de dois ela nao e media de
  /// nada, e avisar sobre ela seria falso alarme.
  final int mesesHistorico;

  /// So da para falar em consumo fora do padrao quando existe padrao.
  bool get temPadrao =>
      mesesHistorico >= 2 && mediaConsumo != null && mediaConsumo! > 0;

  factory Leitura.fromJson(Map<String, dynamic> json) => Leitura(
        unidadeId: json['unidade_id'] as int,
        identificacao: json['identificacao'] as String,
        tipo: json['tipo'] as String,
        competencia: json['competencia'] as String,
        valorAnterior: (json['valor_anterior'] as num).toDouble(),
        valorAtual: (json['valor_atual'] as num?)?.toDouble(),
        consumo: (json['consumo'] as num?)?.toDouble(),
        mediaConsumo: (json['media_consumo'] as num?)?.toDouble(),
        mesesHistorico: (json['meses_historico'] as int?) ?? 0,
      );
}
