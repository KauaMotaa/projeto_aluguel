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

  /// Aviso de consumo fora do padrao. Fica separado do erro de proposito:
  /// erro trava o salvamento, aviso nao. Um mes de consumo alto acontece —
  /// visita, mudanca, chuveiro novo — e o app nao tem como saber.
  String? avisoAgua;
  String? avisoEnergia;

  bool get temAviso => avisoAgua != null || avisoEnergia != null;

  void dispose() {
    controllerAgua.dispose();
    controllerEnergia.dispose();
  }
}

class LeiturasViewModel extends ChangeNotifier {
  LeiturasViewModel(
    this._repo, {
    required this.imovelId,
    required this.competencia,
  });

  final LeituraRepository _repo;
  final int imovelId;

  /// Vem do seletor do painel, pelo CompetenciaStore. Chega pronto no
  /// construtor porque esta tela trabalha num mes fixo enquanto esta
  /// aberta: nao ha como trocar de mes daqui.
  final String competencia;

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

  /// Rodape da tela. Erro vem antes de aviso: um trava o botao e o outro
  /// nao, e mostrar os dois juntos deixaria duvida sobre qual e qual.
  String? get avisoRodape {
    final comErro = _linhas
        .where((l) => l.erroAgua != null || l.erroEnergia != null)
        .map((l) => l.identificacao)
        .toList();
    if (comErro.isNotEmpty) {
      return 'Corrija a leitura de ${comErro.join(', ')} para continuar';
    }

    final foraDoPadrao =
        _linhas.where((l) => l.temAviso).map((l) => l.identificacao).toList();
    if (foraDoPadrao.isEmpty) return null;

    final quantas = foraDoPadrao.length;
    return '${foraDoPadrao.join(', ')}: consumo fora do padrao. '
        'Da para salvar assim mesmo se ${quantas == 1 ? 'estiver' : 'estiverem'} certo.';
  }

  /// Diferencia os dois no rodape: erro pinta de vermelho e trava, aviso
  /// pinta de ambar e deixa passar.
  bool get rodapeEhErro => temErro;

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

      // O que ja estava lancado tambem passa pela conferencia: o mes pode
      // ter sido digitado errado antes, e so agora ha historico para ver.
      for (final linha in _linhas) {
        linha.avisoAgua = _foraDoPadrao(linha.agua, linha.agua.valorAtual);
        linha.avisoEnergia =
            _foraDoPadrao(linha.energia, linha.energia.valorAtual);
      }
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _linhas = [];
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// A partir de quantas vezes a media o consumo vira suspeito.
  ///
  /// Tres e folgado de proposito: variacao de 50% para mais ou para menos
  /// e rotina num aluguel. O que se quer pegar e o dedo gordo — digitar
  /// 3650 no lugar de 365 da dez vezes a media, nao uma e meia. Falso
  /// alarme toda vez ensina quem usa a ignorar o aviso.
  static const double limiteAlto = 3.0;
  static const double limiteBaixo = 1 / 3;

  /// Validacao local: o medidor nao anda para tras. Pegar isso aqui evita
  /// uma ida ate a API so para receber 422.
  void validar(LinhaLeitura linha, String tipo, String texto) {
    final valor = double.tryParse(texto.replaceAll(',', '.'));
    final medidor = tipo == 'agua' ? linha.agua : linha.energia;
    final anterior = medidor.valorAnterior;

    String? erro;
    if (texto.trim().isEmpty) {
      erro = null;
    } else if (valor == null) {
      erro = 'Numero invalido';
    } else if (valor < anterior) {
      final formatado = Formatters.numero(anterior, casas: tipo == 'agua' ? 1 : 0);
      erro = 'Menor que a anterior ($formatado)';
    }

    final aviso = erro == null ? _foraDoPadrao(medidor, valor) : null;

    if (tipo == 'agua') {
      linha.erroAgua = erro;
      linha.avisoAgua = aviso;
    } else {
      linha.erroEnergia = erro;
      linha.avisoEnergia = aviso;
    }
    notifyListeners();
  }

  /// Compara o consumo digitado com o que aquele medidor costuma marcar.
  ///
  /// A regra que ja existia — nao pode ser menor que a anterior — nao pega
  /// o erro mais comum, que e a tecla a mais. 365 e 3650 sao os dois
  /// maiores que o anterior, e so o historico distingue os dois.
  String? _foraDoPadrao(Leitura medidor, double? valor) {
    if (valor == null || !medidor.temPadrao) return null;

    final consumo = valor - medidor.valorAnterior;
    if (consumo < 0) return null;

    final media = medidor.mediaConsumo!;
    final habitual = Formatters.consumo(media, medidor.tipo);
    final vezes = consumo / media;

    if (vezes >= limiteAlto) {
      return '${Formatters.numero(vezes)}x o normal desta unidade '
          '($habitual por mes). Confere?';
    }
    if (vezes <= limiteBaixo) {
      return 'Bem abaixo do normal desta unidade '
          '($habitual por mes). Confere?';
    }
    return null;
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
