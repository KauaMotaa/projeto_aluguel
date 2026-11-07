import '../datasources/api_client.dart';
import '../models/usuario.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;
  Usuario? _usuario;

  Usuario? get usuario => _usuario;

  Future<Usuario> entrar(String email, String senha) async {
    final json = await _api.post('/auth/login', corpo: {
      'email': email,
      'senha': senha,
    }) as Map<String, dynamic>;

    _api.autenticar(json['token'] as String);
    _usuario = Usuario.fromJson(json['usuario'] as Map<String, dynamic>);
    return _usuario!;
  }

  void sair() {
    _api.sair();
    _usuario = null;
  }
}
