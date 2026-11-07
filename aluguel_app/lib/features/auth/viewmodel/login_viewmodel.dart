import 'package:flutter/foundation.dart';

import '../../../data/datasources/api_client.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._repo);

  final AuthRepository _repo;

  bool _carregando = false;
  String? _erro;
  Usuario? _usuario;

  bool get carregando => _carregando;
  String? get erro => _erro;
  Usuario? get usuario => _usuario;

  Future<bool> entrar(String email, String senha) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      _usuario = await _repo.entrar(email.trim(), senha);
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      return false;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }
}
