class Leitura {
  const Leitura({
    required this.unidadeId,
    required this.identificacao,
    required this.tipo,
    required this.competencia,
    required this.valorAnterior,
    this.valorAtual,
    this.consumo,
  });

  final int unidadeId;
  final String identificacao;
  final String tipo;
  final String competencia;
  final double valorAnterior;
  final double? valorAtual;
  final double? consumo;

  factory Leitura.fromJson(Map<String, dynamic> json) => Leitura(
        unidadeId: json['unidade_id'] as int,
        identificacao: json['identificacao'] as String,
        tipo: json['tipo'] as String,
        competencia: json['competencia'] as String,
        valorAnterior: (json['valor_anterior'] as num).toDouble(),
        valorAtual: (json['valor_atual'] as num?)?.toDouble(),
        consumo: (json['consumo'] as num?)?.toDouble(),
      );
}
