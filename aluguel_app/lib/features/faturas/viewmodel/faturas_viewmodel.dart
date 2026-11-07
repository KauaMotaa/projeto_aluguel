import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/fatura.dart';
import '../../../data/repositories/fatura_repository.dart';

/// Uma fatura na tela: o par valor + consumo de um medidor geral.
///
/// Os dois campos andam juntos. Lancar um sem o outro nao faz sentido, e a
/// API recusa: o rateio precisa dividir um pelo outro.
class LinhaFatura {
  LinhaFatura({required this.fatura});

  final Fatura fatura;

  final TextEditingController controllerValor = TextEditingController();
  final TextEditingController controllerConsumo = TextEditingController();

  String? erroValor;
  String? erroConsumo;

  String get tipo => fatura.tipo;
  bool get jaLancada => fatura.lancada;

  bool get temErro => erroValor != null || erroConsumo != null;

  String get valorTexto => controllerValor.text.trim();
  String get consumoTexto => controllerConsumo.text.trim();

  bool get vazia => valorTexto.isEmpty && consumoTexto.isEmpty;
  bool get completa => valorTexto.isNotEmpty && consumoTexto.isNotEmpty;

  int? get centavos => Formatters.centavos(valorTexto);
  double? get consumo => double.tryParse(consumoTexto.replaceAll(',', '.'));

  void dispose() {
    controllerValor.dispose();
    controllerConsumo.dispose();
  }
}

class FaturasViewModel extends ChangeNotifier {
  FaturasViewModel(
    this._repo, {
    required this.imovelId,
    required this.competencia,
  });

  final FaturaRepository _repo;
  final int imovelId;

  /// Vem do seletor do painel, pelo CompetenciaStore. E a fatura daquele
  /// mes: trocar de mes aqui seria trocar de fatura no meio da digitacao.
  final String competencia;

  bool _carregando = false;
  bool _salvando = false;
  String? _erro;
  List<LinhaFatura> _linhas = [];

  bool get carregando => _carregando;
  bool get salvando => _salvando;
  String? get erro => _erro;
  List<LinhaFatura> get linhas => _linhas;

  String get competenciaFormatada => Formatters.competencia(competencia);

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final faturas =
          await _repo.listar(imovelId: imovelId, competencia: competencia);

      for (final linha in _linhas) {
        linha.dispose();
      }

      _linhas = faturas.map((fatura) {
        final linha = LinhaFatura(fatura: fatura);
        if (fatura.valorTotal != null) {
          linha.controllerValor.text = Formatters.valor(fatura.valorTotal!);
        }
        if (fatura.consumoTotal != null) {
          linha.controllerConsumo.text = Formatters.numero(
            fatura.consumoTotal!,
            casas: fatura.tipo == 'agua' ? 1 : 0,
          );
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

  /// Valida a linha inteira a cada tecla, porque os dois campos se olham:
  /// preencher um exige o outro, e o consumo depende do piso.
  void validar(LinhaFatura linha) {
    linha.erroValor = null;
    linha.erroConsumo = null;

    if (linha.valorTexto.isNotEmpty) {
      final centavos = linha.centavos;
      if (centavos == null) {
        linha.erroValor = 'Valor invalido';
      } else if (centavos <= 0) {
        linha.erroValor = 'Precisa ser maior que zero';
      }
    } else if (linha.consumoTexto.isNotEmpty) {
      linha.erroValor = 'Falta o valor da fatura';
    }

    if (linha.consumoTexto.isNotEmpty) {
      final consumo = linha.consumo;
      final piso = linha.fatura.consumoMedido;
      if (consumo == null) {
        linha.erroConsumo = 'Numero invalido';
      } else if (consumo <= 0) {
        linha.erroConsumo = 'Precisa ser maior que zero';
      } else if (consumo < piso) {
        // A API aceita e so reclama na previa, com
        // consumo_medido_acima_da_fatura. Barrar aqui evita o beco sem
        // saida de lancar, ir fechar e descobrir la que nao da.
        linha.erroConsumo =
            'Menor que os submedidores (${Formatters.consumo(piso, linha.tipo)})';
      }
    } else if (linha.valorTexto.isNotEmpty) {
      linha.erroConsumo = 'Falta o consumo do relogio';
    }

    notifyListeners();
  }

  bool get podeSalvar =>
      !_salvando &&
      _linhas.isNotEmpty &&
      !_linhas.any((l) => l.temErro) &&
      _linhas.any((l) => l.completa);

  String? get avisoRodape {
    if (_linhas.isEmpty) return null;
    if (_linhas.any((l) => l.temErro)) {
      return 'Corrija os campos marcados para continuar';
    }
    if (_linhas.every((l) => l.vazia)) {
      return 'Preencha pelo menos uma das duas faturas';
    }
    return null;
  }

  Future<bool> salvar() async {
    _salvando = true;
    _erro = null;
    notifyListeners();

    final corpo = [
      for (final linha in _linhas)
        if (linha.completa)
          {
            'tipo': linha.tipo,
            'valor_total': linha.centavos,
            'consumo_total': linha.consumo,
          }
    ];

    try {
      await _repo.lancar(
        imovelId: imovelId,
        competencia: competencia,
        faturas: corpo,
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

  // --- rotulos prontos para a View ---------------------------------------

  String tituloDe(LinhaFatura linha) =>
      linha.tipo == 'agua' ? 'Agua' : 'Energia';

  String unidadeDe(LinhaFatura linha) =>
      linha.tipo == 'agua' ? 'm³' : 'kWh';

  String statusDe(LinhaFatura linha) =>
      linha.jaLancada ? 'Lancada' : 'Pendente';

  String pisoDe(LinhaFatura linha) {
    final medido = linha.fatura.consumoMedido;
    if (medido <= 0) return 'Nenhum submedidor lido neste mes';
    return 'Submedidores somam ${Formatters.consumo(medido, linha.tipo)}';
  }

  /// Previa do valor unitario enquanto se digita. E o numero que o rateio
  /// vai usar, e ver ele aqui pega vírgula no lugar errado na hora.
  String? unitarioDe(LinhaFatura linha) {
    if (linha.temErro) return null;
    final centavos = linha.centavos;
    final consumo = linha.consumo;
    if (centavos == null || consumo == null || consumo <= 0) return null;
    final porUnidade = Formatters.moeda((centavos / consumo).round());
    return 'Sai a $porUnidade por ${unidadeDe(linha)}';
  }

  @override
  void dispose() {
    for (final linha in _linhas) {
      linha.dispose();
    }
    super.dispose();
  }
}
