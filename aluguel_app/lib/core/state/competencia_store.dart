import 'package:flutter/foundation.dart';

import '../../data/datasources/api_client.dart';
import '../../data/models/competencia.dart';
import '../../data/repositories/competencia_repository.dart';
import '../utils/formatters.dart';

/// Fonte unica do mes que o app esta olhando.
///
/// Antes cada ViewModel do proprietario carregava a propria
/// `static const competencia = '2026-11'`: quatro copias do mesmo valor, e
/// trocar de mes exigia recompilar. Agora o mes mora aqui, e quem precisa
/// dele le daqui.
///
/// A lista de meses vem da API, nao de um calculo de calendario: quem sabe
/// onde os lancamentos comecam e o servidor. Um intervalo inventado no
/// cliente ofereceria meses vazios.
///
/// Formata os rotulos como um ViewModel faria, pelo mesmo motivo: o
/// seletor recebe String pronta e nao conhece Formatters.
class CompetenciaStore extends ChangeNotifier {
  CompetenciaStore(this._repo);

  final CompetenciaRepository _repo;

  List<Competencia> _opcoes = const [];
  String? _escolhida;
  bool _carregando = false;
  String? _erro;

  List<Competencia> get opcoes => _opcoes;
  bool get carregando => _carregando;
  String? get erro => _erro;

  /// Enquanto a lista nao chegou, vale o mes do relogio do aparelho: as
  /// telas pedem a competencia antes de o seletor ter resposta.
  String get atual => _escolhida ?? doMes(DateTime.now());

  String get formatada => Formatters.competencia(atual);

  Competencia? get selecionada {
    for (final opcao in _opcoes) {
      if (opcao.valor == atual) return opcao;
    }
    return null;
  }

  /// `DateTime` para "AAAA-MM".
  static String doMes(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}';

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      _opcoes = await _repo.listar();
      // Mantem a escolha de quem esta usando, se ela continuar na lista.
      // Senao cai no mes mais recente que a API conhece, que vem primeiro.
      if (_opcoes.isNotEmpty && selecionada == null) {
        _escolhida = _opcoes.first.valor;
      }
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _opcoes = const [];
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Troca o mes. Devolve `false` quando nao mudou nada, e e isso que
  /// evita a tela recarregar ao tocar no mes que ja estava selecionado.
  bool selecionar(String competencia) {
    if (competencia == _escolhida) return false;
    _escolhida = competencia;
    notifyListeners();
    return true;
  }

  /// Chamado no logout. Nao notifica de proposito: quem ouve recarregaria
  /// na hora, e sem token a chamada voltaria 401 na cara do login.
  void limpar() {
    _opcoes = const [];
    _escolhida = null;
    _erro = null;
  }

  // --- rotulos prontos para a View ---------------------------------------

  String rotulo(Competencia opcao) => Formatters.competencia(opcao.valor);

  String descricao(Competencia opcao) {
    final partes = <String>[];
    if (opcao.fechada) {
      final n = opcao.cobrancas;
      partes.add('Fechado  ·  $n ${n == 1 ? 'cobranca' : 'cobrancas'}');
    } else if (opcao.parcial) {
      partes.add('${opcao.imoveisFechados} de ${opcao.imoveis} pontos fechados');
    } else {
      partes.add('Nenhum ponto fechado');
    }
    if (opcao.atual) partes.add('mes corrente');
    return partes.join('  ·  ');
  }
}
