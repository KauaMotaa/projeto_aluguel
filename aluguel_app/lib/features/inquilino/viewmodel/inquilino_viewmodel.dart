import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/cobranca.dart';
import '../../../data/models/consumo.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/inquilino_repository.dart';

/// Estado da tela do inquilino: as cobrancas dele e o historico de consumo.
///
/// As duas chamadas nao levam id: a API resolve de quem sao os dados pelo
/// token da sessao. O ViewModel so precisa do nome, que pega no
/// AuthRepository, para nao ter que receber nada pela arvore de widgets.
class InquilinoViewModel extends ChangeNotifier {
  InquilinoViewModel(this._repo, this._auth);

  final InquilinoRepository _repo;
  final AuthRepository _auth;

  bool _carregando = false;
  String? _erro;
  List<Cobranca> _cobrancas = const [];
  List<Consumo> _consumo = const [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<Cobranca> get cobrancas => _cobrancas;
  List<Consumo> get consumo => _consumo;

  String get nome => _auth.usuario?.nome ?? 'Inquilino';

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final cobrancas = await _repo.minhasCobrancas();
      final consumo = await _repo.meuConsumo();

      // Mais recente primeiro: e a cobranca que o inquilino abriu o app
      // para ver.
      cobrancas.sort((a, b) => b.competencia.compareTo(a.competencia));
      _cobrancas = cobrancas;
      _consumo = consumo;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _cobrancas = const [];
      _consumo = const [];
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  void sair() => _auth.sair();

  // --- rotulos prontos para a View ---------------------------------------

  List<Cobranca> get emAberto => _cobrancas.where((c) => !c.paga).toList();

  int get totalEmAberto =>
      emAberto.fold(0, (soma, c) => soma + c.valorTotal);

  String get totalFormatado => Formatters.moeda(totalEmAberto);

  bool get temPendencia => emAberto.isNotEmpty;

  /// Legenda do cabecalho: diz o que o valor grande significa.
  String get resumoCabecalho {
    if (_cobrancas.isEmpty) return 'Nenhuma cobranca ainda';
    if (!temPendencia) return 'Tudo pago  ·  nada em aberto';

    final atrasadas = emAberto.where((c) => c.atrasada).length;
    final plural = emAberto.length == 1 ? 'cobranca' : 'cobrancas';
    if (atrasadas > 0) {
      return '${emAberto.length} $plural em aberto  ·  $atrasadas em atraso';
    }
    return '${emAberto.length} $plural em aberto';
  }

  String get valorCabecalho =>
      temPendencia ? totalFormatado : Formatters.moeda(0);

  String competenciaDe(Cobranca cobranca) =>
      Formatters.competencia(cobranca.competencia);

  String legendaDe(Cobranca cobranca) {
    final unidade = cobranca.identificacao;
    if (cobranca.paga) return '$unidade  ·  quitada';
    return '$unidade  ·  vence em ${Formatters.data(cobranca.vencimento)}';
  }

  String aluguelDe(Cobranca c) => Formatters.moeda(c.valorAluguel);
  String aguaDe(Cobranca c) => Formatters.moeda(c.valorAgua);
  String energiaDe(Cobranca c) => Formatters.moeda(c.valorEnergia);
  String totalDe(Cobranca c) => Formatters.moeda(c.valorTotal);

  String mesDe(PontoConsumo ponto) =>
      Formatters.competenciaCurta(ponto.competencia);

  /// Guiao do travessao: consumo nao lancado e diferente de consumo zero,
  /// e o mes em andamento costuma ter so um dos medidores lido.
  String aguaConsumidaDe(PontoConsumo ponto) => ponto.agua == null
      ? '—'
      : Formatters.consumo(ponto.agua!, 'agua');

  String energiaConsumidaDe(PontoConsumo ponto) => ponto.energia == null
      ? '—'
      : Formatters.consumo(ponto.energia!, 'energia');
}
