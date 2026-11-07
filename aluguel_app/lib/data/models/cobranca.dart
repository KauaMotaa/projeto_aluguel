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

  bool get paga => status == 'paga';
  bool get atrasada => status == 'atrasada';

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
      );
}
