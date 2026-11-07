/// Consumo de uma competencia, por tipo de medidor.
///
/// Os dois campos sao opcionais porque o mes em andamento pode ter apenas
/// um dos medidores lancado.
class PontoConsumo {
  const PontoConsumo({
    required this.competencia,
    this.agua,
    this.energia,
  });

  final String competencia;
  final double? agua;
  final double? energia;

  factory PontoConsumo.fromJson(Map<String, dynamic> json) => PontoConsumo(
        competencia: json['competencia'] as String,
        agua: (json['agua'] as num?)?.toDouble(),
        energia: (json['energia'] as num?)?.toDouble(),
      );
}

/// Historico de consumo de uma unidade, do mes mais antigo para o mais novo.
class Consumo {
  const Consumo({
    required this.unidadeId,
    required this.identificacao,
    required this.historico,
  });

  final int unidadeId;
  final String identificacao;
  final List<PontoConsumo> historico;

  factory Consumo.fromJson(Map<String, dynamic> json) => Consumo(
        unidadeId: json['unidade_id'] as int,
        identificacao: json['identificacao'] as String,
        historico: (json['historico'] as List)
            .map((e) => PontoConsumo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
