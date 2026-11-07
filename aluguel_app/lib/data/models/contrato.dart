class Contrato {
  const Contrato({
    required this.id,
    required this.unidadeId,
    required this.inquilinoId,
    required this.inquilino,
    required this.valorAluguel,
    required this.diaVencimento,
    required this.dataInicio,
    required this.ativo,
  });

  final int id;
  final int unidadeId;
  final int inquilinoId;
  final String inquilino;
  final int valorAluguel;
  final int diaVencimento;
  final String dataInicio;
  final bool ativo;

  factory Contrato.fromJson(Map<String, dynamic> json) => Contrato(
        id: json['id'] as int,
        unidadeId: json['unidade_id'] as int,
        inquilinoId: json['inquilino_id'] as int,
        inquilino: json['inquilino'] as String,
        valorAluguel: json['valor_aluguel'] as int,
        diaVencimento: json['dia_vencimento'] as int,
        dataInicio: json['data_inicio'] as String,
        ativo: json['ativo'] as bool,
      );
}
