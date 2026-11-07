import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/contrato.dart';
import '../../../data/models/inquilino.dart';
import '../../../data/models/unidade.dart';
import '../../../data/repositories/cadastro_repository.dart';

/// Contrato de uma unidade vaga.
///
/// A unidade chega escolhida: o gesto comeca no card vago do painel, que e
/// onde se ve que ela esta vazia. O inquilino pode ser alguem que ja esta
/// cadastrado ou um nome novo, e nesse caso a tela faz duas chamadas —
/// cria a pessoa e depois o contrato, nessa ordem, porque o contrato
/// precisa do id dela.
class ContratoFormViewModel extends ChangeNotifier {
  ContratoFormViewModel(
    this._repo, {
    required this.unidade,
    DateTime? hoje,
  }) : _dataInicio = hoje ?? DateTime.now();

  final CadastroRepository _repo;
  final Unidade unidade;

  final TextEditingController controllerValor = TextEditingController();
  final TextEditingController controllerNome = TextEditingController();
  final TextEditingController controllerTelefone = TextEditingController();

  /// Dias que a API aceita como vencimento. Para em 28 porque fevereiro
  /// existe: dia 30 nao daria data valida em todo mes.
  static const List<int> diasVencimento = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
  ];

  List<Inquilino> _inquilinos = const [];
  int? _inquilinoId;
  bool _novoInquilino = false;
  int _diaVencimento = 10;
  DateTime _dataInicio;

  bool _carregando = false;
  bool _salvando = false;
  String? _erro;
  String? _erroValor;
  String? _erroNome;
  Contrato? _criado;

  List<Inquilino> get inquilinos => _inquilinos;
  int? get inquilinoId => _inquilinoId;
  bool get novoInquilino => _novoInquilino;
  int get diaVencimento => _diaVencimento;
  DateTime get dataInicio => _dataInicio;
  bool get carregando => _carregando;
  bool get salvando => _salvando;
  String? get erro => _erro;
  String? get erroValor => _erroValor;
  String? get erroNome => _erroNome;

  String get titulo => 'Alugar ${unidade.identificacao}';
  String get dataInicioFormatada => Formatters.data(dataInicioIso);

  String get dataInicioIso => '${_dataInicio.year.toString().padLeft(4, '0')}-'
      '${_dataInicio.month.toString().padLeft(2, '0')}-'
      '${_dataInicio.day.toString().padLeft(2, '0')}';

  int? get centavos => Formatters.centavos(controllerValor.text);

  Inquilino? get escolhido {
    for (final pessoa in _inquilinos) {
      if (pessoa.id == _inquilinoId) return pessoa;
    }
    return null;
  }

  /// Aviso, nao erro: a mesma pessoa pode alugar duas unidades, e isso
  /// acontece de verdade. Mas na maioria das vezes e o nome errado na
  /// lista, entao vale dizer.
  String? get avisoInquilino {
    final pessoa = escolhido;
    if (pessoa == null || !pessoa.alojado) return null;
    return '${pessoa.nome} ja ocupa ${pessoa.unidades.join(', ')}';
  }

  String get resumoVencimento =>
      'Todo dia $_diaVencimento, a partir de $dataInicioFormatada';

  bool get podeSalvar {
    if (_salvando || _erroValor != null) return false;
    if ((centavos ?? 0) <= 0) return false;
    if (_novoInquilino) {
      return _erroNome == null && controllerNome.text.trim().length >= 2;
    }
    return _inquilinoId != null;
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      _inquilinos = await _repo.listarInquilinos();
      // Sem ninguem cadastrado, a unica saida e cadastrar: ja abre no
      // modo de nome novo em vez de mostrar uma lista vazia.
      if (_inquilinos.isEmpty) _novoInquilino = true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _inquilinos = const [];
      _novoInquilino = true;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  void escolherInquilino(int id) {
    _inquilinoId = id;
    _novoInquilino = false;
    notifyListeners();
  }

  void cadastrarNovo() {
    _novoInquilino = true;
    _inquilinoId = null;
    notifyListeners();
  }

  void escolherDia(int dia) {
    if (dia == _diaVencimento) return;
    _diaVencimento = dia;
    notifyListeners();
  }

  void escolherDataInicio(DateTime data) {
    _dataInicio = data;
    notifyListeners();
  }

  void validar() {
    final valor = centavos;
    if (controllerValor.text.trim().isEmpty) {
      _erroValor = null; // em branco nao e erro, so nao salva
    } else if (valor == null) {
      _erroValor = 'Valor invalido';
    } else if (valor <= 0) {
      _erroValor = 'Precisa ser maior que zero';
    } else {
      _erroValor = null;
    }

    final nome = controllerNome.text.trim();
    if (!_novoInquilino || nome.isEmpty) {
      _erroNome = null;
    } else if (nome.length < 2) {
      _erroNome = 'Nome muito curto';
    } else {
      _erroNome = null;
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
      // Pessoa primeiro, contrato depois: o contrato precisa do id dela.
      // Se a segunda chamada falhar, a pessoa fica cadastrada sem contrato
      // — que e um estado valido, e nao um registro orfao.
      var id = _inquilinoId;
      if (_novoInquilino) {
        final pessoa = await _repo.criarInquilino(
          nome: controllerNome.text.trim(),
          telefone: controllerTelefone.text.trim(),
        );
        id = pessoa.id;
      }

      _criado = await _repo.criarContrato(
        unidadeId: unidade.id,
        inquilinoId: id!,
        valorAluguel: centavos!,
        diaVencimento: _diaVencimento,
        dataInicio: dataInicioIso,
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
    final contrato = _criado;
    if (contrato == null) return 'Contrato criado';
    return '${unidade.identificacao} alugada para ${contrato.inquilino} '
        'por ${Formatters.moeda(contrato.valorAluguel)}';
  }

  @override
  void dispose() {
    controllerValor.dispose();
    controllerNome.dispose();
    controllerTelefone.dispose();
    super.dispose();
  }
}
