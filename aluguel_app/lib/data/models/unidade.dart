class Unidade {
  const Unidade({
    required this.id,
    required this.imovelId,
    required this.identificacao,
    required this.status,
    this.inquilino,
    this.valorAluguel,
    this.cobrancaStatus,
    this.cobrancaTotal,
  });

  final int id;
  final int imovelId;
  final String identificacao;
  final String status;
  final String? inquilino;
  final int? valorAluguel;
  final String? cobrancaStatus;
  final int? cobrancaTotal;

  bool get ocupada => status == 'ocupada';

  factory Unidade.fromJson(Map<String, dynamic> json) => Unidade(
        id: json['id'] as int,
        imovelId: json['imovel_id'] as int,
        identificacao: json['identificacao'] as String,
        status: json['status'] as String,
        inquilino: json['inquilino'] as String?,
        valorAluguel: json['valor_aluguel'] as int?,
        cobrancaStatus: json['cobranca_status'] as String?,
        cobrancaTotal: json['cobranca_total'] as int?,
      );
}
