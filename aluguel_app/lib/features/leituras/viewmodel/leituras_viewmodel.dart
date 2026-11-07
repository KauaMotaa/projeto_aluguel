import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/leitura.dart';
import '../../../data/repositories/leitura_repository.dart';

/// Uma unidade na tela de leituras: os dois medidores juntos.
class LinhaLeitura {
  LinhaLeitura({
    required this.unidadeId,
    required this.identificacao,
    required this.agua,
    required this.energia,
  });

  final int unidadeId;
  final String identificacao;
  final Leitura agua;
  final Leitura energia;

  final TextEditingController controllerAgua = TextEditingController();
  final TextEditingController controllerEnergia = TextEditingController();

  String? erroAgua;
  String? erroEnergia;

  void dispose() {
    controllerAgua.dispose();
    controllerEnergia.dispose();
  }
}

class LeiturasViewModel extends ChangeNotifier {
  LeiturasViewModel(this._repo, {required this.imovelId});

  final LeituraRepository _repo;
  final int imovelId;

  static const String competencia = '2026-11';

  bool _carregando = false;
  bool _salvando = false;
  String? _erro;
  String? _sucesso;
  List<LinhaLeitura> _linhas = [];

  bool get carregando => _carregando;
  bool get salvando => _salvando;
  String? get erro => _erro;
  String? get sucesso => _sucesso;
  List<LinhaLeitura> get linhas => _linhas;

  String get competenciaFormatada => Formatters.competencia(competencia);

  bool get temErro =>
      _linhas.any((l) => l.erroAgua != null || l.erroEnergia != null);

  bool get podeSalvar => !temErro && _linhas.isNotEmpty && !_salvando;

  String? get avisoRodape {
    final comErro = _linhas
        .where((l) => l.erroAgua != null || l.erroEnergia != null)
        .map((l) => l.identificacao)
        .toList();
    if (comErro.isEmpty) return null;
    return 'Corrija a leitura de ${comErro.join(', ')} para continuar';
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final leituras =
          await _repo.listar(competencia: competencia, imovelId: imovelId);

      final porUnidade = <int, List<Leitura>>{};
      for (final leitura in leituras) {
        porUnidade.putIfAbsent(leitura.unidadeId, () => []).add(leitura);
      }

      for (final linha in _linhas) {
        linha.dispose();
      }

      _linhas = porUnidade.entries.map((entrada) {
        final agua = entrada.value.firstWhere((l) => l.tipo == 'agua');
        final energia = entrada.value.firstWhere((l) => l.tipo == 'energia');
        final linha = LinhaLeitura(
          unidadeId: entrada.key,
          identificacao: agua.identificacao,
          agua: agua,
          energia: energia,
        );
        if (agua.valorAtual != null) {
          linha.controllerAgua.text = Formatters.numero(agua.valorAtual!);
        }
        if (energia.valorAtual != null) {
          linha.controllerEnergia.text =
              Formatters.numero(energia.valorAtual!, casas: 0);
        }
        return linha;
      }).toList();
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _linhas = [];
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Validacao local: o medidor nao anda para tras. Pegar isso aqui evita
  /// uma ida ate a API so para receber 422.
  void validar(LinhaLeitura linha, String tipo, String texto) {
    final valor = double.tryParse(texto.replaceAll(',', '.'));
    final anterior =
        tipo == 'agua' ? linha.agua.valorAnterior : linha.energia.valorAnterior;

    String? erro;
    if (texto.trim().isEmpty) {
      erro = null;
    } else if (valor == null) {
      erro = 'Numero invalido';
    } else if (valor < anterior) {
      final formatado = Formatters.numero(anterior, casas: tipo == 'agua' ? 1 : 0);
      erro = 'Menor que a anterior ($formatado)';
    }

    if (tipo == 'agua') {
      linha.erroAgua = erro;
    } else {
      linha.erroEnergia = erro;
    }
    notifyListeners();
  }

  Future<bool> salvar() async {
    _salvando = true;
    _erro = null;
    _sucesso = null;
    notifyListeners();

    final corpo = <Map<String, dynamic>>[];
    for (final linha in _linhas) {
      final agua = double.tryParse(linha.controllerAgua.text.replaceAll(',', '.'));
      final energia =
          double.tryParse(linha.controllerEnergia.text.replaceAll(',', '.'));
      if (agua != null) {
        corpo.add({'unidade_id': linha.unidadeId, 'tipo': 'agua', 'valor_atual': agua});
      }
      if (energia != null) {
        corpo.add({
          'unidade_id': linha.unidadeId,
          'tipo': 'energia',
          'valor_atual': energia,
        });
      }
    }

    try {
      await _repo.lancar(competencia: competencia, leituras: corpo);
      _sucesso = 'Leituras salvas';
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      return false;
    } finally {
      _salvando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final linha in _linhas) {
      linha.dispose();
    }
    super.dispose();
  }
}
