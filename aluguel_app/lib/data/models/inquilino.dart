class Inquilino {
  const Inquilino({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.unidades,
  });

  final int id;
  final String nome;
  final String telefone;

  /// Unidades que a pessoa ocupa hoje. Vem da API para a tela de contrato
  /// poder avisar que ela ja esta alojada antes de alguem escolher.
  final List<String> unidades;

  bool get alojado => unidades.isNotEmpty;

  factory Inquilino.fromJson(Map<String, dynamic> json) => Inquilino(
        id: json['id'] as int,
        nome: json['nome'] as String,
        telefone: (json['telefone'] as String?) ?? '',
        unidades: ((json['unidades'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}
