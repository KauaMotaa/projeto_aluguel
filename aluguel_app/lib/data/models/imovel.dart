class Imovel {
  const Imovel({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.unidades,
    required this.unidadesOcupadas,
  });

  final int id;
  final String nome;
  final String endereco;
  final int unidades;
  final int unidadesOcupadas;

  factory Imovel.fromJson(Map<String, dynamic> json) => Imovel(
        id: json['id'] as int,
        nome: json['nome'] as String,
        endereco: json['endereco'] as String,
        unidades: json['unidades'] as int,
        unidadesOcupadas: json['unidades_ocupadas'] as int,
      );
}
