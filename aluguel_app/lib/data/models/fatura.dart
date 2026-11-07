/// Fatura da concessionaria de um ponto, lancada ou ainda em branco.
///
/// A API devolve sempre os dois tipos, mesmo os nao lancados, com
/// `valorTotal` nulo. E o que permite a tela montar uma linha por medidor
/// e editar o que ja existe sem redigitar.
class Fatura {
  const Fatura({
    required this.imovelId,
    required this.competencia,
    required this.tipo,
    required this.consumoMedido,
    this.valorTotal,
    this.consumoTotal,
  });

  final int imovelId;
  final String competencia;
  final String tipo;

  /// Soma dos submedidores ja lidos na competencia. Serve de piso: o
  /// consumo do relogio geral nao pode ser menor que ele, senao a area
  /// comum fica negativa.
  final double consumoMedido;

  final int? valorTotal;
  final double? consumoTotal;

  bool get lancada => valorTotal != null && consumoTotal != null;

  factory Fatura.fromJson(Map<String, dynamic> json) => Fatura(
        imovelId: json['imovel_id'] as int,
        competencia: json['competencia'] as String,
        tipo: json['tipo'] as String,
        consumoMedido: (json['consumo_medido'] as num).toDouble(),
        valorTotal: json['valor_total'] as int?,
        consumoTotal: (json['consumo_total'] as num?)?.toDouble(),
      );
}
