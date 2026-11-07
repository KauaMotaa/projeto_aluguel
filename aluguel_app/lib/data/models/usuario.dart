class Usuario {
  const Usuario({required this.id, required this.nome, required this.perfil});

  final int id;
  final String nome;
  final String perfil;

  bool get ehProprietario => perfil == 'proprietario';

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nome: json['nome'] as String,
        perfil: json['perfil'] as String,
      );
}
