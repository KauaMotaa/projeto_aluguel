import 'package:flutter/material.dart';

import '../../../data/datasources/api_client.dart';
import '../../../data/models/imovel.dart';
import '../../../data/models/unidade.dart';
import '../../../data/repositories/cadastro_repository.dart';

/// Cadastro de uma unidade nova num ponto que ja existe.
///
/// A unidade nasce vaga, sem contrato: quem aluga e a tela de contrato.
/// Separar os dois e o que permite cadastrar a kitnet enquanto ela esta
/// sendo construida, antes de haver inquilino.
class UnidadeFormViewModel extends ChangeNotifier {
  UnidadeFormViewModel(
    this._repo, {
    required this.imoveis,
    required Map<int, List<String>> existentes,
    int? imovelId,
  })  : _existentes = existentes,
        _imovelId = imovelId ?? (imoveis.isEmpty ? null : imoveis.first.id);

  final CadastroRepository _repo;
  final List<Imovel> imoveis;

  /// Identificacoes ja usadas, por imovel. Vem do painel, que acabou de
  /// carregar a lista: a API nao recusa nome repetido, e duas "Kitnet 03"
  /// no mesmo ponto sao um problema de leitura depois, nao agora.
  final Map<int, List<String>> _existentes;

  final TextEditingController controllerIdentificacao = TextEditingController();

  int? _imovelId;
  bool _salvando = false;
  String? _erro;
  String? _erroIdentificacao;
  Unidade? _criada;

  int? get imovelId => _imovelId;
  bool get salvando => _salvando;
  String? get erro => _erro;
  String? get erroIdentificacao => _erroIdentificacao;
  Unidade? get criada => _criada;

  Imovel? get imovel {
    for (final candidato in imoveis) {
      if (candidato.id == _imovelId) return candidato;
    }
    return null;
  }

  /// Quantas unidades o ponto escolhido ja tem. Serve de contexto para
  /// quem esta cadastrando saber se acertou o ponto.
  String get resumoDoImovel {
    final atuais = _existentes[_imovelId] ?? const [];
    if (atuais.isEmpty) return 'Nenhuma unidade cadastrada neste ponto';
    return 'Ja tem ${atuais.length} '
        '${atuais.length == 1 ? 'unidade' : 'unidades'}: ${atuais.join(', ')}';
  }

  bool get podeSalvar =>
      !_salvando &&
      _imovelId != null &&
      _erroIdentificacao == null &&
      controllerIdentificacao.text.trim().length >= 2;

  void escolherImovel(int id) {
    if (id == _imovelId) return;
    _imovelId = id;
    validar(); // o nome repetido depende do ponto, entao revalida
    notifyListeners();
  }

  void validar() {
    final texto = controllerIdentificacao.text.trim();
    final atuais = _existentes[_imovelId] ?? const [];

    if (texto.isEmpty) {
      _erroIdentificacao = null; // campo em branco nao e erro, so nao salva
    } else if (texto.length < 2) {
      _erroIdentificacao = 'Nome muito curto';
    } else if (atuais.any((nome) => nome.toLowerCase() == texto.toLowerCase())) {
      _erroIdentificacao = 'Este ponto ja tem uma unidade com esse nome';
    } else {
      _erroIdentificacao = null;
    }
    notifyListeners();
  }

  Future<bool> salvar() async {
    validar();
    if (!podeSalvar) return false;

    _salvando = true;
    _erro = null;
    notifyListeners();

    try {
      _criada = await _repo.criarUnidade(
        imovelId: _imovelId!,
        identificacao: controllerIdentificacao.text.trim(),
      );
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      return false;
    } finally {
      _salvando = false;
      notifyListeners();
    }
  }

  String get confirmacao {
    final unidade = _criada;
    if (unidade == null) return 'Unidade cadastrada';
    return '${unidade.identificacao} cadastrada, ainda sem inquilino';
  }

  @override
  void dispose() {
    controllerIdentificacao.dispose();
    super.dispose();
  }
}
