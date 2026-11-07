/// Um mes que o seletor do painel oferece.
///
/// O fechamento acontece por ponto, nao por mes: novembro pode estar
/// fechado na Rua das Palmeiras e aberto na 104 Sul. Por isso o modelo
/// guarda a contagem de pontos fechados em vez de um `fechada` booleano,
/// que mentiria no caso parcial.
class Competencia {
  const Competencia({
    required this.valor,
    required this.cobrancas,
    required this.imoveisFechados,
    required this.imoveis,
    required this.atual,
  });

  /// No formato AAAA-MM, que e o que as rotas da API recebem.
  final String valor;
  final int cobrancas;
  final int imoveisFechados;
  final int imoveis;

  /// E o mes do calendario. Nao quer dizer que tenha lancamento.
  final bool atual;

  bool get aberta => imoveisFechados == 0;
  bool get fechada => imoveis > 0 && imoveisFechados == imoveis;
  bool get parcial => !aberta && !fechada;

  factory Competencia.fromJson(Map<String, dynamic> json) => Competencia(
        valor: json['competencia'] as String,
        cobrancas: json['cobrancas'] as int,
        imoveisFechados: json['imoveis_fechados'] as int,
        imoveis: json['imoveis'] as int,
        atual: json['atual'] as bool,
      );
}
